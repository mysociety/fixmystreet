package FixMyStreet::App::Form::Waste::Request::Bexley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

# Shown as first page if property able to order Green Wheelie Bins
has_page household_size => (
    title => 'Household size',
    fields => [ 'household_size', 'continue' ],
    next => 'request',
);

has_field household_size => (
    type => 'Select',
    widget => 'RadioGroup',
    label   => 'How many people live at the property?',
    options => [
        map {
            label     => $_,
            value     => $_,
        },
        ( 1..4, '5 or more' )
    ],
);

1;
