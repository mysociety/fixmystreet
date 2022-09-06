package FixMyStreet::App::Form::Waste::Request::Bromley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

has_page replacement => (
    fields => ['replacement_reason', 'continue'],
    title => 'Reason for replacement',
    next => 'about_you',
);

has_field replacement_reason => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Why do you need a replacement garden waste container?',
    options => [
        { value => 'damaged', label => 'Damaged' },
        { value => 'stolen', label => 'Stolen' },
        { value => 'taken', label => 'Taken by crew' },
    ],
);

1;
