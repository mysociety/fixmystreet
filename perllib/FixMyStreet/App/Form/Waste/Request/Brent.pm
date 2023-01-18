package FixMyStreet::App::Form::Waste::Request::Brent;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

use constant CONTAINER_GREY_BIN => 16;
use constant CONTAINER_BLUE_BIN => 6;
use constant CONTAINER_FOOD_CADDY => 11;
use constant CONTAINER_GREEN_BIN => 13;

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'summary',
);

has_page replacement => (
    fields => ['request_reason', 'continue'],
    title => 'Reason for request',
    next => sub {
        my $data = shift;
        my $choice = $data->{"container-choice"};
        my $refuse_bin = ($choice == CONTAINER_GREY_BIN);
        my $reason = $data->{request_reason};
        return 'notes_damaged' if $reason eq 'damaged' && $refuse_bin;
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
    my $refuse_bin = ($choice == CONTAINER_GREY_BIN);
    my $garden_bin = ($choice == CONTAINER_GREEN_BIN);
    my @options;
    push @options, { value => 'new_build', label => 'I am a new resident without a container' } if !$refuse_bin && !$garden_bin;
    push @options, { value => 'damaged', label => 'My container is damaged' };
    push @options, { value => 'missing', label => 'My container is missing' };
    push @options, { value => 'extra', label => 'I would like an extra container' } if !$refuse_bin && !$garden_bin;
    return @options;
}

has_page notes_damaged => (
    fields => ['notes_damaged', 'continue'],
    title => 'Extra information',
    next => sub {
        my $data = shift;
        if ($data->{'notes_damaged'} eq 'collection') {
            return 'details_damaged';
        } else {
            return 'about_you';
        }
    },
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

has_page details_damaged => (
    fields => ['details_damaged', 'continue'],
    title => 'Collection damage',
    next => 'about_you',
);

has_field details_damaged => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Please describe how your container was damaged',
);

has_field submit => (
    type => 'Submit',
    value => 'Request container',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
