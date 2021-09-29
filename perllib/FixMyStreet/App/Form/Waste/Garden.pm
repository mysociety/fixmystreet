package FixMyStreet::App::Form::Waste::Garden;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_field service_id => ( type => 'Hidden' );
has_field is_staff => ( type => 'Hidden' );

sub details_update_fields {
    my $form = shift;
    my $data = $form->saved_data;
    my $c = $form->{c};

    my $existing = $data->{existing_number} || 0;
    $existing = 0 if $data->{existing} eq 'no';
    my $bin_count = $c->get_param('bins_wanted') || $form->saved_data->{bins_wanted} || $existing;
    my $cost = $bin_count == 0 ? 0 : $form->{c}->cobrand->garden_waste_cost($bin_count);
    $form->{c}->stash->{payment} = $cost / 100;
    return {
        current_bins => { default => $existing },
        bins_wanted => { default => $bin_count },
    };
}

has_page intro => (
    title => 'Subscribe to the Green Garden Waste collection service',
    template => 'waste/garden/subscribe_intro.html',
    fields => ['continue'],
    update_field_list => sub {
        my $form = shift;
        return {
            is_staff => { default => $form->{c}->stash->{staff_payments_allowed} || 0 }
        };
    },
    next => 'existing',
);

has_page existing => (
    title => 'Subscribe to Green Garden Waste collections',
    template => 'waste/garden/subscribe_existing.html',
    fields => ['existing', 'existing_number', 'continue'],
    next => sub { return $_[0]->{is_staff} ? 'details_staff' : 'details'; },
);

has_page details => (
    title => 'Subscribe to Green Garden Waste collections',
    template => 'waste/garden/subscribe_details.html',
    fields => ['current_bins', 'bins_wanted', 'payment_method', 'billing_differ', 'billing_address', 'name', 'email', 'phone', 'password', 'continue_review'],
    update_field_list => \&details_update_fields,
    next => 'summary',
);

has_page details_staff => (
    title => 'Subscribe to Green Garden Waste collections',
    template => 'waste/garden/subscribe_details.html',
    fields => ['current_bins', 'bins_wanted', 'name', 'email', 'phone', 'continue_review'],
    update_field_list => \&details_update_fields,
    next => 'summary',
);


has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Submit container request',
    template => 'waste/garden/subscribe_summary.html',
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $total = $form->{c}->cobrand->garden_waste_cost( $data->{bins_wanted} );
        $data->{total_bins} = $data->{bins_wanted};
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
    label => 'How many? (1-6)',
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
    label => 'Number of bins currently on site (0-6)',
    required => 1,
    range_start => 0,
    range_end => 6,
);

has_field bins_wanted => (
    type => 'Integer',
    label => 'Number of bins to be emptied (including bins already on site) (0-6)',
    required => 1,
    range_start => 0,
    range_end => 6,
    tags => {
        hint => 'We will deliver, or remove, bins if this is different from the number of bins already on the property',
    },
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
        'I agree to the <a href="/about/garden_terms" target="_blank">terms and conditions</a>',
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
        my $total = $self->field('bins_wanted')->value;
        $self->add_form_error('The total number of bins cannot exceed ' . $max_bins)
            if $total > $max_bins;

        $self->add_form_error('The total number of bins must be at least 1')
            if $total == 0;
    }
}

1;
