package FixMyStreet::App::Form::Waste::Request::Merton;

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
    fields => ['request_reason', 'request_reason_text', 'continue'],
    title => 'Reason for request',
    next => 'about_you',
    field_ignore_list => sub {
        my $page = shift;
        if (!$page->form->{c}->stash->{is_staff}) {
            return ['request_reason_text'];
        } else {
            return [];
        };
    },
);

has_field request_reason => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Why do you need a replacement container?',
);

has_field request_reason_text => (
    required => 0,
    type => 'Text',
    widget => 'Textarea',
    label => 'Additional details',
    tags => { hint => 'Please enter any additional details that will help us with the request' },
);

sub options_request_reason {
    my $form = shift;
    my @options = (
        { value => 'new_build', label => 'I am a new resident without a container' },
        { value => 'damaged', label => 'Damaged' },
        { value => 'missing', label => 'Missing' },
        { value => 'more', label => 'I need an additional container/bin' },
    );
    return @options;
}

1;
