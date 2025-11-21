package FixMyStreet::App::Form::Waste::Enquiry;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

# First page has dynamic fields, so is set in code

has_field category => ( type => 'Hidden' );
has_field service_id => ( type => 'Hidden' );

has_page about_you => (
    fields => ['name', 'phone', 'email', 'category', 'service_id', 'continue'],
    title => 'About you',
    next => 'summary',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->c;
        return {
            category => { default => $c->get_param('category') },
            service_id => { default => $c->get_param('service_id') },
        }
    }
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_page summary => (
    fields => ['submit'],
    title => 'Submit missed collection',
    template => 'waste/summary_enquiry.html',
    finished => sub {
        return $_[0]->wizard_finished('process_enquiry_data');
    },
    next => 'done',
);

has_page done => (
    title => 'Enquiry sent',
    template => 'waste/confirmation.html',
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
    order => 999
);

has_field submit => (
    type => 'Submit',
    value => 'Submit',
    element_attr => { class => 'govuk-button' }
);

1;
