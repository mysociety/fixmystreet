package FixMyStreet::App::Form::Waste::Bulky::Amend;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Bulky::Shared';

has_page intro => (
    title => 'Amend bulky waste collection',
    intro => 'bulky/intro_amend.html',
    fields => ['continue'],
    next => 'choose_date_earlier',
);

has_field submit => (
    type => 'Submit',
    value => 'Amend booking',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
