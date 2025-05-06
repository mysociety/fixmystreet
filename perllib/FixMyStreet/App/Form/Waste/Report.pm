package FixMyStreet::App::Form::Waste::Report;

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
    template => 'waste/summary_report.html',
    finished => sub {
        return $_[0]->wizard_finished('process_report_data');
    },
    next => 'done',
);

has_page done => (
    title => 'Missed collection sent',
    template => 'waste/confirmation.html',
);

has_field category => (
    type => 'Hidden',
    default => 'Report missed collection'
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

has_field submit => (
    type => 'Submit',
    value => 'Report collection as missed',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

sub validate {
    my $self = shift;
    my $any = 0;

    foreach ($self->all_fields) {
        $any = 1 if $_->name =~ /^service-/ && ($_->value || $self->saved_data->{$_->name});
    }
    $self->add_form_error('Please specify what was missed')
        unless $any;

    $self->next::method();
}

1;

