package FixMyStreet::App::Form::Waste::Request::Sutton;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

has_page replacement => (
    fields => ['request_reason', 'continue'],
    title => 'Reason for request',
    next => 'about_you',
);

has_field request_reason => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Why do you need a replacement bin?',
    options => [
        { value => 'damaged', label => 'Damaged' },
        { value => 'missing', label => 'Missing' },
        { value => 'new_build', label => 'New build' },
        { value => 'more', label => 'Would like more recycling' },
    ],
);

1;
