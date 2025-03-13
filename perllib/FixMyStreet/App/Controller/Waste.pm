package FixMyStreet::App::Controller::Waste;
use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::App::Controller::Form' }

use utf8;
use Lingua::EN::Inflect qw( NUMWORDS );
use List::Util qw(any);
use FixMyStreet::App::Form::Field::JSON;
use FixMyStreet::App::Form::Waste::UPRN;
use FixMyStreet::App::Form::Waste::AboutYou;
use FixMyStreet::App::Form::Waste::Report;
use FixMyStreet::App::Form::Waste::Problem;
use FixMyStreet::App::Form::Waste::Enquiry;
use FixMyStreet::App::Form::Waste::Garden;
use FixMyStreet::App::Form::Waste::Garden::Modify;
use FixMyStreet::App::Form::Waste::Garden::Cancel;
use FixMyStreet::App::Form::Waste::Garden::Renew;
use FixMyStreet::App::Form::Waste::Garden::Sacks::Purchase;
use FixMyStreet::App::Form::Waste::Garden::Transfer;
use WasteWorks::Costs;
use Memcached;
use Hash::Util qw(lock_hash);
use JSON::MaybeXS;

has feature => (
    is => 'ro',
    default => 'waste',
);

has index_template => (
    is => 'ro',
    default => 'waste/form.html'
);

my %GARDEN_IDS = (
    merton => { bin240 => 26, bin140 => 27, sack => 28 },
    kingston => { bin240 => 39, bin140 => 37, sack => 36 },
    sutton => { bin240 => 39, bin140 => 37, sack => 36 },
);
lock_hash(%GARDEN_IDS);

sub auto : Private {
    my ( $self, $c ) = @_;

    $self->SUPER::auto($c);

    # The check will exist by this point - let push endpoint through if needed
    my $cobrand_check = $c->cobrand->feature( $self->feature );
    $c->detach( '/page_error_404_not_found' )
        if $cobrand_check eq 'echo-push-only'
            && $c->action ne 'waste/echo/receive_echo_event_notification';

    $c->stash->{is_staff} = $c->user && $c->cobrand->admin_allow_user($c->user);

    my $features = $c->cobrand->feature('waste_features') || {};
    # Copy so cobrands can switch things off depending on situation
    $c->stash->{waste_features} = $features = { %$features };
    if ($features->{garden_waste_staff_only} && !$c->stash->{is_staff}) {
        $features->{garden_disabled} = 1;
    }

    if ( my $site_name = Utils::trim_text($c->render_fragment('waste/site-name.html')) ) {
        $c->stash->{site_name} = $site_name;
    }

    $c->stash->{staff_payments_allowed} = '';
    $c->cobrand->call_hook( 'waste_check_staff_payment_permissions' );

    $c->cobrand->call_hook( 'waste_check_downtime' )
        if $c->action ne 'waste/echo/receive_echo_event_notification'
            && $c->action ne 'waste/pay'
            && $c->action ne 'waste/pay_complete';

    return 1;
}

sub pre_form : Private {
    my ($self, $c) = @_;

    # Special button to go back to existing (as form wraps whole page)
    if ($c->get_param('goto-existing')) {
        $c->set_param('goto', 'existing');
        $c->set_param('process', '');
    }
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    if (my $id = $c->get_param('address')) {
        $c->cobrand->call_hook( clear_cached_lookups_property => $id );
        $c->detach('redirect_to_id', [ $id ]);
    }

    if (my $id = $c->get_param('continue_id')) {
        $c->stash->{continue_id} = $id;
        if (my $p = $c->cobrand->problems->search({ state => 'unconfirmed' })->find($id)) {
            if ($c->stash->{is_staff} && $c->stash->{waste_features}{bulky_retry_bookings}) {
                my $property_id = $p->waste_property_id;
                my $saved_data = $c->cobrand->waste_reconstruct_bulky_data($p);
                $saved_data->{continue_id} = $id;
                my $saved_data_field = FixMyStreet::App::Form::Field::JSON->new(name => 'saved_data');
                $saved_data = $saved_data_field->deflate_json($saved_data);
                $c->set_param(saved_data => $saved_data);
                $c->set_param('goto', 'summary');
                $c->go('/waste/bulky/index', [ $property_id ], []);
            }
        }
        $c->stash->{form} = {
            errors => 1,
            all_form_errors => [ 'That booking reference could not be found' ],
        };
        return;
    }

    $c->cobrand->call_hook( clear_cached_lookups_postcode => $c->get_param('postcode') )
        if $c->get_param('postcode');

    $c->stash->{title} = 'What is your address?';
    my $form = FixMyStreet::App::Form::Waste::UPRN->new( cobrand => $c->cobrand );
    $form->process( params => $c->req->body_params );
    if ($form->validated) {
        my $addresses = $form->value->{postcode};
        $c->stash->{template} = 'waste/form.html';
        $form = address_list_form($addresses);
    }
    $c->stash->{form} = $form;
}

sub address_list_form {
    my $addresses = shift;
    HTML::FormHandler->new(
        field_list => [
            address => {
                required => 1,
                type => 'Select',
                label => 'Select an address',
                tags => { last_differs => 1, small => 1, autocomplete => 1 },
                options => $addresses,
            },
            go => {
                type => 'Submit',
                value => 'Continue',
                element_attr => { class => 'govuk-button' },
            },
        ],
    );
}

sub redirect_to_id : Private {
    my ($self, $c, $id) = @_;
    my $uri = '/waste/' . $id;
    my $type = $c->get_param('type') || '';
    $uri .= '/request' if $type eq 'request';
    $uri .= '/report' if $type eq 'report';
    $uri .= '/garden_check' if $type eq 'garden';
    $uri .= '/bulky' if $type eq 'bulky';
    $uri .= '/small_items' if $type eq 'small_items';
    $c->res->redirect($uri);
    $c->detach;
}

sub check_payment_redirect_id : Private {
    my ( $self, $c, $id, $token ) = @_;

    $c->detach( '/page_error_404_not_found' ) unless $id =~ /^\d+$/;

    my $p = $c->model('DB::Problem')->find({
        id => $id,
    });

    $c->detach( '/page_error_404_not_found' )
        unless $p && $p->get_extra_metadata('redirect_id') eq $token;

    $c->stash->{report} = $p;
}

# This looks for pending unconfirmed DD reports in the database, as
# we might not hear about them for days (though preferably, we can query
# the DD system involved).
# For Bexley, DD reports are confirmed immediately, and cancellations
# might not be instant, so look for any open reports, not just DD
sub get_pending_subscription : Private {
    my ($self, $c) = @_;

    my $uprn = $c->stash->{property}{uprn};
    my $state = 'unconfirmed';
    $state = 'confirmed' if $c->cobrand->moniker eq 'bexley';
    my $subs = $c->model('DB::Problem')->search({
        state => $state,
        created => { '>=' => \"current_timestamp-'20 days'::interval" },
        category => { -in => ['Garden Subscription', 'Cancel Garden Subscription'] },
        title => { -in => ['Garden Subscription - Renew', 'Garden Subscription - New', 'Garden Subscription - Cancel'] },
        extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => $c->stash->{property}{uprn} } ] }) }
    })->to_body($c->cobrand->body);

    my ($new, $cancel);
    while (my $sub = $subs->next) {
        my $payment_method = $sub->get_extra_field_value('payment_method') || '';
        if ( $c->cobrand->moniker eq 'bexley' || $payment_method eq 'direct_debit' ) {
            if ( $sub->title eq 'Garden Subscription - New' ||
                 $sub->title eq 'Garden Subscription - Renew' ) {
                $new = $sub;
            } elsif ( $sub->title eq 'Garden Subscription - Cancel' ) {
                $cancel = $sub;
            }
        }

    }
    $c->stash->{pending_subscription} ||= $new;
    $c->stash->{pending_cancellation} = $cancel;
}

sub pay_retry : Path('pay_retry') : Args(0) {
    my ($self, $c) = @_;

    my $id = $c->get_param('id');
    my $token = $c->get_param('token');
    $c->forward('check_payment_redirect_id', [ $id, $token ]);

    my $p = $c->stash->{report};
    $c->stash->{property} = $c->cobrand->call_hook(look_up_property => $p->waste_property_id);
    $c->forward('pay', [ 'bin_days' ]);
}

