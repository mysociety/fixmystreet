package FixMyStreet::App::Form::Waste::Sharps;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Bulky::Shared';

has_page intro => (
    title => 'Book sharps collection',
    intro => 'sharps/intro.html',
    fields => ['continue'],
    next => 'about_you',
);

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'choose_date_earlier',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

# XXX
# May need to be more than one page?
has_page extra_questions => (
    fields => ['continue'],
    title => 'Extra questions',
    next => 'summary',
);

has_field submit => (
    type => 'Submit',
    value => 'Submit booking',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
