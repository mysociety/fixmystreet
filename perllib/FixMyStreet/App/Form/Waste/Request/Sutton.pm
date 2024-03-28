package FixMyStreet::App::Form::Waste::Request::Sutton;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    intro => 'about_you.html',
    title => 'About you',
    next => 'summary',
    post_process => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $c = $form->c;
        if ($data) {
            my $choice = $data->{'container-choice'};
            my ($cost, $hint) = $c->cobrand->request_cost($choice, $c->stash->{quantities});
            $data->{payment} = $cost if $cost;
        }
    },
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
    label => 'Why do you need a replacement container?',
);

sub options_request_reason {
    my $form = shift;
    my @options = (
        { value => 'damaged', label => 'Damaged' },
        { value => 'missing', label => 'Missing' },
    );
    return @options;
}

has_field submit => (
    type => 'Submit',
    value => 'Request container',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
