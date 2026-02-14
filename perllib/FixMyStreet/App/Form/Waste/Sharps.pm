package FixMyStreet::App::Form::Waste::Sharps;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Bulky::Shared';

has sharps => ( is => 'ro', default => 1 );

has_page intro => (
    title => 'Book sharps collection',
    intro => 'sharps/intro.html',
    fields => ['continue'],
    next => 'about_you',
);

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'choose_date_earlier',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_page collection_and_delivery => (
    fields => ['sharps_collecting', 'sharps_delivering', 'continue'],
    title => 'Collection and delivery',
    next => sub {
        my $data = $_[0];
        return 'collection_quantities' if $data->{sharps_collecting} eq 'Yes';
        return 'delivery_details';
    },
);

has_field sharps_collecting => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Do you have sharps boxes that need collecting?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field sharps_delivering => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Do you need sharps boxes delivered?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_page collection_quantities => (
    fields => ['collect_small_quantity', 'collect_large_quantity', 'continue'],
    title => 'Collection quantities',
    next => 'collection_details',
);

has_field collect_small_quantity => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'How many 1-litre boxes do you need collected?',
    options => [
        map { { label => $_, value => $_ } } 0 .. 5,
    ],
);

has_field collect_large_quantity => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'How many 5-litre boxes do you need collected?',
    options => [
        map { { label => $_, value => $_ } } 0 .. 3,
    ],
);

has_page collection_details => (
    fields => ['collect_location', 'collect_glucose_monitor', 'collect_cytotoxic', 'continue'],
    title => 'Collection details',
    next => sub {
        my $data = $_[0];
        return 'delivery_details' if $data->{sharps_delivering} eq 'Yes';
        return 'summary';
    },
);

has_field collect_location => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Where are the boxes located?',
    options => [
        { label => 'Inside property', value => 'Inside property' },
        { label => 'Doorstep', value => 'Doorstep' },
    ],
);

has_field collect_glucose_monitor => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Do any of the boxes contain glucose monitoring devices?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field collect_cytotoxic => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Do any of the boxes contain cytotoxic waste?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_page delivery_details => (
    fields => ['deliver_size', 'deliver_quantity', 'continue'],
    title => 'Delivery details',
    next => 'summary',
);

has_field deliver_size => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'What size boxes do you need?',
    options => [
        { label => '1-litre', value => '1-litre' },
        { label => '5-litre', value => '5-litre' },
    ],
);

has_field deliver_quantity => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'How many boxes?',
    options => [
        map { { label => $_, value => $_ } } 1 .. 5,
    ],
);

has_field submit => (
    type => 'Submit',
    value => 'Submit booking',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

sub validate {
    my $self = shift;

    $self->next::method();

    if ($self->current_page->name eq 'collection_and_delivery') {
        my $collecting = $self->field('sharps_collecting')->value || '';
        my $delivering = $self->field('sharps_delivering')->value || '';
        if ($collecting eq 'No' && $delivering eq 'No') {
            $self->add_form_error('You must select at least one of collection or delivery');
        }
    }

    if ($self->current_page->name eq 'collection_quantities') {
        my $small = $self->field('collect_small_quantity')->value || 0;
        my $large = $self->field('collect_large_quantity')->value || 0;
        my $total = $small + $large;
        if ($total == 0) {
            $self->add_form_error('You must specify at least one box for collection');
        } elsif ($total > 8) {
            $self->add_form_error('You can collect a maximum of 8 boxes at a time');
        }
    }

    if ($self->current_page->name eq 'delivery_details') {
        my $size = $self->field('deliver_size')->value || '';
        my $quantity = $self->field('deliver_quantity')->value || 0;
        if ($size eq '5-litre' && $quantity > 3) {
            $self->add_form_error('You can request a maximum of 3 five-litre boxes');
        }
    }
}

1;
