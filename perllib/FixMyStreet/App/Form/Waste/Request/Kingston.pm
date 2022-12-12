package FixMyStreet::App::Form::Waste::Request::Kingston;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    intro => 'about_you.html',
    title => 'About you',
    next => 'summary',
);

has_page replacement => (
    fields => ['request_reason', 'continue'],
    title => 'Reason for request',
    next => sub {
        my $data = shift;
        my $choice = $data->{"container-choice"};
        my $reason = $data->{request_reason};
        return 'recycling_swap' if $choice == 16 && $reason eq 'more';
        return 'recycling_number' if $choice == 16;
        return 'notes_missing' if $reason eq 'missing';
        return 'notes_damaged' if $reason eq 'damaged';
        return 'about_you';
    },
);

has_field request_reason => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Why do you need a replacement container?',
);

sub options_request_reason {
    my $form = shift;
    my $data = $form->saved_data;
    my $choice = $data->{'container-choice'} || 0;
    my $garden = $data->{'container-26'} || $data->{'container-27'} || $choice == 26 || $choice == 27;
    my $green_box = $data->{'container-16'} || ($data->{'container-choice'}||0) == 16;
    my @options;
    push @options, { value => 'new_build', label => 'I am a new resident without a container' }
        if !$garden;
    push @options, { value => 'damaged', label => 'My container is damaged' };
    push @options, { value => 'missing', label => 'My container is missing' };
    push @options, { value => 'more', label => 'I need an additional container/bin' }
        if $green_box;
    return @options;
}

has_page recycling_swap => (
    fields => ['recycling_swap', 'continue'],
    title => 'Reason for request',
    next => sub {
        my $data = shift;
        return 'recycling_swap_confirm' if $data->{recycling_swap} eq 'Yes';
        return 'recycling_number';
    },
);

has_field recycling_swap => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Would you like to replace your recycling box containers with a wheelie bin?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
    tags => {
        hint => 'If you already have 3 or more recycling box containers, you may swap them for a recycling wheelie bin.',
    },
);

has_page recycling_swap_confirm => (
    fields => ['recycling_swap_confirm', 'continue'],
    title => 'Reason for request',
    next => 'about_you',
);

has_field recycling_swap_confirm => (
    type => 'Checkbox',
    required => 1,
    label => 'Confirmation',
    option_label => 'I confirm that I have 3 or more recycling box containers',
);

has_page recycling_number => (
    fields => ['recycling_quantity', 'continue'],
    title => 'Quantity',
    next => sub {
        my $data = shift;
        my $reason = $data->{request_reason};
        return 'notes_missing' if $reason eq 'missing';
        return 'notes_damaged' if $reason eq 'damaged';
        return 'about_you';
    },
);

has_field recycling_quantity => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    build_label_method => sub {
        my $self = shift;
        my $reason = $self->parent->saved_data->{request_reason};
        return 'How many recycling boxes would you like?' if $reason eq 'new_build';
        return 'How many containers are missing?' if $reason eq 'missing';
        return 'How many containers are damaged?' if $reason eq 'damaged';
        return 'How many recycling boxes would you like?' if $reason eq 'more';
    },
);

sub options_recycling_quantity {
    my $form = shift;
    my @options = map { { value => $_, label => $_ } } (1..5);
    return @options;
}

has_page notes_missing => (
    fields => ['notes_missing', 'continue'],
    title => 'Extra information',
    next => 'about_you',
);

has_field notes_missing => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Can you give us any information about what happened to your container?',
);

has_page notes_damaged => (
    fields => ['notes_damaged', 'continue'],
    intro => 'request_notes_damaged.html',
    title => 'Extra information',
    next => 'about_you',
);

has_field notes_damaged => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'What happened to your container?',
);

sub options_notes_damaged {
    my $form = shift;
    my @options = (
        { value => 'collection', label => 'Damaged during collection' },
        { value => 'wear', label => 'Wear and tear' },
        { value => 'other', label => 'Other damage' },
    );
    return @options;
}

has_field submit => (
    type => 'Submit',
    value => 'Request container',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
