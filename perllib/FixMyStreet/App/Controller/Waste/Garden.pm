package FixMyStreet::App::Controller::Waste::Garden;
use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::App::Controller::Form' }

use utf8;
use FixMyStreet::App::Form::Waste::Garden;
use FixMyStreet::App::Form::Waste::Garden::Modify;
use FixMyStreet::App::Form::Waste::Garden::Cancel;
use FixMyStreet::App::Form::Waste::Garden::Renew;
use FixMyStreet::App::Form::Waste::Garden::Sacks::Purchase;
use FixMyStreet::App::Form::Waste::Garden::Transfer;
use WasteWorks::Costs;
use Hash::Util qw(lock_hash);

has feature => (
    is => 'ro',
    default => 'waste',
);

has index_template => (
    is => 'ro',
    default => 'waste/form.html'
);

my %GARDEN_IDS = (
    merton => { bin240 => 39, bin140 => 37, sack => 36 },
    kingston => { bin240 => 39, bin140 => 37, sack => 36 },
    sutton => { bin240 => 39, bin140 => 37, sack => 36 },
);
lock_hash(%GARDEN_IDS);

sub setup : Chained('/waste/property') : PathPart('') : CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->detach('/waste/property_redirect') if $c->stash->{waste_features}->{garden_disabled};

    $c->stash->{garden_costs} = WasteWorks::Costs->new({ cobrand => $c->cobrand });
}

