package FixMyStreet::App::Form::Waste::Bulky::Cancel;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Cancel your bulky collection',
    intro => 'bulky/cancel_intro.html',
    fields => [ 'confirm', 'submit' ],
    finished => sub {
        return $_[0]->wizard_finished('process_bulky_cancellation');
    },
    next => 'done',
);

has_page done => (
    title => 'Bulky collection cancelled',
    template => 'waste/bulky/booking_cancellation.html',
);

has_field confirm => (
    type => 'Checkbox',
    required => 1,
    label => "Confirm",
    build_option_label_method => sub {
        my $cobrand = $_[0]->form->{c}->cobrand;
        my $text = 'I confirm I wish to cancel my bulky collection';
        if ($cobrand->moniker eq 'kingston' || $cobrand->moniker eq 'sutton') {
            $text = 'I acknowledge that the collection fee is non-refundable and would like to cancel my bulky collection';
        }
        return $text;
    },
);

has_field submit => (
    type => 'Submit',
    value => 'Cancel collection',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
