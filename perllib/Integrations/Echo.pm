package Integrations::Echo;

use Moo;
use strict;
use warnings;
with 'FixMyStreet::Roles::SOAPIntegration';
with 'FixMyStreet::Roles::ParallelAPI';
with 'FixMyStreet::Roles::Syslog';

use DateTime;
use DateTime::Format::Strptime;
use File::Temp;
use FixMyStreet;

has attr => ( is => 'ro', default => 'http://www.twistedfish.com/xmlns/echo/api/v1' );
has action => ( is => 'lazy', default => sub { $_[0]->attr . "/Service/" } );
has username => ( is => 'ro' );
has password => ( is => 'ro' );
has url => ( is => 'ro' );

has sample_data => ( is => 'ro', default => 0 );

has log_ident => (
    is => 'ro',
    default => sub {
        my $feature = 'echo';
        my $features = FixMyStreet->config('COBRAND_FEATURES');
        return unless $features && ref $features eq 'HASH';
        return unless $features->{$feature} && ref $features->{$feature} eq 'HASH';
        my $f = $features->{$feature}->{_fallback};
        return $f->{log_ident};
    }
);

has endpoint => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        # $ENV{PERL_LWP_SSL_CA_PATH} = '/etc/ssl/certs';
        SOAP::Lite->soapversion(1.2);
        my $soap = SOAP::Lite->on_action( sub { $self->action . $_[1]; } )->proxy($self->url);
        $soap->serializer->register_ns("http://schemas.microsoft.com/2003/10/Serialization/Arrays", 'msArray'),
        $soap->serializer->register_ns("http://schemas.datacontract.org/2004/07/System", 'dataContract');
        return $soap;
    },
);

has security => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        SOAP::Header->name("Security")->attr({
            'mustUnderstand' => 'true',
            'xmlns' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        })->value(
            \SOAP::Header->name(
                "UsernameToken" => \SOAP::Header->value(
                    SOAP::Header->name('Username', $self->username),
                    SOAP::Header->name('Password', $self->password),
                )
            )
        );
    },
);

has backend_type => ( is => 'ro', default => 'echo' );

sub action_hdr {
    my ($self, $method) = @_;
    SOAP::Header->name("Action")->attr({
        'xmlns' => 'http://www.w3.org/2005/08/addressing',
    })->value(
        $self->action . $method
    );
}

sub call {
    my ($self, $method, @params) = @_;

    require SOAP::Lite;
    @params = make_soap_structure(@params);
    my $res = $self->endpoint->call(
        SOAP::Data->name($method)->attr({ xmlns => $self->attr }),
        $self->security,
        $self->action_hdr($method),
        @params
    );
    $res = $res->result;
    return $res;
}

# Given a list of task handles as two-value array refs (as returned in e.g. the
# LastInstance part of GetServiceUnitsForObject), returns a list of the
# corresponding tasks.
sub GetTasks {
    my $self = shift;

    my @refs;
    foreach my $ref (@_) {
        my $a = ixhash(
            Key => 'Handle',
            Type => "Task",
            Value => [
                { 'msArray:anyType' => $ref->[0] },
                { 'msArray:anyType' => $ref->[1] },
            ],
        );
        push @refs, $a;
    }

    if ($self->sample_data) {
        my %lookup = map { $_->[0] . ',' . $_->[1] => 1 } @_;
        my $data = [];
        push @$data, {
            Ref => { Value => { anyType => [ '123', '456' ] } },
            State => { Name => 'Completed' },
            Resolution => { Ref => { Value => { anyType => '187' } }, Name => 'Wrong Bin Out' },
            TaskTypeId => '3216',
            CompletedDate => { DateTime => '2020-05-27T10:00:00Z' }
        } if $lookup{"123,456"};
        push @$data, {
            Ref => { Value => { anyType => [ '234', '567' ] } },
            State => { Name => 'Outstanding' },
            CompletedDate => undef
        } if $lookup{"234,567"};
        push @$data, {
            Ref => { Value => { anyType => [ '345', '678' ] } },
            State => { Name => 'Not Completed' }
        } if $lookup{"345,678"};
        push @$data, {
            Ref => { Value => { anyType => [ '456', '789' ] } },
            CompletedDate => undef
        } if $lookup{"456,789"};
        return $data;
    }

    # This creates XML of the form <taskRefs><ObjectRef>...</ObjectRef><ObjectRef>...</ObjectRef>...</taskRefs>
    # uncoverable statement
    my $res = $self->call('GetTasks',
        taskRefs => [
            map { { ObjectRef => $_ } } @refs
        ],
        options => {
            IncludePoints => 'false',
        },
    );
    # uncoverable statement
    return force_arrayref($res, 'Task');
}

sub _id_ref {
    require SOAP::Lite;
    my ($id, $type, $key) = @_;
    $key ||= 'Id';
    my $value = SOAP::Data->value($id);
    $value = $value->type('string') if $key eq 'Uprn';
    return ixhash(
        Key => $key,
        Type => $type,
        Value => [
            { 'msArray:anyType' => $value },
        ],
    );
}

