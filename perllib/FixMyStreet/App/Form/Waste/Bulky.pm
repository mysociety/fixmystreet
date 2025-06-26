package FixMyStreet::App::Form::Waste::Bulky;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Bulky::Shared';

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Bulky' );

has_page intro => (
    intro => 'bulky/intro.html',
    fields => ['continue'],
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $c = $form->c;
        $data->{_residency_check} = 1 if $c->cobrand->moniker eq 'peterborough';
        $data->{_pension_check} = 1 if $c->cobrand->moniker eq 'bexley';
        return {};
    },
    next => sub {
        return 'residency_check' if $_[0]->{_residency_check};
        return 'pension_check' if $_[0]->{_pension_check};
        'about_you';
    }
);

has_page residency_check => (
    fields => ['resident', 'continue'],
    next => sub { $_[0]->{resident} eq 'Yes' ? 'about_you' : 'cannot_book' },
);

has_page pension_check => (
    fields => ['pension', 'disability', 'continue'],
    next => 'about_you',
);

has_page cannot_book => (
    fields => [],
    intro => 'bulky/cannot_book.html',
);

has_page about_you => (
    intro => 'bulky/about_you_preamble.html',
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'choose_date_earlier',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->c;
        my $fields = {};
        $fields->{phone}{tags}{hint} = 'Providing a phone number will allow Aragon Direct Services (who provide the service on behalf of the council) to contact you if there are any issues with the service.'
            if $c->cobrand->moniker eq 'peterborough';
        return $fields;
    },
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_field submit => (
    type => 'Submit',
    value => 'Continue to payment',
    tags => { hint => "You will be redirected to the council’s card payments provider." },
    element_attr => { class => 'govuk-button' },
    order => 999,
);

has_field resident => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Do you live at the property or are you booking on behalf of the householder?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field pension => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Is anyone at the property in receipt of a state pension?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field disability => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Do you have a physical disability?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

1;
