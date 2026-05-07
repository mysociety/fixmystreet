package FixMyStreet::App::Form::Waste::Report::Clinical::Bexley;

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
            ? 'missed_collection_intro'
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

has_page missed_collection_intro => (
    title => 'Report a missed clinical waste collection',
    intro => 'clinical/missed_intro.html',
    fields => ['continue'],
    next => 'container_quantity',
);

has_page container_quantity => (
    title => 'Number of containers',
    fields => [ 'bin_quantity', 'continue' ],
    next => 'container_location',
);

has_field bin_quantity => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'How many clinical waste bags need to be collected?',
    options => [ map { $_, $_ } 1..5 ],
);

has_page container_location => (
    title => 'Location of containers',
    fields => [ 'bin_location', 'continue' ],
    next => 'about_you',
);

has_field bin_location => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Where are the containers located?',
    options_method => sub {
        # Bexley want 'staff_or_assisted' locations for any clinical
        # report
        my $options
            = FixMyStreet::Cobrand::Bexley::Waste->_bin_location_options()
            ->{staff_or_assisted};
        return [ map { $_, $_ } @$options ];
    },
);

has_page cannot_confirm => (
    template => 'waste/clinical/cannot_confirm.html',
);

has_page contact_customer_services => (
    template => 'waste/clinical/contact_customer_services.html',
);

1;
