package FixMyStreet::App::Form::Waste::Request::Brent;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';
use Readonly;

Readonly::Scalar my $CONTAINER_GREY_BIN => 16;
Readonly::Scalar my $CONTAINER_BLUE_BIN => 6;
Readonly::Scalar my $CONTAINER_CLEAR_SACK => 8;
Readonly::Scalar my $CONTAINER_FOOD_CADDY => 11;
Readonly::Scalar my $CONTAINER_GREEN_BIN => 13;
Readonly::Scalar my $CONTAINER_BLUE_SACK => 46;

my %new_build_ordered_months = (
    $CONTAINER_FOOD_CADDY => 2,
    $CONTAINER_BLUE_BIN => 6,
    $CONTAINER_BLUE_SACK => 2,
);
my %ordered_months = (
    $CONTAINER_GREEN_BIN => 6,
    $CONTAINER_FOOD_CADDY => 3,
    $CONTAINER_BLUE_BIN => 6,
    $CONTAINER_BLUE_SACK => 3,
);
my %refusal_contamination_months = (
    $CONTAINER_FOOD_CADDY => 3,
    $CONTAINER_BLUE_BIN => 3,
    $CONTAINER_BLUE_SACK => 3,
);

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'summary',
);

has_page request_refuse_call_us => (
    fields => [],
    template => 'waste/refuse_call_us.html',
);

has_page request_extra_refusal => (
    fields => [],
    template => 'waste/refuse_extra_container.html',
);

has_page replacement => (
    fields => ['request_reason', 'continue'],
    title => 'Reason for request',
    next => sub {
        my $data = shift;
        my $choice = $data->{"container-choice"};
        my $reason = $data->{request_reason};

        return 'about_you' if $choice == $CONTAINER_CLEAR_SACK;
        return 'how_long_lived' if $reason eq 'new_build';
        return 'request_extra_refusal' if $reason eq 'extra' && ($data->{ordered_previously} || $data->{contamination_reports});
        return 'about_you';
    },
);

has_field request_reason => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    build_label_method => sub {
        my $self = shift;
        my $choice = $self->parent->saved_data->{'container-choice'};
        return 'Why do you need more sacks?' if $choice == $CONTAINER_CLEAR_SACK;
        return 'Why do you need a replacement container?';
    },
    validate_method => sub {
        my $self = shift;
        my $c = $self->form->c;
        return if $self->has_errors;
        my $value = $self->value;
        my $saved_data = $self->form->saved_data;

        my $echo = $c->cobrand->feature('echo');
        $echo = Integrations::Echo->new(%$echo);

        my $choice = $saved_data->{'container-choice'};
        my $months = $value eq 'new_build' ?  $new_build_ordered_months{$choice} : $ordered_months{$choice};
        return unless $months;

        my $events = $echo->GetEventsForObject(PointAddress => $c->stash->{property}{id}, 2936, $months);
        $events = $c->cobrand->_parse_events($events, { include_closed_events => 1 });
        $saved_data->{ordered_previously} = $events->{request}{$choice} ? 1 : 0;

        if ($value eq 'extra' || $value eq 'missing') {
            my $months = $refusal_contamination_months{$choice};
            my $events = $echo->GetEventsForObject(PointAddress => $c->stash->{property}{id}, 2923, $months);
            $events = $c->cobrand->_parse_events($events, { include_closed_events => 1 });
            $saved_data->{contamination_reports} = $events->{enquiry}{2923} ? 1 : 0;
        }
    },
);

sub options_request_reason {
    my $form = shift;
    my $data = $form->saved_data;
    my $choice = $data->{'container-choice'} || 0;
    my @options;
    if ($choice == $CONTAINER_CLEAR_SACK) {
        push @options, { value => 'new_build', label => 'I am a new resident without any' };
        push @options, { value => 'extra', label => 'I have used all the sacks provided' };
    } elsif ($choice == $CONTAINER_GREEN_BIN) {
        push @options, { value => 'damaged', label => 'My container is damaged' };
        push @options, { value => 'missing', label => 'My container is missing' };
    } else {
        push @options, { value => 'new_build', label => 'I am a new resident without a container' };
        push @options, { value => 'damaged', label => 'My container is damaged' };
        push @options, { value => 'missing', label => 'My container is missing' };
        push @options, { value => 'extra', label => 'I would like an extra container' };
    }
    return @options;
}

has_page how_long_lived => (
    fields => ['how_long_lived', 'continue'],
    title => 'Reason for request',
    next => 'about_you',
);

has_field how_long_lived => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'How long have you lived at this address?',
    options => [
        { value => 'less3', label => 'Less than 3 months' },
        { value => '3more', label => '3 months or more' },
    ],
);

has_field submit => (
    type => 'Submit',
    value => 'Request container',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
