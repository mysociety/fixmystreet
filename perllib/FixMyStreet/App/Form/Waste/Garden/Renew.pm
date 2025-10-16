package FixMyStreet::App::Form::Waste::Garden::Renew;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';
use WasteWorks::Costs;

has_page discount => (
    next => 'intro',
    title => 'Discount',
    intro => 'garden/_renew_discount.html',
    fields => ['apply_discount', 'continue_choice'],
);

sub intro {
    return (
        title => 'Renew your garden waste subscription',
        template => 'waste/garden/renew.html',
        fields => ['current_bins', 'bins_wanted', 'payment_method', 'payment_explanation', 'cheque_reference', 'name', 'phone', 'email', 'email_renewal_reminders', 'continue_review'],
        field_ignore_list => sub {
            my $page = shift;
            my $c = $page->form->c;
            my @exclude;
            push @exclude, 'email_renewal_reminders' if !$c->cobrand->garden_subscription_email_renew_reminder_opt_in;
            push @exclude, ('payment_method', 'payment_explanation', 'cheque_reference') if $c->cobrand->garden_hide_payment_method_field;
            return \@exclude;
        },
        update_field_list => sub {
            my $form = shift;
            my $form_data = $form->saved_data;
            my $c = $form->{c};
            my $data = $c->stash->{garden_form_data};
            my $current_bins = $c->get_param('current_bins') || $form_data->{current_bins} || $data->{bins} || 0;
            my $bin_count = $c->get_param('bins_wanted') || $form_data->{bins_wanted} || $data->{bins} || 1;
            my $new_bins = $bin_count - $current_bins;

            my $edit_current_allowed = $c->cobrand->call_hook('waste_allow_current_bins_edit');
            my $bins_wanted_disabled = $c->cobrand->call_hook('waste_renewal_bins_wanted_disabled');
            my $costs = WasteWorks::Costs->new({
                cobrand => $c->cobrand,
                discount => $form_data->{apply_discount},
                first_bin_discount => $c->cobrand->call_hook(garden_waste_first_bin_discount_applies => $data) || 0,
            });
            my $cost_pa = $costs->bins_renewal($bin_count);
            my $cost_now_admin = $costs->new_bin_admin_fee($new_bins);
            $form->{c}->stash->{cost_pa} = $cost_pa / 100;
            $form->{c}->stash->{cost_now_admin} = $cost_now_admin / 100;
            $form->{c}->stash->{cost_now} = ($cost_now_admin + $cost_pa) / 100;

            my $max_bins = $data->{max_bins};
            my %bin_params = ( default => $data->{bins}, range_end => $max_bins );

            $form_data->{_direct_debit_internal} = 1 if $c->cobrand->direct_debit_collection_method eq 'internal';

            return {
                current_bins => { %bin_params, $edit_current_allowed ? (disabled=>0) : () },
                bins_wanted => { %bin_params, $bins_wanted_disabled ? (disabled=>1) : () },
            };
        },
        next => sub {
            my $data = shift;
            # If the user has selected direct debit, go to the bank details page
            # This allows the form to support switching from credit card to direct debit
            return 'bank_details'
                if $data->{_direct_debit_internal}
                && $data->{payment_method}
                && $data->{payment_method} eq 'direct_debit';
            return 'summary';
        },
    );
}

has_page intro => ( intro() );

with 'FixMyStreet::App::Form::Waste::Garden::EmailRenewalReminders';

has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Renew your garden waste subscription',
    template => 'waste/garden/subscribe_summary.html',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        my $data = $form->saved_data;

        my $current_bins = $data->{current_bins} || 0;
        my $bin_count = $data->{bins_wanted} || 1;
        my $new_bins = $bin_count - $current_bins;
        my $costs = WasteWorks::Costs->new({
            cobrand => $c->cobrand,
            discount => $data->{apply_discount},
            first_bin_discount => $c->cobrand->call_hook(garden_waste_first_bin_discount_applies => $data) || 0,
        });
        my ($cost_pa, $cost_now_admin);
        if (($data->{container_choice}||'') eq 'sack') {
            $cost_pa = $costs->sacks_renewal($bin_count);
            $cost_now_admin = 0;
        } else {
            $cost_pa = $costs->bins_renewal($bin_count);
            $cost_now_admin = $costs->new_bin_admin_fee($new_bins);
        }
        my $total = $cost_now_admin + $cost_pa;

        $data->{cost_now_admin} = $cost_now_admin / 100;
        $data->{cost_pa} = $cost_pa / 100;
        $data->{display_total} = $total / 100;

        if (!$c->stash->{is_staff} && $c->user_exists) {
            $data->{name} ||= $c->user->name;
            $data->{email} = $c->user->email;
            $data->{phone} ||= $c->user->phone;
        }

        my $button_text = 'Continue to payment';
        my $features = $form->{c}->cobrand->feature('waste_features');
        if ($c->stash->{is_staff} && $features->{text_for_waste_payment}) {
            $button_text = $features->{text_for_waste_payment};
        }

        return {submit => { value => $button_text }};
    },
    finished => sub {
        return $_[0]->wizard_finished('process_garden_renew');
    },
    next => 'done',
);

has_page done => (
    title => 'Subscription renewed',
    template => 'waste/garden/renewed.html',
);

has_field apply_discount => (
    type => 'Checkbox',
    build_label_method => sub {
        my $self = shift;
        my $percent = $self->parent->{c}->stash->{waste_features}->{ggw_discount_as_percent};
        return "$percent" . '% Customer discount';
    },
    option_label => 'Check box if customer is entitled to a discount',
);

has_field continue_choice => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
);

has_field current_bins => (
    type => 'Integer',
    label => 'Number of bins currently on site',
    tags => { number => 1 },
    required => 1,
    disabled => 1,
    range_start => 1,
);

sub bins_wanted_label_method {
    'Number of bins to be emptied (including bins already on site)';
}

has_field bins_wanted => (
    type => 'Integer',
    build_label_method => \&bins_wanted_label_method,
    tags => { number => 1 },
    required => 1,
    range_start => 1,
    tags => {
        hint => 'We will deliver, or remove, bins if this is different from the number of bins already on the property',
    }
);

with 'FixMyStreet::App::Form::Waste::Billing';
with 'FixMyStreet::App::Form::Waste::AboutYou';
with 'FixMyStreet::App::Form::Waste::GardenTandC';

has_field continue_review => (
    type => 'Submit',
    value => 'Review subscription',
    element_attr => { class => 'govuk-button' },
);

has_field submit => (
    type => 'Submit',
    value => 'Continue to payment',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

sub validate {
    my $self = shift;
    my $max_bins = $self->{c}->stash->{garden_form_data}->{max_bins};
    unless ( $self->field('bins_wanted')->is_inactive ) {
        my $total = $self->field('bins_wanted')->value;
        $self->add_form_error('The total number of bins cannot exceed ' . $max_bins)
            if $total > $max_bins;

        $self->add_form_error('The total number of bins must be at least 1')
            if $total == 0;
    }

    $self->next::method();
}

1;
