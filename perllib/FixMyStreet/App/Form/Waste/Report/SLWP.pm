package FixMyStreet::App::Form::Waste::Report::SLWP;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Report';

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    intro => 'about_you.html',
    title => 'About you',
    next => 'summary',
);

1;

