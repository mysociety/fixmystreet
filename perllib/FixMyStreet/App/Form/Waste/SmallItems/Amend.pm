package FixMyStreet::App::Form::Waste::SmallItems::Amend;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::SmallItems';

has_page intro => (
    title => 'Amend small items collection',
    intro => 'small_items/intro_amend.html',
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
