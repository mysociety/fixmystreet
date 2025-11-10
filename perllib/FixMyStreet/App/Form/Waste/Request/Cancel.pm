package FixMyStreet::App::Form::Waste::Request::Cancel;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    fields => ['confirm'],
    finished => sub {
        return $_[0]->wizard_finished('process_request_cancellation');
    },
    next => 'done',
);

has title => ( is => 'ro', 'isa' => 'Str', lazy => 1, builder => '_build_title' );

has_page done => (
    title => 'Container request cancelled',
    template => 'waste/request_cancellation.html',
);

has_field confirm => (
    type => 'Checkbox',
    required => 1,
    label => "Confirm",
    option_label => "I acknowledge that the payment will not be refunded and would like to cancel my request",
);

has_field submit => (
    type => 'Submit',
    value => 'Cancel request',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

sub _build_title {
    my $self = shift;
    my $c = $self->form->{c};
    my $service_name = lc $c->stash->{request_to_cancel_service_name};
    return "Cancel your $service_name container request";
}

1;
