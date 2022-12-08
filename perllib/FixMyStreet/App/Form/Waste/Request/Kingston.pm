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
    next => 'about_you',
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

has_field submit => (
    type => 'Submit',
    value => 'Request container',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
