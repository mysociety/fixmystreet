package FixMyStreet::App::Form::Waste::Garden::Cancel::Shared;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => intro();

sub intro {
    return (
        title => 'Cancel your garden waste subscription',
        template => 'waste/garden/cancel.html',
        fields => ['confirm', 'submit'],
        finished => sub {
            return $_[0]->wizard_finished('process_garden_cancellation');
        },
        next => 'done',
    );
}

has_page done => (
    title => 'Subscription cancelled',
    template => 'waste/garden/cancel_confirmation.html',
);

has_field submit => (
    type => 'Submit',
    value => 'Cancel subscription',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