sub GetPointAddress {
    my $self = shift;
    my $id = shift;
    my $type = shift || 'Id';
    my $obj = _id_ref($id, 'PointAddress', $type);
    return {
        Id => $type eq 'Id' ? $id : '12345',
        SharedRef => { Value => { anyType => $type eq 'Uprn' ? $id : '1000000002' } },
        PointType => 'PointAddress',
        PointAddressType => { Name => 'House' },
        Coordinates => { GeoPoint => { Latitude => 51.401546, Longitude => 0.015415 } },
        Description => '2 Example Street, Bromley, BR1 1AA',
    } if $self->sample_data;
    $self->call('GetPointAddress', ref => $obj);
}

# Given a postcode, returns an arrayref of addresses
sub FindPoints {
    my $self = shift;
    my $pc = shift;
    my $cfg = shift;

    my $obj = ixhash(
        PointType => 'PointAddress',
        Postcode => $pc,
    );
    if ($cfg->{address_types}) {
        my @types;
        foreach (@{$cfg->{address_types}}) {
            my $obj = _id_ref($_, 'PointAddressType');
            push @types, { ObjectRef => $obj };
        }
        $obj->{TypeRefs} = \@types;
    }
    return [
        { Description => '1 Example Street, Bromley, BR1 1AA', Id => '11345', SharedRef => { Value => { anyType => '1000000001' } } },
        { Description => '2 Example Street, Bromley, BR1 1AA', Id => '12345', SharedRef => { Value => { anyType => '1000000002' } } },
        $cfg->{address_types} ? () : ({ Description => '3 Example Street, Bromley, BR1 1AA', Id => '13345', SharedRef => { Value => { anyType => '1000000003' } } }),
        { Description => '4 Example Street, Bromley, BR1 1AA', Id => '14345', SharedRef => { Value => { anyType => '1000000004' } } },
        { Description => '5 Example Street, Bromley, BR1 1AA', Id => '15345', SharedRef => { Value => { anyType => '1000000005' } } },
    ] if $self->sample_data;
    my $res = $self->call('FindPoints', query => $obj);
    return force_arrayref($res, 'PointInfo');
}

sub GetServiceUnitsForObject {
    my $self = shift;
    my $id = shift;
    my $type = shift;
    my $obj = _id_ref($id, 'PointAddress', $type);
    my $from = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->add(days => -20);
    return [ {
        Id => '1001',
        ServiceId => '531',
        ServiceName => 'Non-Recyclable Refuse',
        ServiceTasks => { ServiceTask => {
            Id => '401',
            ServiceTaskSchedules => { ServiceTaskSchedule => {
                ScheduleDescription => 'every Wednesday',
                StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                    Ref => { Value => { anyType => [ '123', '456' ] } },
                },
            } },
        } },
    }, {
        Id => '1002',
        ServiceId => '537',
        ServiceName => 'Paper recycling collection',
        ServiceTasks => { ServiceTask => {
            Id => '402',
            ServiceTaskSchedules => { ServiceTaskSchedule => {
                ScheduleDescription => 'every other Wednesday',
                StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                    Ref => { Value => { anyType => [ '234', '567' ] } },
                },
            } },
        } },
    }, {
        Id => '1003',
        ServiceId => '535',
        ServiceName => 'Domestic Container Mix Collection',
        ServiceTasks => { ServiceTask => {
            Id => '403',
            ServiceTaskSchedules => { ServiceTaskSchedule => {
                ScheduleDescription => 'every other Wednesday',
                StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2020-05-20T00:00:00Z' },
                    Ref => { Value => { anyType => [ '345', '678' ] } },
                },
            } },
        } },
    }, {
        Id => '1004',
        ServiceId => '542',
        ServiceName => 'Food waste collection',
        ServiceTasks => { ServiceTask => {
            Id => '404',
            ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                ScheduleDescription => 'every other Monday',
                StartDate => { DateTime => '2019-01-01T00:00:00Z' },
                EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                },
            }, {
                ScheduleDescription => 'every other Monday',
                StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-02T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    Ref => { Value => { anyType => [ '456', '789' ] } },
                },
            }, {
                # Some bad data, future schedule, with past last instance
                ScheduleDescription => 'every other Tuesday',
                StartDate => { DateTime => '2050-01-01T00:00:00Z' },
                EndDate => { DateTime => '2051-01-01T00:00:00Z' },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    Ref => { Value => { anyType => [ '456', '789' ] } },
                },
            } ] },
        } },
    }, {
        Id => '1005',
        ServiceId => '545',
        ServiceName => 'Garden waste collection',
        ServiceTasks => { ServiceTask => {
            Id => '405',
            Data => { ExtensibleDatum => [ {
                DatatypeName => 'LBB - GW Container',
                ChildData => { ExtensibleDatum => [ {
                    DatatypeName => 'Quantity',
                    Value => '1',
                }, {
                    DatatypeName => 'Container',
                    Value => '44',
                } ] },
            } ] },
            ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                StartDate => { DateTime => '2019-01-01T00:00:00Z' },
                EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                },
            }, {
                ScheduleDescription => 'every other Monday',
                StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                EndDate => { DateTime => '2021-03-30T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    Ref => { Value => { anyType => [ '567', '890' ] } },
                },
            } ] },
        } },
    } ] if $self->sample_data;
    # uncoverable statement
    my $res = $self->call('GetServiceUnitsForObject',
        objectRef => $obj,
        query => ixhash(
            From => dt_to_hash($from),
            IncludeTaskInstances => 'true',
        ),
    );
    # uncoverable statement
    return force_arrayref($res, 'ServiceUnit');
}

