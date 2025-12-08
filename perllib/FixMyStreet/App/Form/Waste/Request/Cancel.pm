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
    build_option_label_method => sub {
        my $self = shift;
        my $c = $self->form->{c};
        my $text = "I would like to cancel my container request.";
        if ($c->stash->{request_to_cancel_is_paid}) {
            $text .= " I acknowledge that the payment will not be refunded."
        }
        return $text;
    },
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
    my $service_name = $c->stash->{request_to_cancel_service_name} || "";
    if ($service_name) {
        $service_name = lc $service_name;
        $service_name .= " ";
    }
    return "Cancel your $service_name" . "container request";
}

1;