sub pay : Path('pay') : Args(0) {
    my ($self, $c, $back) = @_;

    my $p = $c->stash->{report};

    # If it's using the same flow as users, but is staff, mark as CSC payment
    if ( $c->stash->{staff_payments_allowed} eq 'cnp' ) {
        $p->update_extra_field({ name => 'payment_method', value => 'csc' });
        $p->update;
    }

    if ($c->cobrand->waste_cc_has_redirect($p)) {
        my $redirect_url = $c->cobrand->waste_cc_get_redirect_url($c, $back);

        if ( $redirect_url ) {
            $c->res->redirect( $redirect_url );
            $c->detach;
        } else {
            unless ( $c->stash->{error} ) {
                $c->stash->{error} = 'Unknown error';
            }
            $c->stash->{template} = 'waste/pay_error.html';
            $c->detach;
        }
    } else {
        $c->forward('populate_cc_details');
        $c->cobrand->call_hook('waste_cc_munge_form_details' => $c);
        $c->stash->{template} = 'waste/cc.html';
        $c->detach;
    }
}

# redirect from cc processing - bulky goods only at present
sub pay_cancel : Local : Args(2) {
    my ($self, $c, $id, $token) = @_;

    my $property_id = $c->get_param('property_id');

    $c->forward('check_payment_redirect_id', [ $id, $token ]);

    $c->forward('/auth/get_csrf_token');

    my $p = $c->stash->{report};
    my $saved_data = $c->cobrand->waste_reconstruct_bulky_data($p);
    my $saved_data_field = FixMyStreet::App::Form::Field::JSON->new(name => 'saved_data');
    $saved_data = $saved_data_field->deflate_json($saved_data);
    $c->set_param(saved_data => $saved_data);
    $c->set_param(goto => 'summary');
    $c->set_param(process => '');
    $c->go('/waste/bulky/index', [ $property_id ], []);
}

# redirect from cc processing
sub pay_complete : Path('pay_complete') : Args(2) {
    my ($self, $c, $id, $token) = @_;

    $c->forward('check_payment_redirect_id', [ $id, $token ]);
    my $p = $c->stash->{report};

    my $ref = $c->cobrand->garden_cc_check_payment_status($c, $p);

    if ( $ref ) {
        $c->stash->{title} = 'Payment successful';
        $c->stash->{reference} = $ref;
        $c->stash->{action} = $p->title eq 'Garden Subscription - Amend' ? 'add_containers' : 'new_subscription';
        $c->forward( 'confirm_subscription', [ $ref ] );
    } else {
        $c->stash->{template} = 'waste/pay_error.html';
        $c->detach;
    }
}

sub confirm_subscription : Private {
    my ($self, $c, $reference) = @_;
    my $p = $c->stash->{report};

    $c->stash->{property_id} = $p->waste_property_id;

    if ($p->category eq 'Bulky collection' || $p->category eq 'Small items collection') {
        $c->stash->{template} = 'waste/bulky/confirmation.html';
    } elsif ($p->category eq 'Request new container') {
        $c->stash->{template} = 'waste/request_confirm.html';
    } else {
        $c->stash->{template} = 'waste/garden/subscribe_confirm.html';
    }

    # Set an override template, so that the form processing can finish (to e.g.
    # clear the session unique ID) and have the form code load this template
    # rather than the default 'done' form one
    $c->stash->{override_template} = $c->stash->{template};

    # Do everything needed to confirm a waste payment
    $p->waste_confirm_payment($reference);
}

sub cancel_subscription : Private {
    my ($self, $c, $reference) = @_;

    $c->stash->{template} = 'waste/garden/cancel_confirmation.html';
    $c->detach;
}

sub populate_payment_details : Private {
    my ($self, $c) = @_;

    my $p = $c->stash->{report};
    my $reference = mySociety::AuthToken::random_token();
    $p->set_extra_metadata('redirect_id', $reference);
    $p->update;

    my $address = $c->stash->{property}{address};

    my @parts = split /\s*,\s*/, $address;

    my $name = $c->stash->{report}->name;
    my ($first, $last) = split /\s/, $name, 2;

    $c->stash->{account_holder} = $name;
    $c->stash->{first_name} = $first;
    $c->stash->{last_name} = $last;
    $c->stash->{address1} = shift @parts;
    $c->stash->{address2} = shift @parts;
    $c->stash->{postcode} = pop @parts;
    $c->stash->{town} = pop @parts;
    $c->stash->{address3} = join ', ', @parts;

    my $payment_details = $c->cobrand->feature('payment_gateway');
    $c->stash->{payment_details} = $payment_details;

    if ($c->cobrand->moniker eq 'sutton' && $p->category eq 'Bulky collection') {
        $c->stash->{reference} = $p->id . substr(mySociety::AuthToken::random_token(), 0, 8);
    } else {
        $c->stash->{reference} = substr($c->cobrand->waste_payment_ref_council_code . '-' . $p->id . '-' . $c->stash->{property}{uprn}, 0, 18);
    }
    $c->stash->{lookup} = $reference;
}

sub populate_cc_details : Private {
    my ($self, $c) = @_;

    $c->forward('populate_payment_details');

    my $p = $c->stash->{report};
    my $payment = $p->get_extra_field_value('pro_rata');
    unless ($payment) {
        $payment = $p->get_extra_field_value('payment');
    }
    my $admin_fee = $p->get_extra_field_value('admin_fee');
    if ( $admin_fee ) {
        $payment = $admin_fee + $payment;
    }
    $c->stash->{amount} = sprintf( '%.2f', $payment / 100 );
}

sub populate_dd_details : Private {
    my ($self, $c) = @_;

    $c->forward('populate_payment_details');

    my $p = $c->stash->{report};

    my $dt = $c->cobrand->waste_get_next_dd_day;

    my $payment = $p->get_extra_field_value('payment');
    my $admin_fee = $p->get_extra_field_value('admin_fee');
    if ( $admin_fee ) {
        my $first_payment = $admin_fee + $payment;
        $c->stash->{firstamount} = sprintf( '%.2f', $first_payment / 100 );
    }
    $c->stash->{amount} = sprintf( '%.2f', $payment / 100 );
    $c->stash->{payment_date} = $dt;
    $c->stash->{start_date} = $dt->ymd;
    $c->stash->{day} = $dt->day;
    $c->stash->{month} = $dt->month;
    $c->stash->{month_name} = $dt->month_name;
    $c->stash->{year} = $dt->year;

    $c->cobrand->call_hook( 'garden_waste_dd_munge_form_details' => $c );

    $c->stash->{redirect} = $c->cobrand->call_hook( 'garden_waste_dd_redirect_url' => $p ) || '';
}

sub direct_debit : Path('dd') : Args(0) {
    my ($self, $c) = @_;

    $c->cobrand->call_hook('waste_report_extra_dd_data');
    $c->forward('populate_dd_details');
    $c->stash->{template} = 'waste/dd.html';
    $c->detach;
}

sub direct_debit_internal : Private {
    my ($self, $c) = @_;

    $c->forward('populate_dd_details');
    $c->cobrand->call_hook('waste_setup_direct_debit');
    $c->stash->{title} = "Direct Debit mandate";
    $c->stash->{message} = "Your Direct Debit has been set up successfully.";
    $c->stash->{template} = 'waste/dd_complete.html';
    $c->detach;
}

# we process direct debit payments when they happen so this page
# is only for setting expectations.
sub direct_debit_complete : Path('dd_complete') : Args(0) {
    my ($self, $c) = @_;

    $c->cobrand->call_hook( 'garden_waste_dd_check_success' => $c );
    my ($token, $id) = $c->cobrand->call_hook( 'garden_waste_dd_get_redirect_params' => $c );
    $c->forward('check_payment_redirect_id', [ $id, $token]);
    $c->cobrand->call_hook( 'garden_waste_dd_complete' => $c->stash->{report} );

    $c->stash->{title} = "Direct Debit mandate";

    $c->send_email('waste/direct_debit_in_progress.txt', {
        to => [ [ $c->stash->{report}->user->email, $c->stash->{report}->name ] ],
        sent_confirm_id_ref => $c->stash->{report}->id,
    } );

    $c->stash->{template} = 'waste/dd_complete.html';
}

sub direct_debit_cancelled : Path('dd_cancelled') : Args(0) {
    my ($self, $c) = @_;

    my ($token, $id) = $c->cobrand->call_hook( 'garden_waste_dd_get_redirect_params' => $c );
    if ( $id && $token ) {
        $c->forward('check_payment_redirect_id', [ $id, $token ]);
        $c->forward('populate_dd_details');
    }

    $c->stash->{template} = 'waste/dd_cancelled.html';
}

