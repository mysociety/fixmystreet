package FixMyStreet::App::Form::Waste::SmallItems::Cancel;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Cancel your small items collection',
    intro => 'bulky/cancel_intro.html',
    fields => [ 'confirm', 'submit' ],
    finished => sub {
        return $_[0]->wizard_finished('process_bulky_cancellation');
    },
    next => 'done',
);

has_page done => (
    title => 'Small items collection cancelled',
    template => 'waste/bulky/booking_cancellation.html',
);

has_field confirm => (
    type => 'Checkbox',
    option_label => 'I confirm I wish to cancel my small items collection',
    required => 1,
    label => "Confirm",
);

has_field submit => (
    type => 'Submit',
    value => 'Cancel collection',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
