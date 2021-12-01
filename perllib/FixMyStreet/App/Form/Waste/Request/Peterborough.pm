package FixMyStreet::App::Form::Waste::Request::Peterborough;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

# This custom class is necessary to use "bin" instead of "container" in the UI,
# that's all.

has_page summary => (
    fields => ['submit'],
    title => 'Submit bin request',
    template => 'waste/summary_request.html',
    finished => sub {
        return $_[0]->wizard_finished('process_request_data');
    },
    next => 'done',
);

has_field submit => (
    type => 'Submit',
    value => 'Request new bins',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
