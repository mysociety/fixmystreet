package FixMyStreet::App::Form::Waste::Request::Bexley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

has_field category_delivery => (
    type => 'Hidden',
    default => 'Request new container',
);

has_field category_removal => (
    type => 'Hidden',
    default => 'Request container removal',
);

# Shown as first page if property able to order Green Wheelie Bins
has_page household_size => (
    title => 'Household size',
    fields => [ 'household_size', 'continue' ],
    next => 'request',
);

has_field household_size => (
    type => 'Select',
    widget => 'RadioGroup',
    label   => 'How many people live at the property?',
    options => [
        map {
            label     => $_,
            value     => $_,
        },
        ( 1..4, '5 or more' )
    ],
);

has_page request_reason => (
    fields => ['request_reason', 'continue'],
    title => 'Reason for request',
    next => 'about_you',
);

has_field request_reason => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Why do you need new bins?',
);

has_field submit => (
    type => 'Submit',
    value => 'Request bin delivery or removal',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

sub options_request_reason {
    my $form = shift;

    my @options = (
        'My existing bin is too small or big',
        'My existing bin is damaged',
        'My existing bin has gone missing',
        'I have moved into a new development',
        'Bins are no longer required',
    );
    return map { { label => $_, value => $_ } } @options;
}

1;
