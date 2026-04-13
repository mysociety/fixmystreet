package FixMyStreet::App::Form::Waste::Report::Clinical;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Report';

has_page intro => (
    title => 'Clinical waste',
    fields => [ 'registered', 'continue' ],
    next => sub {
        return $_[0]->{registered} eq 'No'
            ? 'register'
            : (
                $_[2]->c->stash->{property}{clinical_service}
                    ? 'select_issue'
                    : 'cannot_confirm'
            );
    },
);

has_field registered => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Are you already registered for clinical waste?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_page register => (
    template => 'waste/clinical/register.html',
);

has_page select_issue => (
    title => 'Clinical waste',
    fields => [ 'issue', 'continue' ],
    next => sub {
        return $_[0]->{issue} eq 'Missed collection'
            ? 'about_you'
            : 'contact_customer_services';
    },
);

has_field issue => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'What do you wish to report?',
    options => [
        { label => 'Missed collection', value => 'Missed collection' },
        { label => 'Other', value => 'Other' },
    ],
);

has_page cannot_confirm => (
    template => 'waste/clinical/cannot_confirm.html',
);

has_page contact_customer_services => (
    template => 'waste/clinical/contact_customer_services.html',
);

1;
