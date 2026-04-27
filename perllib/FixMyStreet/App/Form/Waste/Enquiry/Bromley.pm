package FixMyStreet::App::Form::Waste::Enquiry::Bromley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Enquiry';

has_page missed_collection_intro => (
    title => 'Missed collection',
    intro => 'enquiry_missed_intro.html',
    fields => [],
);

has_page missed_collection_intro_not_presented => (
    title => 'Missed collection',
    intro => 'enquiry_missed_intro.html',
    fields => ['continue'],
    next => 'missed_collection_declaration'
);

has_page missed_collection_declaration => (
    title => 'Missed collection',
    intro => 'enquiry_missed_declaration.html',
    fields => ['declaration', 'warning', 'continue'],
    next => 'enquiry',
);

# Any field not on a page gets shown on all pages. We have this dummy page so
# that the notice fields are only shown if manually added by the cobrand code
has_page notices => (
    fields => ['bromley_missed_notice_not_presented', 'bromley_missed_notice'],
);

has_field bromley_missed_notice_not_presented => (
    widget => 'NoRender',
    required => 0,
    type => 'Notice',
    order => -1,
    build_label_method => sub {
        my $self = shift;
        my $service_id = $self->parent->{c}->get_param('service_id');
        return "Do not use this form to report a missed collection. Instead, please <a href='enquiry?category=Return+request&amp;service_id=$service_id'>Report a missed collection</a>";
    },
);

has_field bromley_missed_notice => (
    widget => 'NoRender',
    required => 0,
    type => 'Notice',
    order => -1,
    build_label_method => sub {
        my $self = shift;
        my $service_id = $self->parent->{c}->get_param('service_id');
        return "We cannot accept missed collection reports through this form. If you believe you are eligible for re-collection, please visit <a href='enquiry?category=Return+request&amp;service_id=$service_id'>My bin was not collected</a>";
    },
);

has_field declaration => (
    type => 'Multiple',
    widget => 'CheckboxGroup',
    label => 'To request a missed collection, please confirm the following:',
    required => 1,
    options => [
        { label => 'My rubbish was presented before 7am', value => '7am' },
        { label => 'My bin was presented within arm’s reach of the pavement', value => 'arm' },
    ],
     validate_method => sub {
        my $self = shift;
        my $vals = $self->value;
        $self->add_error('Please confirm all options') if @$vals < 2;
    },
);

has_field warning => (
    widget => 'NoRender',
    required => 0,
    type => 'Notice',
    label => '<strong>Please note all our waste and recycling vehicles are fitted with CCTV and disputed missed collections may be investigated before the collection teams are instructed to return.</strong>',
);

1;
