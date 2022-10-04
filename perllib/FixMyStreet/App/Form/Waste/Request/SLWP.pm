package FixMyStreet::App::Form::Waste::Request::SLWP;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    intro => 'about_you.html',
    title => 'About you',
    next => 'summary',
);

has_page replacement => (
    fields => ['request_reason', 'continue'],
    title => 'Reason for request',
    next => 'about_you',
);

has_field request_reason => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Why do you need a replacement bin?',
    validate_method => sub {
        my $self = shift;
        if ($self->value eq 'more') {
            my $data = $self->form->saved_data;
            if ($data->{"quantity-16"} > 1) {
                $data->{"quantity-16"} = 1;
            }
        }
    },
);

sub options_request_reason {
    my $form = shift;
    my @options = (
        { value => 'damaged', label => 'Damaged' },
        { value => 'missing', label => 'Missing' },
        { value => 'new_build', label => 'I am a new resident' },
    );
    if ($form->saved_data->{"container-16"}) {
        push @options, { value => 'more', label => 'I would like an extra recycling container' };
    }
    return @options;
}

1;
