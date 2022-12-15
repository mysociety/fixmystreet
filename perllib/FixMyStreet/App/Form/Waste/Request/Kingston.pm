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
        my $reason = $data->{request_reason};
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
    my @options;
    push @options, { value => 'new_build', label => 'I am a new resident without a container' }
        if !$garden;
    push @options, { value => 'damaged', label => 'My container is damaged' };
    push @options, { value => 'missing', label => 'My container is missing' };
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
