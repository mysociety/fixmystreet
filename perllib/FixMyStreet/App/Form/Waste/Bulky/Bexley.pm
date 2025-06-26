package FixMyStreet::App::Form::Waste::Bulky::Bexley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Bulky';

has_page intro => (
    intro => 'bulky/intro.html',
    fields => ['continue'],
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        $data->{_pension_check} = 1;
        return {};
    },
    next => 'about_you',
);

has_page pension_check => (
    fields => ['pension', 'disability', 'continue'],
    next => 'choose_date_earlier',
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

