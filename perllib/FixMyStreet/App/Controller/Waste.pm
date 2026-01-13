package FixMyStreet::App::Controller::Waste;
use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::App::Controller::Form' }

use utf8;
use Digest::SHA qw(sha1_hex);
use Lingua::EN::Inflect qw( NUMWORDS );
use List::Util qw(any);
use FixMyStreet::App::Form::Field::JSON;
use FixMyStreet::App::Form::Waste::UPRN;
use FixMyStreet::App::Form::Waste::AboutYou;
use FixMyStreet::App::Form::Waste::Report;
use FixMyStreet::App::Form::Waste::Problem;
use FixMyStreet::App::Form::Waste::Enquiry;
use FixMyStreet::App::Form::Waste::Assisted;
use FixMyStreet::App::Form::Waste::Request::Cancel;
use Memcached;
use JSON::MaybeXS;

has feature => (
    is => 'ro',
    default => 'waste',
);

has index_template => (
    is => 'ro',
    default => 'waste/form.html'
);

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
# might not be instant.
sub get_pending_subscription : Private {
    my ($self, $c) = @_;

    my $uprn = $c->stash->{property}{uprn};
    my ( $new, $cancel );

    if ( $c->cobrand->moniker eq 'bexley' ) {
        # This calls waste_check_existing_dd, so we can be sure that
        # direct_debit_status is set for check below
        $c->forward('get_original_sub', ['any']);

        my $subs = $c->model('DB::Problem')->search({
            # Bexley confirms garden reports immediately
            uprn => $c->stash->{property}{uprn},
            state => 'confirmed',
            created => { '>=' => \"current_timestamp-'20 days'::interval" },
            category => 'Garden Subscription',
            title => { -in => ['Garden Subscription - Renew', 'Garden Subscription - New'] },
        })->to_body($c->cobrand->body);

        my $status = $c->stash->{direct_debit_status} || '';
        while (my $sub = $subs->next) {
            $new = $sub if $status eq 'pending';
        }

    } else {
        my $subs = $c->model('DB::Problem')->search({
            uprn => $c->stash->{property}{uprn},
            state => 'unconfirmed',
            created => { '>=' => \"current_timestamp-'20 days'::interval" },
            category => { -in => ['Garden Subscription', 'Cancel Garden Subscription'] },
            title => { -in => ['Garden Subscription - Renew', 'Garden Subscription - New', 'Garden Subscription - Cancel'] },
        })->to_body($c->cobrand->body);

        while (my $sub = $subs->next) {
            my $payment_method = $sub->get_extra_field_value('payment_method') || '';
            if ( $payment_method eq 'direct_debit' ) {
                if ( $sub->title eq 'Garden Subscription - New' ||
                    $sub->title eq 'Garden Subscription - Renew' ) {
                    $new = $sub;
                } elsif ( $sub->title eq 'Garden Subscription - Cancel' ) {
                    $cancel = $sub;
                }
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

sub pay_process : Private {
    my ($self, $c, $type, $payment_method, $data, $dd_flow) = @_;
    $payment_method ||= '';

    if ( FixMyStreet->staging_flag('skip_waste_payment') ) {
        $c->forward('pay_skip', []);
    } elsif ($payment_method eq 'cheque') {
        $c->forward('pay_skip', [ $data->{cheque_reference}, undef ]);
    } elsif ($payment_method eq 'waived' || $payment_method eq 'cash') {
        $c->forward('pay_skip', [ undef, $data->{payment_explanation} ]);
    } else {
        if ($dd_flow) { # Garden only
            if ($c->cobrand->direct_debit_collection_method eq 'internal') {
                $c->stash->{form_data} = $data;
                $c->forward('/waste/garden/direct_debit_internal');
            } else {
                $c->forward('/waste/garden/direct_debit');
            }
        } elsif ( $c->stash->{staff_payments_allowed} eq 'paye' ) {
            $c->forward('csc_code');
        } else {
            $c->forward('pay', [ $type ]);
        }
    }
}

sub pay_skip : Private {
    my ($self, $c, $cheque, $waived) = @_;

    if (FixMyStreet->staging_flag('skip_waste_payment')) {
        $c->stash->{message} = 'Payment skipped on staging';
        $c->stash->{reference} = $c->stash->{report}->id;
        $c->forward('confirm_subscription', [ $c->stash->{reference} ] );
        return;
    }

    $c->stash->{action} = 'new_subscription';
    if ($waived) {
        my $p = $c->stash->{report};
        $p->set_extra_metadata('payment_explanation', $waived);
        $p->update;
    }
    $c->forward('confirm_subscription', [ $cheque ] );
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

    my $already_paid = $p->waste_check_payment_state;
    my $ref;
    if ($already_paid) {
        $ref = $p->get_extra_metadata('payment_reference');
    } else {
        $ref = $c->cobrand->waste_cc_check_payment_status($c, $p);
    }

    if ( $ref ) {
        $c->stash->{title} = 'Payment successful';
        $c->stash->{reference} = $ref;
        $c->forward( 'confirm_subscription', [ $ref, $already_paid ] );
    } else {
        $c->stash->{template} = 'waste/pay_error.html';
        $c->detach;
    }
}

sub confirm_subscription : Private {
    my ($self, $c, $reference, $already_paid) = @_;
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
    $p->waste_confirm_payment($reference) unless $already_paid;
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

    # Make sure report hasn't previously been cancelled.
    # When staff mark payment as failed, report may be cancelled
    # immediately (e.g. for bulky waste for certain cobrands),
    # but staff can click back and try to mark as successful.
    if ( $report->state eq 'cancelled' ) {
        $c->stash->{attempted_resubmission} = 1;
        $c->stash->{report} = $report;
        $c->stash->{property_id} = $report->waste_property_id;
        $c->stash->{template} = 'waste/garden/csc_payment_failed.html';
        $c->detach;
    }

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
    unless ($property && $property->{id}) {
        if ($c->cobrand->waste_suggest_retry_on_no_property_data) {
            $c->stash->{template} = 'waste/no_property_details_suggest_retry.html';
            $c->detach;
        }
        $c->detach( '/page_error_404_not_found', [] );
    }

    $c->stash->{latitude} = Utils::truncate_coordinate( $property->{latitude} );
    $c->stash->{longitude} = Utils::truncate_coordinate( $property->{longitude} );

    $c->stash->{service_data} = $c->cobrand->call_hook(bin_services_for_address => $property) || [];
    $c->stash->{services} = { map { $_->{service_id} => $_ } @{$c->stash->{service_data}} };

    my $calendar = $c->action eq 'waste/calendar_ics';
    return if $calendar; # Calendar doesn't need to look up collections

    if ($c->cobrand->can('find_booked_collections')) {
        my $cfg = $c->cobrand->feature('waste_features');
        my $retry = $cfg->{bulky_retry_bookings} && $c->stash->{is_staff};
        my $collections = $c->cobrand->find_booked_collections($property->{uprn}, 'recent', $retry);
        $c->stash->{collections} = $collections;
    }

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

    # Remove session cookie (created by caching of property data) so this
    # response can be cached. This deletes the session data but would still set
    # an immediately-expire cookie, so delete the cookie directly as well.
    $c->delete_session;
    delete $c->response->cookies->{$c->_session_plugin_config->{cookie_name}};

    require Data::ICal::RFC7986;
    require Data::ICal::Entry::Event;
    my $calendar = Data::ICal::RFC7986->new(
        calname => 'Bin calendar',
        rfc_strict => 1,
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
        my $date = $_->{date}->ymd('');
        $event->add_properties(
            summary => $_->{summary},
            description => $_->{desc},
            dtstamp => $stamp,
            dtstart => [ $date, { value => 'DATE' } ],
            dtend => [ $_->{date}->clone->add(days=>1)->ymd(''), { value => 'DATE' } ],
            uid => sha1_hex($date . $_->{summary}) . '@' . $c->req->uri->host,
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
            next unless $c->stash->{containers}->{$id}; # Must have a label
            next unless $max; # Must have a maximum quantity
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
    my $payment_method = $data->{payment_method} || 'credit_card';
    foreach (@services) {
        my ($id) = /container-(.*)/;
        $c->cobrand->waste_munge_request_data($id, $data, $form);
        if ($payment) {
            # "payment" param must be set in the munge function above with the cost for this entry
            $c->set_param('payment_method', $payment_method);
        }
        $c->forward('add_report', [ $data, $unconfirmed || $payment ? 1 : 0 ]) or return;
        push @reports, $c->stash->{report};
    }
    group_reports($c, @reports);

    if ($payment) {
        $c->forward('/waste/pay_process', [ 'request', $payment_method, $data ]);
    }

    return 1;
}

sub cancel_request : Chained('property') : PathPart('request/cancel') : Args(1) {
    my ($self, $c, $request_report_id) = @_;
    $c->detach( '/auth/redirect' ) unless $c->user_exists;

    my $request_report = $c->model('DB::Problem')->find( { id => $request_report_id } )
        || $c->detach('/waste/property_redirect');

    $c->detach('/waste/property_redirect')
        if !$c->cobrand->waste_can_cancel_request($request_report);

    # Try to get the service name
    my $service_id = $request_report->get_extra_field_value('service_id');
    my $service = $c->stash->{services}->{$service_id};
    my $service_name;
    if ($service) {
        $service_name = $service->{service_name};
    }

    $c->stash->{request_to_cancel} = $request_report;
    $c->stash->{request_to_cancel_is_paid} = $request_report->waste_has_payment;
    $c->stash->{request_to_cancel_description} = $c->cobrand->waste_container_request_description($request_report);
    $c->stash->{form_class} = "FixMyStreet::App::Form::Waste::Request::Cancel";
    $c->forward('form');
}

sub process_request_cancellation : Private {
    my ( $self, $c, $form ) = @_;
    my $report = $c->stash->{request_to_cancel};
    my $text = $c->cobrand->waste_container_request_cancellation_text($report);
    $report->add_to_comments({
        text => $text,
        user => $c->cobrand->body->comment_user || $report->user,
        extra => { request_cancellation => 1 },
        problem_state => 'cancelled',
    });
    $report->state('cancelled');
    $report->update;
    return 1;
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

sub assisted : Chained('property') : Args(1) {
    my ($self, $c, $report_id) = @_;

    my $staff = $c->user_exists && ($c->user->is_superuser || $c->user->from_body);
    $c->detach('property_redirect') unless $staff;

    my $request_report = FixMyStreet::DB->resultset('Problem')->search({ id => $report_id })->first;
    unless ($request_report->category eq 'Request assisted collection' && $request_report->state eq 'confirmed') {
        $c->detach('property_redirect');
    }

    $c->stash->{assisted_request_report} = $request_report;

    $c->stash->{first_page} = 'outcome_choice';
    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Assisted';
    $c->forward('form');
}

sub process_assisted_data : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;

    if ($data->{outcome_choice} eq 'Approve') {
        $data->{category} = 'Assisted collection add';
        $data->{name} = $c->user->name;
        $data->{email} = $c->user->email;
        $data->{title} = 'Confirm assisted collection';
        $data->{detail} = 'Generated by approval form';
        foreach my $id (grep { /^assisted_/ } keys %$data) {
            $c->set_param($id, $data->{$id});
        };
        $c->forward('add_report', [ $data ]);
        $c->forward('add_update_to_assisted_request', ['approve']);
    } else {
        $c->forward('add_update_to_assisted_request', ['deny']);
    }
}

sub add_update_to_assisted_request : Private {
    my ($self, $c, $response) = @_;

    my $report = $c->stash->{assisted_request_report};

    my $text;
    my $status;

    if ($response eq 'approve') {
        $text = 'Your request for an assisted collection has been approved';
        $status = 'fixed - council';
    } elsif ($response eq 'deny') {
        $text = 'Your request for an assisted collection has been denied';
        $status = 'closed';
    } else {
        return;
    };

    my $body = $c->cobrand->body;
    my $template = $report->response_template_for($body, $status, 'confirmed', '', '');
    $text = $template->text if $template;

    my $comment = $report->add_to_comments({
        text => $text,
        state => 'confirmed',
        problem_state => $status,
        user => $body->comment_user,
        confirmed => \'current_timestamp',
        send_state => 'processed',
    });

    $report->update({
        state => $status,
        lastupdate => \'current_timestamp',
    });
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
        my $report_allowed = !$show_all_services && $_->{last} && $_->{report_allowed} && !$_->{report_open};
        my $additional_allowed = $show_all_services && !$_->{additional_open};
        unless ( $report_allowed || $_->{report_only} || $additional_allowed ) {
            next;
        }

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

    # XXX Should we refactor bulky & small items into the general service
    # data (above)?
    # Plus side, gets the report missed stuff built in; minus side it
    # doesn't have any next/last collection stuff which is assumed.
    my $allow_report_bulky = 0;
    my $allow_report_small_items = 0;

    foreach ( values %{ $c->stash->{booked_missed} || {} } ) {
        if ( $_->{report_allowed} && !$_->{report_open} ) {
            $_->{service_name} eq 'Small items'
                ? $allow_report_small_items = $_
                : $allow_report_bulky = $_;
        }
    }
    for ( $allow_report_bulky, $allow_report_small_items ) {
        if ($_) {
            my $service_id = $_->{service_id};
            my $service_name = $_->{service_name};
            push @$field_list, "service-$service_id" => {
                type => 'Checkbox',
                label => "$service_name collection",
                option_label => "$service_name collection",
            };
        }
    }

    $c->cobrand->call_hook("waste_munge_report_form_fields", $field_list);

    return $field_list;
}

sub report : Chained('property') : Args(0) {
    my ($self, $c) = @_;

    $c->stash->{original_booking_report}
        = FixMyStreet::DB->resultset("Problem")
        ->find( { id => $c->get_param('original_booking_id') } )
        if $c->get_param('original_booking_id');

    my $field_list = construct_bin_report_form($c);

    # If there are no items to be chosen, redirect back to bin day page
    $c->detach('property_redirect') unless @$field_list;

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
            my $id = $c->stash->{property}->{id};
            $_->{description} =~ s/PROPERTY_ID/$id/;
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

    # Bexley special for assisted collection removal
    if ($c->cobrand->moniker eq 'bexley' && $category eq 'Assisted collection remove') {
        $c->detach('/auth/redirect') unless $staff || $c->stash->{user_requested_assisted};
    }

    # If the contact has no extra fields (e.g. Peterborough) then skip to the
    # "about you" page instead of showing an empty first page.
    $c->stash->{first_page} = @$field_list ? 'enquiry' : 'about_you';

    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Enquiry';
    $c->stash->{page_list} = [
        enquiry => {
            fields => [ grep { ! ref $_ } @$field_list, 'continue' ],
            title => $category,
            next => 'about_you',
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

# We assume orig_sub has already tried to be fetched by this point
sub get_current_payment_method : Private {
    my ($self, $c) = @_;

    my $payment_method;

    if ($c->stash->{orig_sub}) {
        $payment_method = $c->stash->{orig_sub}->get_extra_field_value('payment_method');
    }

    # Allow cobrand to override payment method detection for legacy subscriptions
    if (!$payment_method) {
        $payment_method = $c->cobrand->call_hook('waste_get_current_payment_method' => $c->stash->{orig_sub});
    }

    return $payment_method || 'credit_card';

}

sub get_original_sub : Private {
    my ($self, $c, $type) = @_;

    my $p = $c->model('DB::Problem')->search({
        uprn => $c->stash->{property}{uprn},
        category => 'Garden Subscription',
        title => ['Garden Subscription - New', 'Garden Subscription - Renew', 'Garden Subscription - Transfer'],
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
    my $original_name;
    if ($c->user_exists && $c->user->from_body && $c->user->email eq ($data->{email} || '')) {
        $original_name = $c->user->name;
    }

    # We want to take what has been entered in the form, even if someone is logged in
    $c->stash->{ignore_logged_in_user} = 1;

    # We don't want reporter updates on assisted collection adds, tells us nothing
    if ($data->{category} eq 'Assisted collection add') {
        $c->stash->{no_reporter_alert} = 1;
    }

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

    # Set UPRN on report
    $report->uprn($data->{uprn} || $c->stash->{property}{uprn});

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

    $c->cobrand->call_hook('waste_post_report_creation', $report, $data);

    $c->user->update({ name => $original_name }) if $original_name;

    $c->cobrand->call_hook(
        clear_cached_lookups_property => $c->stash->{property}{id},
    );
    $c->cobrand->call_hook(
        clear_cached_lookups_bulky_slots => $c->stash->{property}{id},
        skip_echo => 1, # We do not want to remove/cancel anything in Echo just before payment
        delete_guid => 1, # We don't need the cached GUID any more
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
    my $id = $c->cobrand->uprn_to_property_id($uprn);
    $c->detach( '/page_error_404_not_found', [] ) unless $id;
    $c->res->redirect('/waste/' . $id);
}

sub property_redirect : Private {
    my ($self, $c) = @_;
    $c->res->redirect('/waste/' . $c->stash->{property}{id});
}

__PACKAGE__->meta->make_immutable;

1;