sub GetServiceTaskInstances {
    my ($self, @tasks) = @_;

    my @objects;
    foreach (@tasks) {
        my $obj = _id_ref($_, 'ServiceTask');
        push @objects, { ObjectRef => $obj };
    }
    my $start = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->truncate( to => 'day' );
    my $end = $start->clone->add(months => 3);
    my $query = ixhash(
        From => dt_to_hash($start),
        To => dt_to_hash($end),
    );
    return [
        { ServiceTaskRef => { Value => { anyType => '401' } },
            Instances => { ScheduledTaskInfo => [
                { CurrentScheduledDate => { DateTime => '2020-07-01T00:00:00Z' } },
            ] }
        },
        { ServiceTaskRef => { Value => { anyType => '402' } },
            Instances => { ScheduledTaskInfo => [
                { CurrentScheduledDate => { DateTime => '2020-07-08T00:00:00Z' } },
            ] }
        },
    ] if $self->sample_data;
    # uncoverable statement
    my $res = $self->call('GetServiceTaskInstances',
        serviceTaskRefs => \@objects,
        query => $query,
    );
    return force_arrayref($res, 'ServiceTaskInstances');
}

sub GetEvent {
    my ($self, $guid, $type) = @_;
    $type ||= 'Guid';
    $self->call('GetEvent', ref => ixhash(
        Key => $type,
        Type => 'Event',
        Value => { 'msArray:anyType' => $guid },
    ));
}

sub GetEventType {
    my ($self, $id) = @_;
    $self->call('GetEventType', ref => _id_ref($id, 'EventType'));
}

sub GetEventsForObject {
    my ($self, $type, $id, $event_type) = @_;
    my $from = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->subtract(months => 3);
    if ($self->sample_data) {
        return [ {
            # Missed collection for service 542 (food waste)
            EventTypeId => '2100',
            EventDate => { DateTime => "2020-05-18T17:00:00Z" },
            ServiceId => '542',
        }, { # And a gate not closed
            EventTypeId => '2118',
            ServiceId => '542',
        }, {
            # Request for a new paper container, currently out of stock
            EventTypeId => '2104',
            Data => { ExtensibleDatum => [
                { Value => '2', DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => '1', DatatypeName => 'Action' },
                        { Value => '12', DatatypeName => 'Container Type' },
                    ] },
                },
            ] },
            ServiceId => '535',
            ResolutionCodeId => '584',
        } ] if $type eq 'PointAddress';
        return [ {
            # Missed collection for service 537 (paper)
            EventTypeId => '2099',
            EventDate => { DateTime => "2020-05-27T16:00:00Z" },
            ServiceId => '537',
        } ] if $type eq 'ServiceUnit' && $id == 1002;
        return [];
    }

    # uncoverable statement
    my $res = $self->call('GetEventsForObject',
        objectRef => _id_ref($id, $type),
        query => ixhash(
            $event_type ? (EventTypeRef => _id_ref($event_type, 'EventType')) : (),
            From => dt_to_hash($from),
        ),
    );
    return force_arrayref($res, 'Event');
}

sub ReserveAvailableSlotsForEvent {
    my ($self, $service, $event_type, $property, $guid, $from, $to) = @_;

    my $parser = DateTime::Format::Strptime->new( pattern => '%Y-%m-%d');
    $from = $parser->parse_datetime($from);
    $to = $parser->parse_datetime($to);

    my $res = $self->call('ReserveAvailableSlotsForEvent',
        event => ixhash(
            Guid => $guid,
            EventObjects => { EventObject => ixhash(
                EventObjectType => 'Source',
                ObjectRef => _id_ref($property, 'PointAddress'),
            ) },
            EventTypeId => $event_type,
            ServiceId => $service,
        ),
        parameters => ixhash(
            From => dt_to_hash($from),
            To => dt_to_hash($to),
        ),
    );

    return [] unless ref $res eq 'HASH';

    $self->log($res);
    return force_arrayref($res->{ReservedTaskInfo}{ReservedSlots}, 'ReservedSlot');
}

sub CancelReservedSlotsForEvent {
    my ($self, $guid) = @_;
    $self->call('CancelReservedSlotsForEvent', eventGuid => $guid);
}

sub dt_to_hash {
    my $dt = shift;
    my $utc = $dt->clone->set_time_zone('UTC');
    $dt = ixhash(
        'dataContract:DateTime' => $utc->ymd . 'T' . $utc->hms . 'Z',
        'dataContract:OffsetMinutes' => $dt->offset / 60,
    );
    return $dt;
}

1;
