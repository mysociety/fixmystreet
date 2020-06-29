package Integrations::Echo;

use strict;
use warnings;
use Moo;
use Tie::IxHash;

has attr => ( is => 'ro', default => 'http://www.twistedfish.com/xmlns/echo/api/v1' );
has action => ( is => 'lazy', default => sub { $_[0]->attr . "/Service/" } );
has username => ( is => 'ro' );
has password => ( is => 'ro' );
has url => ( is => 'ro' );

has sample_data => ( is => 'ro', default => 0 );

has endpoint => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        $ENV{PERL_LWP_SSL_CA_PATH} = '/etc/ssl/certs';
        SOAP::Lite->soapversion(1.2);
        my $soap = SOAP::Lite->on_action( sub { $self->action . $_[1]; } )->proxy($self->url);
        $soap->serializer->register_ns("http://schemas.microsoft.com/2003/10/Serialization/Arrays", 'msArray'),
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
        tie(my %a, 'Tie::IxHash',
            Key => 'Handle',
            Type => "Task",
            Value => [
                { 'msArray:anyType' => $ref->[0] },
                { 'msArray:anyType' => $ref->[1] },
            ],
        );
        push @refs, \%a;
    }

    return [
        { Ref => { Value => { anyType => [ 123, 456 ] } }, CompletedDate => undef },
        { Ref => { Value => { anyType => [ 234, 567 ] } }, CompletedDate => { DateTime => '2020-05-27T10:00:00Z' } },
        { Ref => { Value => { anyType => [ 345, 678 ] } }, CompletedDate => undef },
        { Ref => { Value => { anyType => [ 456, 789 ] } }, CompletedDate => undef },
    ] if $self->sample_data;

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

sub _uprn_ref {
    require SOAP::Lite;
    my $uprn = shift;
    tie(my %obj, 'Tie::IxHash',
        Key => 'Uprn',
        Type => 'PointAddress',
        Value => [
            { 'msArray:anyType' => SOAP::Data->value($uprn)->type('string') },
        ],
    );
    return \%obj;
}

sub GetPointAddress {
    my $self = shift;
    my $uprn = shift;
    my $obj = _uprn_ref($uprn);
    return {
        Id => '12345',
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
    tie(my %obj, 'Tie::IxHash',
        PointType => 'PointAddress',
        Postcode => $pc,
    );
    return [
        { Description => '1 Example Street, Bromley, BR1 1AA', SharedRef => { Value => { anyType => 1000000001 } } },
        { Description => '2 Example Street, Bromley, BR1 1AA', SharedRef => { Value => { anyType => 1000000002 } } },
        { Description => '3 Example Street, Bromley, BR1 1AA', SharedRef => { Value => { anyType => 1000000003 } } },
        { Description => '4 Example Street, Bromley, BR1 1AA', SharedRef => { Value => { anyType => 1000000004 } } },
        { Description => '5 Example Street, Bromley, BR1 1AA', SharedRef => { Value => { anyType => 1000000005 } } },
    ] if $self->sample_data;
    my $res = $self->call('FindPoints', query => \%obj);
    return force_arrayref($res, 'PointInfo');
}

sub GetServiceUnitsForObject {
    my $self = shift;
    my $uprn = shift;
    my $obj = _uprn_ref($uprn);
    my $from = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    return [ {
        Id => 1001,
        ServiceId => 101,
        ServiceName => 'Refuse collection',
        ServiceTasks => { ServiceTask => {
            Id => 401,
            ScheduleDescription => 'every Wednesday',
            ServiceTaskSchedules => { ServiceTaskSchedule => {
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                },
                LastInstance => {
                    CurrentScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                },
            } },
        } },
    }, {
        Id => 1002,
        ServiceId => 537,
        ServiceName => 'Paper recycling collection',
        ServiceTasks => { ServiceTask => {
            Id => 402,
            ScheduleDescription => 'every other Wednesday',
            ServiceTaskSchedules => { ServiceTaskSchedule => {
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                },
                LastInstance => {
                    CurrentScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                },
            } },
        } },
    }, {
        Id => 1003,
        ServiceId => 535,
        ServiceName => 'Domestic Container Mix Collection',
        ServiceTasks => { ServiceTask => {
            Id => 403,
            ScheduleDescription => 'every other Wednesday',
            ServiceTaskSchedules => { ServiceTaskSchedule => {
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                },
                LastInstance => {
                    CurrentScheduledDate => { DateTime => '2020-05-20T00:00:00Z' },
                },
            } },
        } },
    }, {
        Id => 1004,
        ServiceId => 542,
        ServiceName => 'Food waste collection',
        ServiceTasks => { ServiceTask => {
            Id => 404,
            ScheduleDescription => 'every other Monday',
            ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                LastInstance => {
                    CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                },
            }, {
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-02T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                },
                LastInstance => {
                    CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
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

sub force_arrayref {
    my ($res, $key) = @_;
    return [] unless $res;
    my $data = $res->{$key};
    return [] unless $data;
    $data = [ $data ] unless ref $data eq 'ARRAY';
    return $data;
}

sub make_soap_structure {
    my @out;
    for (my $i=0; $i<@_; $i+=2) {
        my $name = $_[$i] =~ /:/ ? $_[$i] : $_[$i];
        my $v = $_[$i+1];
        my $val = $v;
        my $d = SOAP::Data->name($name);
        if (ref $v eq 'HASH') {
            $val = \SOAP::Data->value(make_soap_structure(%$v));
        } elsif (ref $v eq 'ARRAY') {
            my @map = map { make_soap_structure(%$_) } @$v;
            $val = \SOAP::Data->value(SOAP::Data->name('dummy' => @map));
        }
        push @out, $d->value($val);
    }
    return @out;
}

1;
