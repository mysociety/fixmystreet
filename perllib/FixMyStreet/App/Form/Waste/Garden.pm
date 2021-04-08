package FixMyStreet::App::Form::Waste::Garden;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_field service_id => ( type => 'Hidden' );

has_page intro => (
    title => 'Subscribe to the Green Garden Waste collection service',
    template => 'waste/garden/subscribe_intro.html',
    fields => ['continue'],
    next => 'existing',
);

has_page existing => (
    title => 'Subscribe to Green Garden Waste collections',
    template => 'waste/garden/subscribe_existing.html',
    fields => ['existing', 'existing_number', 'continue'],
    next => 'details',
);

has_page details => (
    title => 'Subscribe to Green Garden Waste collections',
    template => 'waste/garden/subscribe_details.html',
    fields => ['current_bins', 'new_bins', 'payment_method', 'billing_differ', 'billing_address', 'name', 'email', 'phone', 'password', 'continue_review'],
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;

        my $existing = $data->{existing_number} || 0;
        $existing = 0 if $data->{existing} eq 'no';
        my $cost = $form->{c}->cobrand->garden_waste_cost($data->{existing_number});
        $form->{c}->stash->{payment} = $cost / 100;
        return {
            current_bins => { default => $existing },
        };
    },
    next => 'summary',
);


has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Submit container request',
    template => 'waste/garden/subscribe_summary.html',
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $total = $form->{c}->cobrand->garden_waste_cost( $data->{new_bins} + $data->{current_bins} );
        $data->{display_total} = $total / 100;
        return {};
    },
    finished => sub {
        return $_[0]->wizard_finished('process_garden_data');
    },
    next => 'done',
);

has_page done => (
    title => 'Container request sent',
    template => 'waste/confirmation.html',
);

has_field existing => (
    type => 'Select',
    label => 'Do you already have one of these bins?',
    required => 1,
    tags => {
        hint => "For example, it may have been left at your house by the previous owner.",
    },
    widget => 'RadioGroup',
    options => [
        { value => 'yes', label => 'Yes', data_show => '#form-existing_number-row' },
        { value => 'no', label => 'No', data_hide => '#form-existing_number-row' },
    ],
);

has_field existing_number => (
    type => 'Integer',
    label => 'How many? (1-3)',
    tags => { number => 1 },
    validate_method => sub {
        my $self = shift;
        my $max_bins = $self->parent->{c}->stash->{garden_form_data}->{max_bins};
        if ( $self->parent->field('existing')->value eq 'yes' ) {
            $self->add_error('Please specify how many bins you already have')
                unless $self->value;
            $self->add_error("Existing bin count must be between 1 and $max_bins")
                if $self->value < 1 || $self->value > $max_bins;
        } else {
            return 1;
        }
    },
);

has_field current_bins => (
    type => 'Integer',
    label => 'Bins already on property (0-3)',
    tags => { number => 1 },
    required => 1,
    range_start => 0,
    range_end => 3,
);

has_field new_bins => (
    type => 'Integer',
    label => 'Additional bins required (0-3)',
    tags => { number => 1 },
    required => 1,
    range_start => 0,
    range_end => 3,
);

with 'FixMyStreet::App::Form::Waste::Billing';

has_field password => (
    type => 'Password',
    label => 'Password (optional)',
    tags => {
        hint => 'Choose a password to sign in and manage your account in the future. If you don’t pick a password, you will still be able to sign in by clicking a link in an email we send to you.',
    },
);

has_field tandc => (
    type => 'Checkbox',
    required => 1,
    label => 'Terms and conditions',
    option_label => FixMyStreet::Template::SafeString->new(
        'I agree to the <a href="" target="_blank">terms and conditions</a>',
    ),
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
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
    $self->add_form_error('Please specify how many bins you already have')
        unless $self->field('existing')->is_inactive || $self->field('existing')->value eq 'no' || $self->field('existing_number')->value;

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
