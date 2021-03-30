package FixMyStreet::App::Form::Waste::Garden::Renew;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Renew your green garden waste subscription',
    template => 'waste/garden/renew.html',
    fields => ['current_bins', 'new_bins', 'payment_method', 'billing_differ', 'billing_address', 'name', 'phone', 'email', 'continue_review'],
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        $c->stash->{per_bin_cost} = $c->cobrand->garden_waste_cost;
        return {
            current_bins => { default => $c->stash->{garden_form_data}->{bins} },
            name => { default => $c->user->name },
            email => { default => $c->user->email },
            phone => { default => $c->user->phone },
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
        my $new_bins = $data->{new_bins};

        my $total = $c->cobrand->garden_waste_cost( $new_bins + $current_bins);

        my $orig_sub = $c->stash->{orig_sub};
        if ( $orig_sub ) {
            $data->{billing_address} = $orig_sub->get_extra_field_value('billing_address');
        }
        $data->{bin_number} = $current_bins + $new_bins;
        $data->{billing_address} ||= $c->stash->{property}{address};
        $data->{display_total} = $total / 100;

        $data->{name} = $c->user->name;
        $data->{email} = $c->user->email;
        $data->{phone} = $c->user->phone;
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
    label => 'Bins already on property',
    tags => { number => 1 },
    required => 1,
    range_start => 1,
    range_end => 3,
);

has_field new_bins => (
    type => 'Integer',
    label => 'Additional bins required',
    tags => { number => 1 },
    range_start => 0,
    range_end => 3,
);


with 'FixMyStreet::App::Form::Waste::Billing';

has_field tandc => (
    type => 'Checkbox',
    required => 1,
    label => 'Terms and conditions',
    option_label => FixMyStreet::Template::SafeString->new(
        'I agree to the <a href="" target="_blank">terms and conditions</a>',
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
    unless ( $self->field('current_bins')->is_inactive ) {
        my $total = $self->field('current_bins')->value + $self->field('new_bins')->value;
        $self->add_form_error('The total number of bins cannot exceed ' . $max_bins)
            if $total > $max_bins;

        $self->add_form_error('The total number of bins must be at least 1')
            if $total == 0;
    }
}

1;