sub direct_debit_error : Path('dd_error') : Args(0) {
    my ($self, $c) = @_;

    my ($token, $id) = $c->cobrand->call_hook( 'garden_waste_dd_get_redirect_params' => $c );
    if ( $id && $token ) {
        $c->forward('check_payment_redirect_id', [ $id, $token ]);
        my $p = $c->stash->{report};
        $c->stash->{property} = $c->cobrand->call_hook(look_up_property => $p->waste_property_id);
        $c->forward('populate_dd_details');
    }

    $c->stash->{template} = 'waste/dd_error.html';
}

sub direct_debit_modify : Private {
    my ($self, $c) = @_;

    my $p = $c->stash->{report};

    my $ref = $c->stash->{orig_sub}->get_extra_metadata('payerReference');
    $p->set_extra_metadata(payerReference => $ref);
    $p->update;
    $c->cobrand->call_hook('waste_report_extra_dd_data');

    my $pro_rata = $p->get_extra_field_value('pro_rata') || 0;
    my $admin_fee = $p->get_extra_field_value('admin_fee') || 0;
    my $total = $p->get_extra_field_value('payment');

    my $ad_hoc = $pro_rata + $admin_fee;

    my $i = $c->cobrand->get_dd_integration;

    # if reducing bin count then there won't be an ad-hoc payment
    if ( $ad_hoc ) {
        my $one_off_ref = $i->one_off_payment( {
                # this will be set when the initial payment is confirmed
                payer_reference => $ref,
                amount => sprintf('%.2f', $ad_hoc / 100),
                reference => $p->id,
                comments => '',
                date => $c->cobrand->waste_get_next_dd_day('ad-hoc'),
                orig_sub => $c->stash->{orig_sub},
        } );
    }

    my $update_ref = $i->amend_plan( {
        payer_reference => $ref,
        amount => sprintf('%.2f', $total / 100),
        orig_sub => $c->stash->{orig_sub},
    } );
}

sub direct_debit_cancel_sub : Private {
    my ($self, $c) = @_;

    my $p = $c->stash->{report};
    my $ref = $c->stash->{orig_sub}->get_extra_metadata('payerReference');
    $p->set_extra_metadata(payerReference => $ref);
    # Bexley can have immediate cancellation
    $p->confirm if $c->cobrand->moniker eq 'bexley';
    $p->update;
    $c->cobrand->call_hook('waste_report_extra_dd_data');

    my $i = $c->cobrand->get_dd_integration;

    $c->stash->{payment_method} = 'direct_debit';
    my $update_ref = $i->cancel_plan( {
        payer_reference => $ref,
        report => $p,
    } );
}

sub csc_code : Private {
    my ($self, $c) = @_;

    unless ( $c->stash->{staff_payments_allowed} eq 'paye' ) {
        $c->detach( '/page_error_404_not_found', [] );
    }

    $c->forward('/auth/get_csrf_token');
    $c->stash->{template} = 'waste/garden/csc_code.html';
    $c->detach;
}

sub csc_payment : Path('csc_payment') : Args(0) {
    my ($self, $c) = @_;

    unless ( $c->stash->{staff_payments_allowed} eq 'paye' ) {
        $c->detach( '/page_error_404_not_found', [] );
    }

    $c->forward('/auth/check_csrf_token');
    my $code = $c->get_param('payenet_code');
    my $id = $c->get_param('report_id');

    my $report = $c->model('DB::Problem')->find({ id => $id});
    $report->update_extra_field({ name => 'payment_method', value => 'csc' });
    $report->update;
    $c->stash->{report} = $report;
    $c->forward('confirm_subscription', [ $code ]);
}

sub csc_payment_failed : Path('csc_payment_failed') : Args(0) {
    my ($self, $c) = @_;

    unless ( $c->stash->{staff_payments_allowed} eq 'paye' ) {
        $c->detach( '/page_error_404_not_found', [] );
    }

    $c->forward('/auth/check_csrf_token');
    my $code = $c->get_param('payenet_code');
    my $id = $c->get_param('report_id');

    my $report = $c->model('DB::Problem')->find({ id => $id});
    $c->stash->{report} = $report;
    $c->stash->{property_id} = $report->waste_property_id;

    my $contributed_as = $report->get_extra_metadata('contributed_as') || '';
    if ( $contributed_as ne 'anonymous_user' ) {
        $c->stash->{sent_email} = 1;
        $c->send_email('waste/csc_payment_failed.txt', {
            to => [ [ $report->user->email, $report->name ] ],
        } );
    }

    $report->update_extra_field({ name => 'payment_method', value => 'csc' });
    $report->update_extra_field({ name => 'payment_reference', value => 'FAILED' });
    $report->update;

    if (($report->category eq 'Bulky collection' || $report->category eq 'Small items collection') && $c->cobrand->bulky_send_before_payment) {
        $c->stash->{cancelling_booking} = $report;
        $c->stash->{non_user_cancel} = 1;
        $c->forward('bulky/process_bulky_cancellation');
    }

    $c->stash->{template} = 'waste/garden/csc_payment_failed.html';
    $c->detach;
}

sub property_id : Chained('/') : PathPart('waste') : CaptureArgs(1) {
    my ($self, $c, $id) = @_;
    $c->stash->{property_id} = $id;
}

sub property : Chained('property_id') : PathPart('') : CaptureArgs(0) {
    my ($self, $c) = @_;
    my $id = $c->stash->{property_id};

    # Some actions chained off /waste/property require user to be logged in.
    # The redirect to /auth does not work if it follows the asynchronous
    # property lookup, so force a redirect to /auth here.
    if ((      $c->action eq 'waste/bulky/cancel'
            || $c->action eq 'waste/bulky/cancel_small'
        )
        && !$c->user_exists
    ) {
        $c->detach('/auth/redirect');
    }

    if ($id eq 'missing') {
        $c->stash->{template} = 'waste/missing.html';
        $c->detach;
    }

    $c->forward('/auth/get_csrf_token');

    # clear this every time they visit this page to stop stale content,
    # unless this load has happened whilst waiting for async Echo/Bartec API
    # calls to complete.
    # non-JS page loads include a page_loading=1 request param
    my $loading = $c->stash->{ajax_loading} = $c->req->{headers}->{'x-requested-with'} || $c->get_param('page_loading');

    if ( $c->req->path =~ m#^waste/[:\w %]+$#i && !$loading) {
        $c->cobrand->call_hook( clear_cached_lookups_property => $id );
    }

    my $property = $c->stash->{property} = $c->cobrand->call_hook(look_up_property => $id);
    $c->detach( '/page_error_404_not_found', [] ) unless $property && $property->{id};

    if ($c->cobrand->can('bulky_enabled')) {
        my @pending = $c->cobrand->find_pending_bulky_collections($property->{uprn});
        $c->stash->{pending_bulky_collections} = @pending ? \@pending : undef;

        my @recent = $c->cobrand->find_recent_bulky_collections($property->{uprn});
        $c->stash->{recent_bulky_collections} = @recent ? \@recent : undef;

        my $cfg = $c->cobrand->feature('waste_features');
        if ($cfg->{bulky_retry_bookings} && $c->stash->{is_staff}) {
            my @unconfirmed = $c->cobrand->find_unconfirmed_bulky_collections($property->{uprn})->all;
            $c->stash->{unconfirmed_bulky_collections} = @unconfirmed ? \@unconfirmed : undef;
        }
    }

    $c->stash->{latitude} = Utils::truncate_coordinate( $property->{latitude} );
    $c->stash->{longitude} = Utils::truncate_coordinate( $property->{longitude} );

    $c->stash->{service_data} = $c->cobrand->call_hook(bin_services_for_address => $property) || [];
    $c->stash->{services} = { map { $_->{service_id} => $_ } @{$c->stash->{service_data}} };

    $c->forward('get_pending_subscription');
}

sub bin_days : Chained('property') : PathPart('') : Args(0) {
    my ($self, $c) = @_;

    # To try and work out whether to show a renewal path or not
    $c->forward('get_original_sub', ['any']);
    $c->stash->{current_payment_method} = $c->forward('get_current_payment_method');

    my $staff = $c->user_exists && ($c->user->is_superuser || $c->user->from_body);

    my $cfg = $c->cobrand->feature('waste_features');

    return if $staff || (!$cfg->{max_requests_per_day} && !$cfg->{max_properties_per_day});

    # Allow lookups of max_per_day different properties per day
    my $today = DateTime->today->set_time_zone(FixMyStreet->local_time_zone)->ymd;
    my $ip = $c->req->address;

    if ($cfg->{max_requests_per_day}) {
        my $key = FixMyStreet->test_mode ? "waste-req-test" : "waste-req-$ip-$today";
        my $count = Memcached::increment($key, 86400) || 0;
        $c->detach('bin_day_deny') if $count > $cfg->{max_requests_per_day};
    }

    # Allow lookups of max_per_day different properties per day
    if ($cfg->{max_properties_per_day}) {
        my $key = FixMyStreet->test_mode ? "waste-prop-test" : "waste-prop-$ip-$today";
        my $list = Memcached::get($key) || [];

        my $id = $c->stash->{property}->{id};
        return if any { $_ eq $id } @$list; # Already visited today

        $c->detach('bin_day_deny') if @$list >= $cfg->{max_properties_per_day};

        push @$list, $id;
        Memcached::set($key, $list, 86400);
    }
}

