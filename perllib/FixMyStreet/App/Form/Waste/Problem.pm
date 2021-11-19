package FixMyStreet::App::Form::Waste::Problem;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

# First page has dynamic fields, so is set in code

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'summary',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_page summary => (
    fields => ['submit'],
    title => 'Submit missed collection',
    template => 'waste/summary_problem.html',
    finished => sub {
        return $_[0]->wizard_finished('process_problem_data');
    },
    next => 'done',
);

has_page done => (
    title => 'Problem report sent',
    template => 'waste/confirmation.html',
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
);

has_field submit => (
    type => 'Submit',
    value => 'Report problem with bin',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

sub validate {
    my $self = shift;
    my $any = 0;

    foreach ($self->all_fields) {
        $any = 1 if $_->name =~ /^service-/ && ($_->value || $self->saved_data->{$_->name});
    }
    $self->add_form_error('Please specify what the problem was')
        unless $any;

    $self->next::method();
}

1;

