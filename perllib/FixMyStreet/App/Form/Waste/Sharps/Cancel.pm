package FixMyStreet::App::Form::Waste::Sharps::Cancel;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Cancel your sharps collection',
    intro => 'bulky/cancel_intro.html',
    fields => [ 'confirm', 'submit' ],
    finished => sub {
        return $_[0]->wizard_finished('process_bulky_cancellation');
    },
    next => 'done',
);

has_page done => (
    title => 'Sharps collection cancelled',
    template => 'waste/bulky/booking_cancellation.html',
);

has_field confirm => (
    type => 'Checkbox',
    option_label => 'I confirm I wish to cancel my sharps collection',
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
