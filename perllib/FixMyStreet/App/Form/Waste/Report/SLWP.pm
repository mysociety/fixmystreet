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

has_page notes => (
    fields => ['extra_detail', 'continue'],
    title => 'Your missed collection',
    next => 'about_you',
);

has_field extra_detail => (
    type => 'Text',
    widget => 'Textarea',
    label => 'Please supply any additional information',
);

1;