sub bin_day_deny : Private {
    my ($self, $c) = @_;
    my $msg = "Please note that for security and privacy reasons we have limited the number of different properties you can look up on the waste collection schedule in a 24-hour period.  You should be able to continue looking up properties you have already viewed.  For other properties please try again after 24 hours.  If you are still seeing this message after that time please try refreshing the page.";
    $c->detach('/page_error_403_access_denied', [ $msg ]);
}

sub calendar : Chained('property_id') : Args(0) {
    my ($self, $c) = @_;
    $c->forward('/about/page', ['waste-calendar']);
}

sub calendar_ics : Chained('property') : PathPart('calendar.ics') : Args(0) {
    my ($self, $c) = @_;
    $c->res->header(Content_Type => 'text/calendar');
    $c->res->header(Cache_Control => 'max-age=86400');
    require Data::ICal::RFC7986;
    require Data::ICal::Entry::Event;
    my $calendar = Data::ICal::RFC7986->new(
        calname => 'Bin calendar',
        rfc_strict => 1,
        auto_uid => 1,
    );
    $calendar->add_properties(
        prodid => '//FixMyStreet//Bin Collection Calendars//EN',
        method => 'PUBLISH',
        'refresh-interval' => [ 'P1D', { value => 'DURATION' } ],
        'x-published-ttl' => 'P1D',
        calscale => 'GREGORIAN',
        'x-wr-timezone' => 'Europe/London',
        source => [ $c->uri_for_action($c->action, [ $c->stash->{property}{id} ]), { value => 'URI' } ],
        url => $c->uri_for_action('waste/bin_days', [ $c->stash->{property}{id} ]),
    );

    my $events = $c->cobrand->bin_future_collections;
    my $stamp = DateTime->now->strftime('%Y%m%dT%H%M%SZ');
    foreach (@$events) {
        my $event = Data::ICal::Entry::Event->new;
        $event->add_properties(
            summary => $_->{summary},
            description => $_->{desc},
            dtstamp => $stamp,
            dtstart => [ $_->{date}->ymd(''), { value => 'DATE' } ],
            dtend => [ $_->{date}->clone->add(days=>1)->ymd(''), { value => 'DATE' } ],
        );
        $calendar->add_entry($event);
    }

    $c->res->body($calendar->as_string);
}

sub construct_bin_request_form {
    my $c = shift;

    my $field_list = [];

    foreach (@{$c->stash->{service_data}}) {
        next unless $_->{next} || $_->{request_only};
        my $service = $_;
        my $name = $_->{service_name};
        my $containers = $_->{request_containers};
        my $maximum = $_->{request_max};
        foreach my $id (@$containers) {
            my $max = ref $maximum ? $maximum->{$id} : $maximum;
            push @$field_list, "container-$id" => {
                type => 'Checkbox',
                label => $name,
                option_label => $c->stash->{containers}->{$id},
                tags => { toggle => "form-quantity-$id-row" },
                disabled => $_->{requests_open}{$id} ? 1 : 0,
            };
            $name = ''; # Only on first container
            if ($max == 1) {
                push @$field_list, "quantity-$id" => {
                    type => 'Hidden',
                    default => '1',
                    apply => [ { check => qr/^1$/ } ],
                };
            } else {
                push @$field_list, "quantity-$id" => {
                    type => 'Select',
                    label => 'Quantity',
                    tags => {
                        hint => "You can request a maximum of " . NUMWORDS($max) . " containers",
                        initial_hidden => 1,
                    },
                    options => [
                        { value => "", label => '-' },
                        map { { value => $_, label => $_ } } (1..$max),
                    ],
                    required_when => { "container-$id" => 1 },
                };
            }
            $c->cobrand->call_hook("bin_request_form_extra_fields", $service, $id, $field_list);
        }
    }

    $c->cobrand->call_hook("waste_munge_request_form_fields", $field_list);

    return $field_list;
}

sub request : Chained('property') : Args(0) {
    my ($self, $c) = @_;

    my %form_settings
        = $c->cobrand->call_hook( 'construct_bin_request_form', $c );

    my $field_list = $form_settings{field_list}
        || construct_bin_request_form($c);

    $c->stash->{first_page} = $form_settings{first_page} || 'request';

    my $cls = ucfirst $c->cobrand->council_url;
    $c->stash->{form_class} = "FixMyStreet::App::Form::Waste::Request::$cls";

    if ( $form_settings{page_list} ) {
        $c->stash->{page_list} = $form_settings{page_list};
    } else {
        my $next  = $c->cobrand->call_hook('waste_request_form_first_next');
        my $title = $c->cobrand->call_hook('waste_request_form_first_title')
            || 'Which containers do you need?';

        $c->stash->{page_list} = [
            request => {
                fields => [ grep { ! ref $_ } @$field_list, 'submit' ],
                title => $title,
                intro => 'request/intro.html',
                check_unique_id => 0,
                next => $next,
            },
        ];
    }

    $c->cobrand->call_hook("waste_munge_request_form_pages", $c->stash->{page_list}, $field_list);
    $c->stash->{field_list} = $field_list;
    $c->forward('form');
}

sub process_request_data : Private {
    my ($self, $c, $form, $reports, $unconfirmed) = @_;
    my $data = $form->saved_data;
    $c->cobrand->call_hook("waste_munge_request_form_data", $data);
    my @services = grep { /^container-/ && $data->{$_} } sort keys %$data;
    my @reports;
    push @reports, @$reports if $reports;

    my $payment = $data->{payment};
    foreach (@services) {
        my ($id) = /container-(.*)/;
        $c->cobrand->call_hook("waste_munge_request_data", $id, $data, $form);
        if ($payment) {
            unless ($c->cobrand->moniker eq 'kingston') {
                $c->set_param('payment', $payment);
            }
            $c->set_param('payment_method', $data->{payment_method} || 'credit_card');
        }
        $c->forward('add_report', [ $data, $unconfirmed || $payment ? 1 : 0 ]) or return;
        push @reports, $c->stash->{report};
    }
    group_reports($c, @reports);

    if ($payment) {
        if ( FixMyStreet->staging_flag('skip_waste_payment') ) {
            $c->stash->{message} = 'Payment skipped on staging';
            $c->stash->{reference} = $c->stash->{report}->id;
            $c->forward('confirm_subscription', [ $c->stash->{reference} ] );
        } else {
            if ( $c->stash->{staff_payments_allowed} eq 'paye' ) {
                $c->forward('csc_code');
            } else {
                $c->forward('pay', [ 'request' ]);
            }
        }
    }

    return 1;
}

sub process_garden_transfer : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;

    # Get the current subscription for the old address
    my $old_property_id = $data->{previous_ggw_address}->{value};
    #$c->forward('get_original_sub', ['', $old_property_id]);

    my $base = {};
    $base->{name} = $c->get_param('name');
    $base->{email} = $c->get_param('email');
    $base->{phone} = $c->get_param('phone');

    # Cancel the old subscription
    my $cancel = { %$base };
    $cancel->{category} = 'Cancel Garden Subscription';
    $cancel->{title} = 'Garden Subscription - Cancel';
    $cancel->{address} = $data->{previous_ggw_address}->{label};
    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $end_date_field = $c->cobrand->call_hook(alternative_backend_field_names => 'Subscription_End_Date') || 'Subscription_End_Date';
    $c->set_param($end_date_field, $now->ymd);
    $c->set_param('property_id', $old_property_id);
    $c->set_param('uprn', $data->{transfer_old_ggw_sub}{transfer_uprn});
    $c->set_param('transferred_to', $c->stash->{property}->{uprn});
    $c->forward('setup_garden_sub_params', [ $cancel, undef ]);
    $c->forward('add_report', [ $cancel ]) or return;
    $c->stash->{report}->confirm;
    $c->stash->{report}->update;

    # Create a report for it for the new address
    my $new = { %$base };
    $new->{category} = 'Garden Subscription';
    $new->{title} = 'Garden Subscription - New';
    $new->{bins_wanted} = $data->{transfer_old_ggw_sub}->{transfer_bin_number};
    $new->{transfer_bin_type} = $data->{transfer_old_ggw_sub}->{transfer_bin_type};

    my $expiry = $data->{transfer_old_ggw_sub}->{subscription_enddate};
    $expiry = DateTime::Format::W3CDTF->parse_datetime($expiry);
    $c->set_param($end_date_field, $expiry->ymd);
    $c->set_param('property_id', '');
    $c->set_param('uprn', '');
    $c->set_param('transferred_from', $data->{transfer_old_ggw_sub}{transfer_uprn});
    $c->forward('setup_garden_sub_params', [ $new, $c->cobrand->waste_subscription_types->{New} ]);
    $c->forward('add_report', [ $new ]) or return;
    $c->stash->{report}->confirm;
    $c->stash->{report}->update;
}

