package FixMyStreet::App::Form::Waste::Request;

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
    title => 'Submit container request',
    template => 'waste/summary_request.html',
    finished => sub {
        return $_[0]->wizard_finished('process_request_data');
    },
    # For payments, updating the submit button
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        if ($data->{payment}) {
            return { submit => { value => 'Continue to payment' } };
        }
        return {};
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
    order => 999,
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
        # Either a container-* has been selected, or
        # Kingston/Merton special cases for change-size-first-page
        $any = 1 if $_->name =~ /^container-|how_many_exchange|medical_condition/ && ($_->value || $self->saved_data->{$_->name});
    }

    $self->add_form_error('Please specify what you need')
        unless $any;

    $self->next::method();
}

1;
