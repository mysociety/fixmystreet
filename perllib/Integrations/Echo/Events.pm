package Integrations::Echo::Events;

use Moo;

has cobrand => ( is => 'ro' );
has event_types => ( is => 'ro' );
has include_closed_requests => ( is => 'ro' );

has _events => ( is => 'ro' );

use overload bool => sub { scalar $_[0]->list };

has res_code_closes_event => ( is => 'lazy', default => sub { $_[0]->cobrand->moniker eq 'bromley' || $_[0]->cobrand->moniker eq 'merton' } );

sub list {
    return @{$_[0]->_events || []};
}

sub parse {
    my ($self, $events_data, $params) = @_;
    my $events = [];
    my $event_types = $self->event_types;
    foreach (@$events_data) {
        my $event_type = $_->{EventTypeId};
        my $service_id = $_->{ServiceId};
        my $type = $event_types->{$event_type} || 'enquiry';

        my $closed = $self->_closed_event($_);
        my $completed = $self->_completed_event($_);
        # Only care about open requests/enquiries
        next if $type eq 'request' && $closed && !$self->include_closed_requests;

        my $source;
        my $objects = Integrations::Echo::force_arrayref($_->{EventObjects}, 'EventObject');
        foreach (@$objects) {
            if ($_->{EventObjectType} eq 'Source') {
                $source = $_->{ObjectRef}{Value}{anyType};
            }
        }

        my $event = {
            id => $_->{Id},
            guid => $_->{Guid},
            ref => $_->{ClientReference},
            type => $type,
            event_type => $event_type || 0,
            service_id => $service_id || 0,
            closed => $closed,
            completed => $completed,
            source => $source,
            $_->{EventDate} ? (date => construct_bin_date($_->{EventDate})) : (),
        };

        my $report = $self->cobrand->problems->search({ external_id => $_->{Guid} })->first;
        $event->{report} = $report if $report;

        if ($type eq 'request') {
            # Look up container type
            my $data = Integrations::Echo::force_arrayref($_->{Data}, 'ExtensibleDatum');
            foreach (@$data) {
                my $moredata = Integrations::Echo::force_arrayref($_->{ChildData}, 'ExtensibleDatum');
                foreach (@$moredata) {
                    if ($_->{DatatypeName} eq 'Container Type') {
                        my $container = $_->{Value};
                        $event->{container} = $container;
                    }
                }
            }
        } elsif ($type eq 'missed') {
            $self->cobrand->call_hook('parse_event_missed', $_, $event, $events);
        } elsif ($type eq 'bulky') {
            if ($report) {
                $event->{resolution} = $_->{ResolutionCodeId};
                if ($closed) {
                    $event->{date} = construct_bin_date($_->{ResolvedDate});
                    $event->{state} = $_->{EventStateId};
                } else {
                    $event->{date} = $self->cobrand->collection_date($report);
                    $event->{state} = 'open';
                }
            }
        }
        push @$events, $event unless $event->{ignore};
    }
    return $self->new(%$self, _events => $events);
}

sub filter {
    my ($self, $params) = @_;
    my %containers = map { $_ => 1 } @{$params->{containers} || []};
    my @events = grep {
           ($params->{service} ? $_->{service_id} eq $params->{service} : 1)
        && ($params->{event_type} ? $_->{event_type} eq $params->{event_type} : 1)
        && ($params->{since} ? $_->{date} && $_->{date} >= $params->{since} : 1)
        && ($params->{type} ? $_->{type} eq $params->{type} : 1)
        && ($params->{containers} ? $containers{$_->{container}} : 1)
        && (defined $params->{closed} ? $_->{closed} == $params->{closed} : 1)
    } $self->list;
    return $self->new(%$self, _events => \@events);
}

sub combine {
    my ($self, $more) = @_;
    return $self->new(%$self, _events => [ $self->list, $more->list ]);
}

sub _closed_event {
    my ($self, $event) = @_;
    return 1 if $event->{ResolvedDate};
    return 1 if $self->res_code_closes_event && $event->{ResolutionCodeId} && $event->{ResolutionCodeId} != 584; # Out of Stock
    return 0;
}

# Returns 1 if Completed, 0 if not Completed, undef if unsure
sub _completed_event {
    my ($self, $event) = @_;
    # Only SLWP Missed Collections at present
    return undef unless $event->{EventTypeId} == 3145 || $event->{EventTypeId} == 3146;
    # XXX Need to factor this out somewhere somehow
    return 1 if $event->{EventStateId} == 19241 || $event->{EventStateId} == 19246;
    return 0;
}

sub construct_bin_date {
    my $str = shift;
    return unless $str;
    my $offset = ($str->{OffsetMinutes} || 0) * 60;
    my $zone = DateTime::TimeZone->offset_as_string($offset);
    my $date = DateTime::Format::W3CDTF->parse_datetime($str->{DateTime});
    $date->set_time_zone($zone);
    return $date;
}

1;