sub check : Chained('setup') : PathPart('garden_check') : Args(0) {
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

sub subscribe : Chained('setup') : PathPart('garden') : Args(0) {
    my ($self, $c) = @_;

    $c->detach('/waste/property_redirect') if $c->stash->{waste_features}->{garden_new_disabled};
    $c->detach('/waste/property_redirect') if $c->cobrand->garden_current_subscription;

    $c->stash->{first_page} = 'intro';
    $c->stash->{garden_form_data} = {
        max_bins => $c->cobrand->waste_garden_maximum
    };
    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden';
    $c->cobrand->call_hook('waste_garden_subscribe_form_setup');
    $c->forward('garden_form');
}

sub modify : Chained('setup') : PathPart('garden_modify') : Args(0) {
    my ($self, $c) = @_;

    my $service = $c->cobrand->garden_current_subscription;
    $c->detach('/waste/property_redirect') unless $service && !$service->{garden_due};
    $c->detach('/waste/property_redirect') if $c->stash->{waste_features}->{garden_modify_disabled};

    $c->detach( '/auth/redirect' ) unless $c->user_exists;

    if ($c->stash->{slwp_garden_sacks} && $service->{garden_container} == $GARDEN_IDS{$c->cobrand->moniker}{sack}) { # SLWP Sack
        if ($c->cobrand->moniker eq 'kingston') {
            my $payment_method = 'credit_card';
            $c->forward('check_if_staff_can_pay', [ $payment_method ]); # Should always be okay here
            $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden::Sacks::Purchase';
        } else {
            $c->detach('/waste/property_redirect');
        }
    } else {
        my $pick = $c->get_param('task') || '';
        if ($pick eq 'cancel') {
            $c->res->redirect('/waste/' . $c->stash->{property}{id} . '/garden_cancel');
            $c->detach;
        }

        $c->forward('/waste/get_original_sub', ['user']);

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

sub cancel : Chained('setup') : PathPart('garden_cancel') : Args(0) {
    my ($self, $c) = @_;

    $c->detach('/waste/property_redirect') unless $c->cobrand->garden_current_subscription;

    my $allowed = $c->cobrand->call_hook('waste_garden_allow_cancellation') || 'all';
    $c->detach('/waste/property_redirect') if $allowed eq 'staff' && !$c->stash->{is_staff};

    $c->detach( '/auth/redirect' ) unless $c->user_exists;

    $c->forward('/waste/get_original_sub', ['user']);

    my $payment_method = $c->forward('/waste/get_current_payment_method');
    $c->forward('check_if_staff_can_pay', [ $payment_method ]);

    $c->stash->{first_page} = 'intro';
    $c->stash->{form_class}
        = $c->cobrand->call_hook('waste_cancel_form_class')
        || 'FixMyStreet::App::Form::Waste::Garden::Cancel';
    $c->forward('form');
}

sub renew : Chained('setup') : PathPart('garden_renew') : Args(0) {
    my ($self, $c) = @_;

    $c->detach('/waste/property_redirect') if $c->stash->{waste_features}->{garden_renew_disabled};

    $c->forward('/waste/get_original_sub', ['any']);

    # direct debit renewal is automatic so you should not
    # be doing this
    my $service = $c->cobrand->garden_current_subscription;
    my $payment_method = $c->forward('/waste/get_current_payment_method');
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

sub transfer : Chained('setup') : PathPart('garden_transfer') : Args(0) {
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

    my $payment_method = $c->forward('/waste/get_current_payment_method');
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

    $c->forward('/waste/add_report', [ $data, 1 ]) or return;

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
    $c->forward('/waste/add_report', [ $data, 1 ]) or return;

    if ( FixMyStreet->staging_flag('skip_waste_payment') ) {
        $c->forward('/waste/pay_skip', []);
    } else {
        if ( $pro_rata && $c->stash->{staff_payments_allowed} eq 'paye' ) {
            $c->forward('/waste/csc_code');
        } elsif ( $payment_method eq 'direct_debit' ) {
            $c->forward('direct_debit_modify');
        } elsif ( $pro_rata ) {
            $c->forward('/waste/pay', [ 'garden/modify' ]);
        } else {
            if ( $c->stash->{staff_payments_allowed} ) {
                my $report = $c->stash->{report};
                $report->update_extra_field({ name => 'payment_method', value => 'csc' });
                $report->update;
            }
            $c->forward('/waste/confirm_subscription', [ undef ]);
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
        || $c->forward('/waste/get_current_payment_method');

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
    $c->forward('/waste/add_report', [ $data, 1 ]) or return;

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
        $c->forward('/waste/process_request_data', [ $form, [ $c->stash->{report} ], 1 ]);
    }

    my $payment_method = $data->{payment_method} || '';
    if ( FixMyStreet->staging_flag('skip_waste_payment') ) {
        $c->forward('/waste/pay_skip', []);
    } elsif ($c->cobrand->waste_cheque_payments && $payment_method eq 'cheque') {
        $c->forward('/waste/pay_skip', [ $data->{cheque_reference}, undef ]);
    } elsif ($payment_method eq 'waived') {
        $c->forward('/waste/pay_skip', [ undef, $data->{payment_explanation} ]);
    } else {
        if ($dd_flow) {
            if ($c->cobrand->direct_debit_collection_method eq 'internal') {
                $c->stash->{form_data} = $data;
                $c->forward('direct_debit_internal');
            } else {
                $c->forward('direct_debit');
            }
        } elsif ( $c->stash->{staff_payments_allowed} eq 'paye' ) {
            $c->forward('/waste/csc_code');
        } else {
            $c->forward('/waste/pay', [ $calc_type eq 'renew' ? 'garden/renew' : 'garden/subscribe' ]);
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
    $c->forward('/waste/add_report', [ $cancel ]) or return;
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
    $c->forward('/waste/add_report', [ $new ]) or return;
    $c->stash->{report}->confirm;
    $c->stash->{report}->update;
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

# Direct debit code

sub direct_debit : Path('/waste/dd') : Args(0) {
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

    # Set an override template, so that the form processing can finish (to e.g.
    # clear the session unique ID to prevent double submission) and have the
    # form code load this template rather than the default 'done' form one
    $c->stash->{override_template} = $c->stash->{template};
    return 1;
}

# we process direct debit payments when they happen so this page
# is only for setting expectations.
sub direct_debit_complete : Path('/waste/dd_complete') : Args(0) {
    my ($self, $c) = @_;

    $c->cobrand->call_hook( 'garden_waste_dd_check_success' => $c );
    my ($token, $id) = $c->cobrand->call_hook( 'garden_waste_dd_get_redirect_params' => $c );
    $c->forward('/waste/check_payment_redirect_id', [ $id, $token]);
    $c->cobrand->call_hook( 'garden_waste_dd_complete' => $c->stash->{report} );

    $c->stash->{title} = "Direct Debit mandate";

    $c->send_email('waste/direct_debit_in_progress.txt', {
        to => [ [ $c->stash->{report}->user->email, $c->stash->{report}->name ] ],
        sent_confirm_id_ref => $c->stash->{report}->id,
    } );

    $c->stash->{template} = 'waste/dd_complete.html';
}

sub direct_debit_cancelled : Path('/waste/dd_cancelled') : Args(0) {
    my ($self, $c) = @_;

    my ($token, $id) = $c->cobrand->call_hook( 'garden_waste_dd_get_redirect_params' => $c );
    if ( $id && $token ) {
        $c->forward('/waste/check_payment_redirect_id', [ $id, $token ]);
        $c->forward('populate_dd_details');
    }

    $c->stash->{template} = 'waste/dd_cancelled.html';
}

sub direct_debit_error : Path('/waste/dd_error') : Args(0) {
    my ($self, $c) = @_;

    my ($token, $id) = $c->cobrand->call_hook( 'garden_waste_dd_get_redirect_params' => $c );
    if ( $id && $token ) {
        $c->forward('/waste/check_payment_redirect_id', [ $id, $token ]);
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

sub populate_dd_details : Private {
    my ($self, $c) = @_;

    $c->forward('/waste/populate_payment_details');

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

1;
