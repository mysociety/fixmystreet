package FixMyStreet::App::Form::Waste::Report::SLWP;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Report';

has additional_collection => ( is => 'ro', lazy => 1, default => sub { $_[0]->c->get_param('additional') });

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    intro => 'about_you.html',
    title => 'About you',
    next => 'summary',
);

has_page summary => (
    fields => ['submit'],
    title => 'Submit missed collection',
    template => 'waste/summary_report.html',
    finished => sub {
        return $_[0]->wizard_finished('process_report_data');
    },
    update_field_list => sub {
        my $form = shift;
        if ($form->additional_collection) {
            return { submit => { value => 'Request additional collection' } };
        }
        return {};
    },
    next => 'done',
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