sub group_reports {
    my ($c, @reports) = @_;
    my $report = shift @reports;
    if (@reports) {
        $report->set_extra_metadata(grouped_ids => [ map { $_->id } @reports ]);
        $report->set_extra_metadata(
            grouped_titles => [ map { $_->title } @reports ] );
        $report->update;
    }
    $c->stash->{report} = $report;
}

sub construct_bin_problem_form {
    my $c = shift;

    my $field_list = [];

    foreach (@{$c->stash->{service_data}}) {
        # next unless ( $_->{last} && $_->{report_allowed} && !$_->{report_open}) || $_->{report_only};
        my $id = $_->{service_id};
        my $name = $_->{service_name};
        push @$field_list, "service-$id" => {
            type => 'Checkbox',
            label => $name,
            option_label => $name,
        };
    }

    $c->cobrand->call_hook("waste_munge_problem_form_fields", $field_list);

    return $field_list;
}

sub problem : Chained('property') : Args(0) {
    my ($self, $c) = @_;

    my $field_list = construct_bin_problem_form($c);

    $c->stash->{first_page} = 'problem';
    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Problem';
    $c->stash->{page_list} = [
        problem => {
            fields => [ grep { ! ref $_ } @$field_list, 'submit' ],
            title => 'Report a problem with a bin',
            next => 'about_you',
        },
    ];
    $c->stash->{field_list} = $field_list;
    $c->forward('form');
}

sub process_problem_data : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;
    $c->cobrand->call_hook("waste_munge_problem_form_data", $data);
    my @services = grep { /^service-/ && $data->{$_} } sort keys %$data;
    my @reports;
    foreach (@services) {
        my ($id) = /service-(.*)/;
        return unless $c->cobrand->can("waste_munge_problem_data");
        $c->cobrand->call_hook("waste_munge_problem_data", $id, $data);
        $c->forward('add_report', [ $data ]) or return;
        push @reports, $c->stash->{report};
    }
    group_reports($c, @reports);
    return 1;
}

sub construct_bin_report_form {
    my $c = shift;

    my $field_list = [];

    my $show_all_services = $c->stash->{is_staff} && $c->get_param('additional');
    foreach (@{$c->stash->{service_data}}) {
        unless (
            ( $_->{last}
            && $_->{report_allowed}
            && !$_->{report_open} )
            || $_->{report_only}
            || $show_all_services )
        {
            next;
        }
        next if $_->{orange_bag}; # Merton special entries

        my $id = $_->{service_id};
        my $name = $_->{service_name};
        my $description = $_->{service_description};
        my $contains_html = $_->{service_description_contains_html};
        push @$field_list, "service-$id" => {
            type => 'Checkbox',
            label => $name,

            build_option_label_method => sub {
                return $name
                    unless $description;

                return $description
                    unless $contains_html;

                return FixMyStreet::Template::SafeString->new($description);
            },
        };
    }

    # XXX Should we refactor bulky into the general service data (above)?
    # Plus side, gets the report missed stuff built in; minus side it
    # doesn't have any next/last collection stuff which is assumed
    my $allow_report_bulky = 0;
    foreach (values %{ $c->stash->{bulky_missed} || {} }) {
        $allow_report_bulky = $_ if $_->{report_allowed} && !$_->{report_open};
    }
    if ($allow_report_bulky) {
        my $service_id = $allow_report_bulky->{service_id};
        my $service_name = $allow_report_bulky->{service_name};
        push @$field_list, "service-$service_id" => {
            type => 'Checkbox',
            label => "$service_name collection",
            option_label => "$service_name collection",
        };
    }

    $c->cobrand->call_hook("waste_munge_report_form_fields", $field_list);

    return $field_list;
}

sub report : Chained('property') : Args(0) {
    my ($self, $c) = @_;

    my $field_list = construct_bin_report_form($c);

    $c->stash->{first_page} = 'report';
    my $next = $c->cobrand->call_hook('waste_report_form_first_next') || 'about_you';

    $c->stash->{form_class} ||= 'FixMyStreet::App::Form::Waste::Report';
    $c->stash->{page_list} = [
        report => {
            fields => [ grep { ! ref $_ } @$field_list, 'submit' ],
            title => 'Select your missed collection',
            next => $next,
        },
    ];
    $c->cobrand->call_hook("waste_munge_report_form_pages", $c->stash->{page_list}, $field_list);
    $c->stash->{field_list} = $field_list;
    $c->forward('form');
}

sub process_report_data : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;
    $c->cobrand->call_hook("waste_munge_report_form_data", $data);
    my @services = grep { /^service-/ && $data->{$_} } sort keys %$data;
    my @reports;
    foreach (@services) {
        my ($id) = /service-(.*)/;
        $c->cobrand->call_hook("waste_munge_report_data", $id, $data);
        $c->forward('add_report', [ $data ]) or return;
        push @reports, $c->stash->{report};
    }
    group_reports($c, @reports);
    return 1;
}

sub enquiry : Chained('property') : Args(0) {
    my ($self, $c) = @_;

    if (my $template = $c->get_param('template')) {
        $c->stash->{template} = "waste/enquiry-$template.html";
        $c->detach;
    }

    $c->forward('setup_categories_and_bodies');

    my $category = $c->get_param('category');
    my $service = $c->get_param('service_id');
    $c->detach('property_redirect') unless $category;

    my ($contact) = grep { $_->category eq $category } @{$c->stash->{contacts}};
    $c->detach('property_redirect') unless $contact;

    my $field_list = [];
    my $staff_form;
    foreach (@{$contact->get_metadata_for_input}) {
        $staff_form = 1 if $_->{code} eq 'staff_form';
        next if ($_->{automated} || '') eq 'hidden_field';

        # Handle notices.
        if ($_->{variable} && $_->{variable} eq 'false') {
            push @$field_list, "extra_$_->{code}" => {
                type => 'Notice', label => $_->{description}, required => 0, widget => 'NoRender',
            };
            next;
        }

        if ($_->{code} eq 'Image') {
            push @$field_list, "location_photo_fileid" => {
                type => 'FileIdPhoto', num_photos_required => 0, linked_field => 'location_photo',
            };
            push @$field_list, "location_photo" => {
                label => $_->{description},
                type => 'Photo',
                tags => {
                    max_photos => 1,
                },
            };
            next;
        }

        my %config = (type => 'Text');
        my $datatype = $_->{datatype} || '';
        if ($datatype eq 'text') {
            %config = (type => 'TextArea');
        } elsif ($datatype eq 'multivaluelist') {
            my @options = map { { label => $_->{name}, value => $_->{key} } } @{$_->{values}};
            %config = (type => 'Multiple', widget => 'CheckboxGroup', options => \@options);
        } elsif ($datatype eq 'singlevaluelist') {
            my @options = map { { label => $_->{name}, value => $_->{key} } } @{$_->{values}};
            %config = (type => 'Select', widget => 'RadioGroup', options => \@options);
        }

        my $required = $_->{required} eq 'true' ? 1 : 0;
        push @$field_list, "extra_$_->{code}" => {
            %config, label => $_->{description}, required => $required
        };
    }

    my $staff = $c->user_exists && ($c->user->is_superuser || $c->user->from_body);
    $c->detach('/auth/redirect') if $staff_form && !$staff;
    $c->stash->{staff_form} = $staff_form;

    # If the contact has no extra fields (e.g. Peterborough) then skip to the
    # "about you" page instead of showing an empty first page.
    # NB this will mean you need to set $data->{category} in the cobrand's
    # waste_munge_enquiry_data.
    $c->stash->{first_page} = @$field_list ? 'enquiry' : 'about_you';

    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Enquiry';
    $c->stash->{page_list} = [
        enquiry => {
            fields => [ 'category', 'service_id', grep { ! ref $_ } @$field_list, 'continue' ],
            title => $category,
            next => 'about_you',
            update_field_list => sub {
                my $form = shift;
                my $c = $form->c;
                return {
                    category => { default => $c->get_param('category') },
                    service_id => { default => $c->get_param('service_id') },
                }
            }
        },
    ];
    $c->cobrand->call_hook("waste_munge_enquiry_form_pages", $c->stash->{page_list}, $field_list);
    $c->stash->{field_list} = $field_list;
    $c->forward('form');
}

