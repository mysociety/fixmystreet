package FixMyStreet::App::Form::Waste::Request;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

# First page has dynamic fields, so is set in code

has_page replacement => (
    fields => ['replacement_reason', 'continue'],
    title => 'Reason for replacement',
    next => 'about_you',
);

has_field replacement_reason => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Why do you need a replacement garden waste container?',
    options => [
        { value => 'damaged', label => 'Damaged' },
        { value => 'stolen', label => 'Stolen' },
        { value => 'taken', label => 'Taken by crew' },
    ],
);

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'summary',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_page summary => (
    fields => ['submit'],
    title => 'Submit container request',
    template => 'waste/summary_request.html',
    finished => sub {
        return $_[0]->wizard_finished('process_request_data');
    },
    next => 'done',
);

has_page done => (
    title => 'Container request sent',
    template => 'waste/confirmation.html',
);

has_field category => (
    type => 'Hidden',
    default => 'Request new container',
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
);

has_field submit => (
    type => 'Submit',
    value => 'Request new containers',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

sub validate {
    my $self = shift;
    my $any = 0;

    foreach ($self->all_fields) {
        $any = 1 if $_->name =~ /^container-/ && ($_->value || $self->saved_data->{$_->name});
    }
    $self->add_form_error('Please specify what you need')
        unless $any;

    $self->next::method();
}

1;
