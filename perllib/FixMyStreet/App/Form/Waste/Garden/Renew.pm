package FixMyStreet::App::Form::Waste::Garden::Renew;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Renew your green garden waste subscription',
    template => 'waste/garden/renew.html',
    fields => ['current_bins', 'bins_wanted', 'payment_method', 'cheque_reference', 'name', 'phone', 'email', 'continue_review'],
    field_ignore_list => sub {
        my $page = shift;
        my $c = $page->form->c;
        return ['payment_method', 'cheque_reference'] if $c->stash->{staff_payments_allowed} && !$c->cobrand->waste_staff_choose_payment_method;
    },
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        my $data = $c->stash->{garden_form_data};
        my $current_bins = $c->get_param('current_bins') || $form->saved_data->{current_bins} || $data->{bins};
        my $bin_count = $c->get_param('bins_wanted') || $form->saved_data->{bins_wanted} || $data->{bins};
        my $new_bins = $bin_count - $current_bins;

        my $edit_current_allowed = $c->cobrand->call_hook('waste_allow_current_bins_edit');
        my $cost_pa = $c->cobrand->garden_waste_cost_pa($bin_count);
        my $cost_now_admin = $c->cobrand->garden_waste_new_bin_admin_fee($new_bins);
        $form->{c}->stash->{cost_pa} = $cost_pa / 100;
        $form->{c}->stash->{cost_now_admin} = $cost_now_admin / 100;
        $form->{c}->stash->{cost_now} = ($cost_now_admin + $cost_pa) / 100;

        my $max_bins = $data->{max_bins};
        my %bin_params = ( default => $data->{bins}, range_end => $max_bins );

        return {
            current_bins => { %bin_params, $edit_current_allowed ? (disabled=>0) : () },
            bins_wanted => { %bin_params },
        };
    },
    next => 'summary',
);

has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Renew your green garden waste subscription',
    template => 'waste/garden/renew_summary.html',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        my $data = $form->saved_data;

        my $current_bins = $data->{current_bins};
        my $bin_count = $data->{bins_wanted};
        my $new_bins = $bin_count - $current_bins;
        my $cost_pa = $form->{c}->cobrand->garden_waste_cost_pa($bin_count);
        my $cost_now_admin = $form->{c}->cobrand->garden_waste_new_bin_admin_fee($new_bins);
        my $total = $cost_now_admin + $cost_pa;

        $data->{cost_now_admin} = $cost_now_admin / 100;
        $data->{cost_pa} = $cost_pa / 100;
        $data->{display_total} = $total / 100;

        if (!$c->stash->{is_staff} && $c->user_exists) {
            $data->{name} ||= $c->user->name;
            $data->{email} = $c->user->email;
            $data->{phone} ||= $c->user->phone;
        }
        return {};
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

has_field current_bins => (
    type => 'Integer',
    label => 'Number of bins currently on site',
    tags => { number => 1 },
    required => 1,
    disabled => 1,
    range_start => 1,
);

has_field bins_wanted => (
    type => 'Integer',
    label => 'Number of bins to be emptied (including bins already on site)',
    tags => { number => 1 },
    required => 1,
    range_start => 1,
    tags => {
        hint => 'We will deliver, or remove, bins if this is different from the number of bins already on the property',
    }
);

with 'FixMyStreet::App::Form::Waste::Billing';

has_field tandc => (
    type => 'Checkbox',
    required => 1,
    label => 'Terms and conditions',
    option_label => FixMyStreet::Template::SafeString->new(
        'I agree to the <a href="/about/garden_terms" target="_blank">terms and conditions</a>',
    ),
);

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
