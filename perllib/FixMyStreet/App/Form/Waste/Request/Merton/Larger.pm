package FixMyStreet::App::Form::Waste::Request::Merton::Larger;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

use constant CONTAINER_REFUSE_240 => 2;

has_page medical_condition => (
    fields => ['medical_condition', 'continue'],
    title => 'Larger black bin request',
    intro => 'request/intro.html',
    next => sub {
        my $data = shift;
        return 'how_much' if $data->{medical_condition} eq 'Yes';
        return 'how_many';
    },
);

has_field medical_condition => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Does anyone in your household have any medical condition that causes extra waste that cannot be recycled?',
    options => [
        { value => 'Yes', label => 'Yes' },
        { value => 'No', label => 'No' },
    ],
);

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    intro => 'about_you.html',
    title => 'About you',
    next => 'summary',
);

has_page how_much => (
    fields => ['how_much', 'continue'],
    intro => 'request/intro.html',
    title => 'Larger black bin request',
    next => sub {
        my $data = shift;
        my $how_much = $data->{how_much};
        return 'how_many' if $how_much eq 'less1';
        return 'request_static' if $how_much eq '3more';
        $data->{'container-' . CONTAINER_REFUSE_240} = 1;
        return 'about_you';
    },
);

has_field how_much => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'How much non-hazardous, non-recyclable waste does your household produce due to medical conditions?',
    options => [
        { value => 'less1', label => 'Less than 1 black sack a fortnight' },
        { value => '1or2', label => '1 or 2 black sacks a fortnight' },
        { value => '3more', label => '3 or more black sacks a fortnight' },
    ],
);

has_page how_many => (
    fields => ['how_many', 'continue'],
    title => 'Larger black bin request',
    next => sub {
        my $data = shift;
        return 'request_static' if $data->{how_many} eq 'less5';
        $data->{'container-' . CONTAINER_REFUSE_240} = 1;
        return 'about_you';
    },
);

has_field how_many => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'How many people live in your home (include you)?',
    options => [
        { value => 'less5', label => '1 to 4' },
        { value => '5more', label => '5 or more' },
    ],
);

has_page request_static => (
    fields => [],
    template => 'waste/request/static.html',
);

1;