sub process_enquiry_data : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;

    $c->cobrand->call_hook("waste_munge_enquiry_data", $data);

    # Read extra details in loop
    foreach (grep { /^extra_/ } keys %$data) {
        my ($id) = /^extra_(.*)/;
        $c->set_param($id, $data->{$_});
    }
    $c->set_param('service_id', $data->{service_id});
    $c->forward('add_report', [ $data ]) or return;
    return 1;
}

# staff should not be able to make payments for direct debit payments
# Except in Bexley
sub check_if_staff_can_pay : Private {
    my ($self, $c, $payment_type) = @_;

    return 1 if $c->cobrand->moniker eq 'bexley';

    if ( $c->stash->{staff_payments_allowed} ) {
        if ( $payment_type && $payment_type eq 'direct_debit' ) {
            $c->stash->{template} = 'waste/garden/staff_no_dd.html';
            $c->detach;
        }
    }

    return 1;
}

sub garden_setup : Chained('property') : PathPart('') : CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->detach('property_redirect') if $c->stash->{waste_features}->{garden_disabled};

    $c->stash->{garden_costs} = WasteWorks::Costs->new({ cobrand => $c->cobrand });
}

sub garden_check : Chained('garden_setup') : Args(0) {
    my ($self, $c) = @_;

    my $id = $c->stash->{property}->{id};
    my $uri = '/waste/' . $id;

    my $service = $c->cobrand->garden_current_subscription;
    if (!$service) {
        # If no subscription, go straight to /garden
        $uri .= '/garden';
    }
    $c->res->redirect($uri);
    $c->detach;
}

sub garden : Chained('garden_setup') : Args(0) {
    my ($self, $c) = @_;

    $c->detach('property_redirect') if $c->stash->{waste_features}->{garden_new_disabled};
    $c->detach('property_redirect') if $c->cobrand->garden_current_subscription;

    $c->stash->{first_page} = 'intro';
    $c->stash->{garden_form_data} = {
        max_bins => $c->cobrand->waste_garden_maximum
    };
    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden';
    $c->cobrand->call_hook('waste_garden_subscribe_form_setup');
    $c->forward('garden_form');
}

sub garden_modify : Chained('garden_setup') : Args(0) {
    my ($self, $c) = @_;

    my $service = $c->cobrand->garden_current_subscription;
    $c->detach('property_redirect') unless $service && !$service->{garden_due};
    $c->detach('property_redirect') if $c->stash->{waste_features}->{garden_modify_disabled};

    $c->detach( '/auth/redirect' ) unless $c->user_exists;

    if ($c->stash->{slwp_garden_sacks} && $service->{garden_container} == $GARDEN_IDS{$c->cobrand->moniker}{sack}) { # SLWP Sack
        if ($c->cobrand->moniker eq 'kingston') {
            my $payment_method = 'credit_card';
            $c->forward('check_if_staff_can_pay', [ $payment_method ]); # Should always be okay here
            $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden::Sacks::Purchase';
        } else {
            $c->detach('property_redirect');
        }
    } else {
        my $pick = $c->get_param('task') || '';
        if ($pick eq 'cancel') {
            $c->res->redirect('/waste/' . $c->stash->{property}{id} . '/garden_cancel');
            $c->detach;
        }

        $c->forward('get_original_sub', ['user']);

        my $max_bins = $c->cobrand->waste_garden_maximum;
        my $payment_method = 'credit_card';
        if ( $c->stash->{orig_sub} ) {
            my $orig_sub = $c->stash->{orig_sub};
            my $orig_payment_method = $orig_sub->get_extra_field_value('payment_method');
            $payment_method = $orig_payment_method if $orig_payment_method && $orig_payment_method ne 'csc';
        }

        $c->forward('check_if_staff_can_pay', [ $payment_method ]);

        $c->stash->{display_end_date} = DateTime::Format::W3CDTF->parse_datetime($service->{end_date});
        $c->stash->{garden_form_data} = {
            max_bins => $max_bins,
            bins => $service->{garden_bins},
            payment_method => $payment_method,
        };

        $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden::Modify';
    }

    $c->stash->{first_page} = 'intro';
    my $allowed = $c->cobrand->call_hook('waste_garden_allow_cancellation') || 'all';
    if ($allowed eq 'staff' && !$c->stash->{is_staff}) {
        $c->stash->{first_page} = 'alter';
    }

    $c->forward('garden_form');
}

sub garden_cancel : Chained('garden_setup') : Args(0) {
    my ($self, $c) = @_;

    $c->detach('property_redirect') unless $c->cobrand->garden_current_subscription;

    my $allowed = $c->cobrand->call_hook('waste_garden_allow_cancellation') || 'all';
    $c->detach('property_redirect') if $allowed eq 'staff' && !$c->stash->{is_staff};

    $c->detach( '/auth/redirect' ) unless $c->user_exists;

    $c->forward('get_original_sub', ['user']);

    my $payment_method = $c->forward('get_current_payment_method');
    $c->forward('check_if_staff_can_pay', [ $payment_method ]);

    $c->stash->{first_page} = 'intro';
    $c->stash->{form_class}
        = $c->cobrand->call_hook('waste_cancel_form_class')
        || 'FixMyStreet::App::Form::Waste::Garden::Cancel';
    $c->forward('form');
}

sub garden_renew : Chained('garden_setup') : Args(0) {
    my ($self, $c) = @_;

    $c->detach('property_redirect') if $c->stash->{waste_features}->{garden_renew_disabled};

    $c->forward('get_original_sub', ['any']);

    # direct debit renewal is automatic so you should not
    # be doing this
    my $service = $c->cobrand->garden_current_subscription;
    my $payment_method = $c->forward('get_current_payment_method');
    if ( $payment_method eq 'direct_debit' && !$c->cobrand->waste_sub_overdue( $service->{end_date} ) ) {
        $c->stash->{template} = 'waste/garden/dd_renewal_error.html';
        $c->detach;
    }

    if ($c->stash->{waste_features}->{ggw_discount_as_percent} && $c->stash->{is_staff}) {
        $c->stash->{first_page} = 'discount';
    } else {
        $c->stash->{first_page} = 'intro';
    }
    my $max_bins = $c->cobrand->waste_garden_maximum;
    $c->stash->{garden_form_data} = {
        max_bins => $max_bins,
        bins => $service->{garden_bins},
    };

    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden::Renew';
    $c->cobrand->call_hook('waste_garden_renew_form_setup');
    $c->forward('garden_form');
}

sub garden_transfer : Chained('garden_setup') : Args(0) {
    my ($self, $c) = @_;

    $c->detach( '/page_error_403_access_denied', [] ) unless $c->stash->{is_staff};

    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden::Transfer';
    $c->forward('form');
}

sub garden_form : Private {
    my ($self, $c) = @_;
    $c->forward('form');

    # We need to inspect the form to see if a discount has been applied, and if so,
    # adjust the already fetched cost data for display on the site
    my $data = $c->stash->{form}->saved_data;
    my $costs = $c->stash->{garden_costs};
    $costs->discount($data->{apply_discount});
}

sub process_garden_cancellation : Private {
    my ($self, $c, $form) = @_;

    my $payment_method = $c->forward('get_current_payment_method');
    my $data = $form->saved_data;

    unless ( $c->stash->{is_staff} ) {
        $data->{name} = $c->user->name || 'Unknown name';
        $data->{email} = $c->user->email;
        $data->{phone} = $c->user->phone;
    }
    $data->{category} = 'Cancel Garden Subscription';
    $data->{title} = 'Garden Subscription - Cancel';
    $data->{payment_method} = $payment_method;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $end_date_field = $c->cobrand->call_hook(alternative_backend_field_names => 'Subscription_End_Date') || 'Subscription_End_Date';
    $c->set_param($end_date_field, $now->dmy('/'));

    my $service = $c->cobrand->garden_current_subscription;
    # Not actually used by Kingston/Sutton
    if (!$c->stash->{slwp_garden_sacks} || $service->{garden_container} == $GARDEN_IDS{$c->cobrand->moniker}{bin240} || $service->{garden_container} == $GARDEN_IDS{$c->cobrand->moniker}{bin140}) {
        my $bin_count = $c->cobrand->get_current_garden_bins;
        $data->{new_bins} = $bin_count * -1;
    }
    $c->forward('setup_garden_sub_params', [ $data, undef ]);

    $c->forward('add_report', [ $data, 1 ]) or return;

    if ( FixMyStreet->staging_flag('skip_waste_payment') ) {
        $c->stash->{report}->confirm;
        $c->stash->{report}->update;
    } else {
        if ( $payment_method eq 'direct_debit' ) {
            $c->forward('direct_debit_cancel_sub');
        } else {
            $c->stash->{report}->confirm;
            $c->stash->{report}->update;
        }
    }
    return 1;
}

