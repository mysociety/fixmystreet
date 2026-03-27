package FixMyStreet::App::Form::Waste::Sharps;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Bulky::Shared';

has sharps => ( is => 'ro', default => 1 );

has_page intro => (
    title => 'Request a sharps box delivery or collection',
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
        return 'delivery_glucose_monitor';
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
    fields => ['collect_location', 'collect_location_other', 'continue'],
    title => 'Collection details',
    next => sub {
        my $data = $_[0];
        return 'delivery_glucose_monitor' if $data->{sharps_delivering} eq 'Yes';
        return 'summary';
    },
);

has_field collect_location => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Where are the boxes located?',
    options => [
        { label => 'On the doorstep', value => 'On the doorstep' },
        { label => 'In the porch (needs to be unlocked)', value => 'In the porch' },
        { label => 'By the bins', value => 'By the bins' },
        { label => 'Report to office (flats or schools only)', value => 'Report to office' },
        { label => 'By communal entrance (flats only)', value => 'By communal entrance' },
        { label => 'Somewhere else? (please use the box below)', value => 'Somewhere else' },
    ],
);

has_field collect_location_other => (
    label => 'Further access details',
    type => 'Text',
    widget => 'Textarea',
    maxlength => 250,
    required_when => {
        collect_location => sub {
            ( $_[1]->form->field('collect_location')->value // '' ) eq 'Somewhere else';
        },
    },
    messages => {
        required => 'Location details are required',
    },
    tags => {
        hint => 'Please use this box to let us know about anything else we need to collect or deliver your sharps boxes',
    },
);

has_page delivery_glucose_monitor => (
    fields => ['deliver_glucose_monitor', 'continue'],
    intro => 'sharps/glucose.html',
    title => 'Delivery details',
    next => 'delivery_details',
);

has_field deliver_glucose_monitor => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Do you need to dispose of glucose monitoring devices (e.g. Dexcom, Omnipod devices or similar)?',
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
    tags => {
        hint => sub {
            ( $_[0]->form->saved_data->{deliver_glucose_monitor} // '' ) eq 'Yes'
                ? 'If you are disposing of glucose monitoring devices you can only request 5-litre boxes.'
                : '';
        },
    },
);

sub options_deliver_size {
    my $self = shift;
    my $data = $self->form->saved_data;

    my $disabled_small
        = ( $data->{deliver_glucose_monitor} // '' ) eq 'Yes' ? 1 : 0;

    return (
        { label => '1-litre', value => '1-litre', disabled => $disabled_small },
        { label => '5-litre', value => '5-litre', checked => $disabled_small },
    );
}

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
            $self->add_form_error('A maximum of 8 boxes can be collected per booking');
        }
        if ($small > 5) {
            $self->add_form_error('A maximum of 5 one-litre boxes can be collected per booking');
        }
        if ($large > 3) {
            $self->add_form_error('A maximum of 3 five-litre boxes can be collected per booking');
        }
    }

    if ($self->current_page->name eq 'delivery_details') {
        my $size = $self->field('deliver_size')->value || '';
        my $quantity = $self->field('deliver_quantity')->value || 0;
        if ($size eq '1-litre' && $quantity > 5) {
            $self->add_form_error('A maximum of 5 one-litre boxes can be delivered per booking');
        }
        if ($size eq '5-litre' && $quantity > 3) {
            $self->add_form_error('A maximum of 3 five-litre boxes can be delivered per booking');
        }
    }
}

1;
