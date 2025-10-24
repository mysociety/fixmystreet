package FixMyStreet::App::Form::Waste::Assisted;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page outcome_choice => (
    fields => ['outcome_choice', 'continue'],
    title => 'Assisted collection outcome',
    next => sub {
        my $data = shift;
        return 'summary' if $data->{outcome_choice} eq 'Deny';
        return 'outcome_details';
    },
);

has_page outcome_details => (
    title => 'Assisted collection details',
    fields => ['assisted_reason', 'assisted_duration', 'assisted_location', 'continue'],
    next => 'summary',
);

has_page summary => (
    fields => ['submit'],
    title => 'Submit assisted request response',
    template => 'waste/summary_assisted.html',
    finished => sub {
        return $_[0]->wizard_finished('process_assisted_data');
    },
    next => 'done',
);

has_page done => (
    title => 'Assisted collection response sent',
    template => 'waste/confirmation.html',
);

has_field outcome_choice => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    options => [
        {
            label => 'Deny',
            value => 'Deny',
        },
        {
            label => 'Approve',
            value => 'Approve',
        },
    ],
);

has_field assisted_reason => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    options => [
        {
            label => 'Physical',
            value => 'physical',
        },
        {
            label => 'Property',
            value => 'property',
        },
    ]
);

has_field assisted_duration => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    options => [
        {
            label => '3 months',
            value => '3 months',
        },
        {
            label => '6 months',
            value => '6 months',
        },
        {
            label => '12 months',
            value => '12 months',
        },
        {
            label => 'No end date',
            value => 'no end date',
        },
    ],
);

has_field assisted_location => (
    type => 'TextArea',
    required => 1,
    label => 'Location of collection'
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
);

has_field submit => (
    type => 'Submit',
    value => 'Submit response',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;