# We assume orig_sub has already tried to be fetched by this point
sub get_current_payment_method : Private {
    my ($self, $c) = @_;

    my $payment_method;

    if ($c->stash->{orig_sub}) {
        $payment_method = $c->stash->{orig_sub}->get_extra_field_value('payment_method');
    }

    return $payment_method || 'credit_card';

}

sub get_original_sub : Private {
    my ($self, $c, $type) = @_;

    my $extra = { '@>' => encode_json({ "_fields" => [ { name => "property_id", value => $c->stash->{property}{id} } ] }) };
    if ($c->cobrand->moniker eq 'bexley') {
        # Bexley doesn't store property_id
        $extra = { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => $c->stash->{property}{uprn} } ] }) };
    }

    my $p = $c->model('DB::Problem')->search({
        category => 'Garden Subscription',
        title => ['Garden Subscription - New', 'Garden Subscription - Renew'],
        extra => $extra,
        state => { '!=' => 'hidden' },
    })->order_by('-id')->to_body($c->cobrand->body);

    if ($type eq 'user' && !$c->stash->{is_staff}) {
        $p = $p->search({
            user_id => $c->user->id,
        });
    }

    my $r = $c->stash->{orig_sub} = $p->first;

    $c->cobrand->call_hook(waste_check_existing_dd => $r)
        if $r && ($r->get_extra_field_value('payment_method') || '') eq 'direct_debit';
}

sub setup_garden_sub_params : Private {
    my ($self, $c, $data, $type) = @_;

    my $address = $data->{address} || $c->stash->{property}->{address};

    $data->{detail} = "$data->{category}\n\n$address";

    my $service_id;
    if (my $service = $c->cobrand->garden_current_subscription) {
        $service_id = $service->{service_id};
    } elsif ($c->cobrand->can('garden_service_id')) { # XXX TODO Does Bexley need its own? Or is this actually Echo only?
        $service_id = $c->cobrand->garden_service_id;
    }
    $c->set_param('email_renewal_reminders_opt_in', $data->{email_renewal_reminders} eq 'Yes' ? 'Y' : 'N') if $data->{email_renewal_reminders};
    $c->set_param('service_id', $service_id);
    $c->set_param('current_containers', $data->{current_bins});
    $c->set_param('new_containers', $data->{new_bins});
    # Either the user picked in the form, or it was staff and so will be credit card (or overridden to csc if that used)
    $c->set_param('payment_method', $data->{payment_method} || 'credit_card');
    $c->cobrand->call_hook(waste_garden_sub_params => $data, $type);
}

sub process_garden_modification : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;

    $data->{category} = 'Garden Subscription';
    $data->{title} = 'Garden Subscription - Amend';

    my $payment;
    my $pro_rata;
    my $payment_method;
    # Needs to check current subscription too
    my $service = $c->cobrand->garden_current_subscription;
    my $costs = WasteWorks::Costs->new({ cobrand => $c->cobrand, discount => $data->{apply_discount} });
    if ($c->stash->{slwp_garden_sacks} && $service->{garden_container} == $GARDEN_IDS{$c->cobrand->moniker}{sack}) { # SLWP Sack
        # This must be Kingston
        $data->{bins_wanted} = 1;
        $data->{new_bins} = 1;
        $payment = $costs->sacks($data->{bins_wanted});
        $payment_method = 'credit_card';
        $pro_rata = $payment; # Set so goes through flow below
    } else {
        my $bin_count = $data->{bins_wanted};
        my $new_bins = $bin_count - $data->{current_bins};
        $data->{new_bins} = $new_bins;

        # One-off ad-hoc payment to be made now
        if ( $new_bins > 0 ) {
            my $cost_now_admin = $costs->new_bin_admin_fee($new_bins);
            $pro_rata = $costs->pro_rata_cost($new_bins);
            $c->set_param('pro_rata', $pro_rata);
            $c->set_param('admin_fee', $cost_now_admin);
        }
        $payment_method = $c->stash->{garden_form_data}->{payment_method};
        $payment = $costs->bins($bin_count);
        $payment = 0 if $payment_method ne 'direct_debit' && $new_bins < 0;

    }
    $c->set_param('payment', $payment);

    $c->forward('setup_garden_sub_params', [ $data, $c->cobrand->waste_subscription_types->{Amend} ]);
    $c->cobrand->call_hook(waste_garden_mod_params => $data);
    $c->forward('add_report', [ $data, 1 ]) or return;

    if ( FixMyStreet->staging_flag('skip_waste_payment') ) {
        $c->stash->{message} = 'Payment skipped on staging';
        $c->stash->{reference} = $c->stash->{report}->id;
        $c->forward('confirm_subscription', [ $c->stash->{reference} ] );
    } else {
        if ( $pro_rata && $c->stash->{staff_payments_allowed} eq 'paye' ) {
            $c->forward('csc_code');
        } elsif ( $payment_method eq 'direct_debit' ) {
            $c->forward('direct_debit_modify');
        } elsif ( $pro_rata ) {
            $c->forward('pay', [ 'garden_modify' ]);
        } else {
            if ( $c->stash->{staff_payments_allowed} ) {
                my $report = $c->stash->{report};
                $report->update_extra_field({ name => 'payment_method', value => 'csc' });
                $report->update;
            }
            $c->forward('confirm_subscription', [ undef ]);
        }
    }
    return 1;
}

sub process_garden_data : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;
    my $dd_flow = $data->{payment_method} && $data->{payment_method} eq 'direct_debit';
    my $type = $c->cobrand->waste_subscription_types->{New};
    $c->forward('process_garden_new_or_renew', [ $data, 'new', $type, $dd_flow ]);
}

sub process_garden_renew : Private {
    my ($self, $c, $form) = @_;

    my $data = $form->saved_data;
    my $service = $c->cobrand->garden_current_subscription;
    # If there is a service at all in Bexley, we want to renew, regardless of end date
    my $bexley = $c->cobrand->moniker eq 'bexley';
    my $new = !$service || (!$bexley && $c->cobrand->waste_sub_overdue($service->{end_date}));
    my $type = $new ? $c->cobrand->waste_subscription_types->{New} : $c->cobrand->waste_subscription_types->{Renew};

    # Get the payment method from the form data or the existing subscription
    my $payment_method = $data->{payment_method}
        || $c->forward('get_current_payment_method');

    my $dd_flow = $payment_method eq 'direct_debit';
    $c->forward('process_garden_new_or_renew', [ $data, 'renew', $type, $dd_flow ]);
}

sub process_garden_new_or_renew : Private {
    my ($self, $c, $data, $calc_type, $cat_type, $dd_flow) = @_;

    if ($cat_type eq $c->cobrand->waste_subscription_types->{New}) {
        $data->{category} = 'Garden Subscription';
        $data->{title} = 'Garden Subscription - New';
    } elsif ($cat_type eq $c->cobrand->waste_subscription_types->{Renew}) {
        $data->{category} = 'Garden Subscription';
        $data->{title} = 'Garden Subscription - Renew';
    }

    $c->forward('garden_calculate_subscription_payment', [ $calc_type, $data ]);
    $c->forward('setup_garden_sub_params', [ $data, $cat_type ]);
    $c->forward('add_report', [ $data, 1 ]) or return;

    if ($data->{new_bins} < 0 && $c->cobrand->call_hook('garden_renewal_reduction_sparks_container_removal')) {
        my $service = $c->cobrand->garden_current_subscription;
        my $id = $service ? $service->{garden_container} : $GARDEN_IDS{$c->cobrand->moniker}{bin240};
        my $data = {
            # Sutton request form needs container-choice and request_reason
            'container-choice' => $id,
            request_reason => 'collect',
            # Kingston needs container- (and removal- to convert into N requests)
            "container-$id" => 1,
            # Both use removal-, Kingston in core and Sutton specficially for this
            "removal-$id" => abs($data->{new_bins}),

            # From the garden data
            email => $data->{email},
            name => $data->{name},
            phone => $data->{phone},
            category => 'Request new container',
        };

        # Set up a fake form to pass to process_request_data
        my $cls = ucfirst $c->cobrand->council_url;
        my $form_class = "FixMyStreet::App::Form::Waste::Request::$cls";
        my $form = $form_class->new( page_list => [], page_name => 'summary', c => $c, saved_data => $data);
        # Pass in report so it can be grouped, and mustn't confirm report before payment
        $c->forward('process_request_data', [ $form, [ $c->stash->{report} ], 1 ]);
    }

    if ( FixMyStreet->staging_flag('skip_waste_payment') ) {
        $c->stash->{message} = 'Payment skipped on staging';
        $c->stash->{reference} = $c->stash->{report}->id;
        $c->forward('confirm_subscription', [ $c->stash->{reference} ] );
    } elsif ($c->cobrand->waste_cheque_payments && $data->{payment_method} eq 'cheque') {
        $c->stash->{action} = 'new_subscription';
        my $p = $c->stash->{report};
        $p->set_extra_metadata('chequeReference', $data->{cheque_reference});
        $p->update;
        $c->forward('confirm_subscription', [ undef ] );
    } else {
        if ($dd_flow) {
            if ($c->cobrand->direct_debit_collection_method eq 'internal') {
                $c->stash->{form_data} = $data;
                $c->forward('direct_debit_internal');
            } else {
                $c->forward('direct_debit');
            }
        } elsif ( $c->stash->{staff_payments_allowed} eq 'paye' ) {
            $c->forward('csc_code');
        } else {
            $c->forward('pay', [ $calc_type eq 'renew' ? 'garden_renew' : 'garden' ]);
        }
    }

    return 1;
}

sub garden_calculate_subscription_payment : Private {
    my ($self, $c, $type, $data) = @_;

    my $container = $data->{container_choice} || '';
    my $costs = WasteWorks::Costs->new({
        cobrand => $c->cobrand,
        discount => $data->{apply_discount},
        first_bin_discount => $c->cobrand->call_hook(garden_waste_first_bin_discount_applies => $data) || 0,
    });
    # Sack form handling
    if ($container eq 'sack') {
        if ($c->cobrand->moniker eq 'merton') {
            # If renewing from bin to sacks, need to know bins to remove - better place for this?
            my $sub = $c->cobrand->garden_current_subscription;
            $data->{current_bins} = $sub->{garden_bins} if $sub;
        }
        $data->{new_bins} = $data->{bins_wanted}; # Always want all of them delivered

        $c->set_param('payment', $costs->sacks($data->{bins_wanted}));
    } else {
        my $bin_count = $data->{bins_wanted};
        $data->{new_bins} = $bin_count - ($data->{current_bins} || 0);

        my $cost_pa;
        if ($type eq 'renew') {
            $cost_pa = $costs->bins_renewal($bin_count);
        } else {
            $cost_pa = $costs->bins($bin_count);
        }
        my $cost_now_admin = $costs->new_bin_admin_fee($data->{new_bins});

        $c->set_param('payment', $cost_pa);
        $c->set_param('admin_fee', $cost_now_admin);
    }
}

sub add_report : Private {
    my ( $self, $c, $data, $no_confirm ) = @_;

    $c->stash->{cobrand_data} = 'waste';
    $c->stash->{override_confirmation_template} ||= 'waste/confirmation.html';

    # Store the name of the first page of the wizard on the token
    # so Peterborough can show the appropriate confirmation page when the
    # confirmation link is followed.
    $c->stash->{token_extra_data} = {
        first_page => $c->stash->{first_page},
    };

    # Don’t let staff inadvertently change their name when making reports
    my $original_name = $c->user->name if $c->user_exists && $c->user->from_body && $c->user->email eq ($data->{email} || '');

    # We want to take what has been entered in the form, even if someone is logged in
    $c->stash->{ignore_logged_in_user} = 1;

    if ($c->user_exists) {
        if ($c->user->from_body && !$data->{email} && !$data->{phone}) {
            $c->set_param('form_as', 'anonymous_user');
        } elsif ($c->user->from_body && $c->user->email ne ($data->{email} || '')) {
            $c->set_param('form_as', 'another_user');
        }
        $c->set_param('username', $data->{email} || $data->{phone});
    } else {
        $c->set_param('username_register', $data->{email} || $data->{phone});
    }

    # Set the data as if a new report form has been submitted

    $c->set_param('submit_problem', 1);
    $c->set_param('pc', '');
    $c->set_param('non_public', 1);

    $c->set_param('name', $data->{name});
    $c->set_param('phone', $data->{phone});

    $c->set_param('category', $data->{category});
    $c->set_param('title', $data->{title});
    $c->set_param('detail', $data->{detail});
    $c->set_param('uprn', $c->stash->{property}{uprn}) unless $c->get_param('uprn');
    $c->set_param('property_id', $c->stash->{property}{id}) unless $c->get_param('property_id');

    # Data may contain duplicate photo data under different keys e.g.
    # 'item_photo_1' => 'c8a965ad74acad4104341a8ea893b1a1275efa4d.jpeg',
    # 'item_photo_1_fileid' => 'c8a965ad74acad4104341a8ea893b1a1275efa4d.jpeg'.
    # So ignore keys that end with 'fileid'.
    # XXX Should fix this so there isn't duplicate data across different keys.
    my @bulky_photo_data;
    push @bulky_photo_data, $data->{location_photo} if $data->{location_photo};
    for (grep { /^item_photo_\d+$/ } sort keys %$data) {
        push @bulky_photo_data, $data->{$_} if $data->{$_};
    }
    $c->stash->{bulky_photo_data} = \@bulky_photo_data;

    $c->forward('setup_categories_and_bodies') unless $c->stash->{contacts};
    $c->forward('/report/new/non_map_creation', [['/waste/remove_name_errors']]) or return;

    my $report = $c->stash->{report};

    # Never send questionnaires for waste reports
    $report->send_questionnaire(0);

    # store photos
    foreach (grep { /^(item|location)_photo/ } keys %$data) {
        next unless $data->{$_};
        my $k = $_;
        $k =~ s/^(.+)_fileid$/$1/;
        $report->set_extra_metadata($k => $data->{$_});
    }

    $report->set_extra_metadata(property_address => $c->stash->{property}{address});
    $report->set_extra_metadata(phone => $c->stash->{phone});
    $c->cobrand->call_hook('save_item_names_to_report' => $data);
    $report->update;

    # we don't want to confirm reports that are for things that require a payment because
    # we need to get the payment to confirm them.
    if ( $no_confirm ) {
        $report->state('unconfirmed');
        $report->confirmed(undef);
        $report->update;
    } else {
        if ($c->cobrand->call_hook('waste_auto_confirm_report', $report)) {
            $report->confirm;
            $report->update;
        }
        $c->forward('/report/new/redirect_or_confirm_creation', [ 1 ]);
    }

    $c->cobrand->call_hook('waste_post_report_creation', $report);

    $c->user->update({ name => $original_name }) if $original_name;

    $c->cobrand->call_hook(
        clear_cached_lookups_property => $c->stash->{property}{id},
        'skip_echo', # We do not want to remove/cancel anything in Echo just before payment
    );

    return 1;
}

sub remove_name_errors : Private {
    my ($self, $c) = @_;
    # We do not mind about missing title/split name here
    my $field_errors = $c->stash->{field_errors};
    delete $field_errors->{fms_extra_title};
    delete $field_errors->{first_name};
    delete $field_errors->{last_name};
}

sub setup_categories_and_bodies : Private {
    my ($self, $c) = @_;

    $c->stash->{fetch_all_areas} = 1;
    $c->stash->{area_check_action} = 'submit_problem';
    $c->forward('/council/load_and_check_areas', []);
    $c->forward('/report/new/setup_categories_and_bodies');
}

sub uprn_redirect : Path('/property') : Args(1) {
    my ($self, $c, $uprn) = @_;

    my $cfg = $c->cobrand->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $result = $echo->GetPointAddress($uprn, 'Uprn');
    $c->detach( '/page_error_404_not_found', [] ) unless $result;
    $c->res->redirect('/waste/' . $result->{Id});
}

sub property_redirect : Private {
    my ($self, $c) = @_;
    $c->res->redirect('/waste/' . $c->stash->{property}{id});
}

__PACKAGE__->meta->make_immutable;

1;
