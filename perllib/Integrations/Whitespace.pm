=head1 NAME

Integrations::Whitespace - Whitespace Work Software API integration

=head1 DESCRIPTION

This module provides an interface to the Whitespace Work Software Web Services API

=cut

package Integrations::Whitespace;

use strict;
use warnings;
use Moo;
use Data::Dumper;
use Time::HiRes;

with 'Integrations::Roles::SOAP';
with 'Integrations::Roles::ParallelAPI';
with 'FixMyStreet::Roles::Syslog';

has log_ident => (
    is => 'ro',
    default => sub {
        my $feature = 'whitespace';
        my $features = FixMyStreet->config('COBRAND_FEATURES');
        return unless $features && ref $features eq 'HASH';
        return unless $features->{$feature} && ref $features->{$feature} eq 'HASH';
        my $f = $features->{$feature}->{_fallback};
        return $f->{log_ident};
    }
);

has attr => ( is => 'ro', default => 'http://webservices.whitespacews.com/' );
has username => ( is => 'ro' );
has password => ( is => 'ro' );
has url => ( is => 'ro' );

has endpoint => (
    is => 'lazy',
    default => sub {
        my $self = shift;

        $ENV{PERL_LWP_SSL_CA_PATH} = '/etc/ssl/certs' unless $ENV{DEV_USE_SYSTEM_CA_PATH};

        SOAP::Lite->new(
            soapversion => 1.1,
            proxy => $self->url,
            default_ns => $self->attr,
            on_action => sub { $self->attr . $_[1] }
        );
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

has backend_type => ( is => 'ro', default => 'whitespace' );

sub call {
    my ($self, $method, $log_info, @params) = @_;

    require SOAP::Lite;

    # SOAP::Lite uses some global constants to set e.g. the request's
    # Content-Type header and various envelope XML attributes. On new() it sets
    # up those XML attributes, and even if you call soapversion on the object's
    # serializer after, it does nothing if the global version matches the
    # object's current version (which it will!), and then uses those same
    # constants anyway. So we have to set the version globally before creating
    # the object (during the call to self->endpoint), and also during the
    # call() (because it uses the constants at that point to set the
    # Content-Type header), and then set it back after so it doesn't break
    # other users of SOAP::Lite.
    SOAP::Lite->soapversion(1.1);

    @params = make_soap_structure(@params);
    my $start = Time::HiRes::time();
    my $som = $self->endpoint->call(
        $method => @params,
        $self->security
    );

    SOAP::Lite->soapversion(1.2);

    my $time = Time::HiRes::time() - $start;
    $self->log("$method $log_info call took $time seconds");

    # TODO: Better error handling
    die $som->faultstring if ($som->fault);

    return $som->result;
}

sub GetSiteCollections {
    my ($self, $uprn) = @_;

    my $res = $self->call('GetSiteCollections', $uprn, siteserviceInput => ixhash( Uprn => $uprn ));

    my $site_services = force_arrayref($res->{SiteServices}, 'SiteService');

    return $site_services;
}

sub GetSiteInfo {
    my ( $self, $uprn ) = @_;

    my $res = $self->call( 'GetSiteInfo', $uprn,
        siteInfoInput => ixhash( Uprn => $uprn ) );

    my $site = $res->{Site};
    if (!$site) {
        $self->log("GetSiteInfo response without site for $uprn: " . Dumper($res));
    }
    return $site;
}

sub GetAccountSiteID {
    my ( $self, $site_id ) = @_;

    my $res = $self->call( 'GetAccountSiteId', $site_id,
        siteInput => ixhash( SiteId => $site_id ) );

    return $res;
}

sub GetSiteServiceItemRoundSchedules {
    my ($self, $site_service_id) = @_;

    my $res = $self->call('GetSiteServiceItemRoundSchedules', $site_service_id,
        siteServiceItemRoundScheduleInput => ixhash( SiteServiceId => $site_service_id ));

    return $res->{RRASSContractRounds}->{RRASSContractRound};
}

sub GetSiteWorksheets {
    my ( $self, $uprn ) = @_;

    my $res = $self->call( 'GetSiteWorksheets', $uprn,
        worksheetInput => ixhash( Uprn => $uprn ) );

    my $worksheets = force_arrayref( $res->{Worksheets}, 'Worksheet' );

    return $worksheets;
}

# Needed to get ServiceItemIDs
sub GetWorksheetDetailServiceItems {
    my ( $self, $worksheet_id ) = @_;

    my $res = $self->call( 'GetWorksheetDetailServiceItems', $worksheet_id,
        worksheetDetailServiceItemsInput =>
            ixhash( WorksheetId => $worksheet_id ) );

    my $items = force_arrayref( $res->{Worksheetserviceitems},
        'WorksheetServiceItem' );

    return $items;
}

sub GetCollectionByUprnAndDatePlus {
    my ( $self, $uprn, $date_from, $date_to ) = @_;

    my $res = $self->call(
        'GetCollectionByUprnAndDatePlus', "$uprn $date_from $date_to",
        getCollectionByUprnAndDatePlusInput => ixhash(
            Uprn                   => $uprn,
            NextCollectionFromDate => $date_from,
            NextCollectionToDate => $date_to,
        ),
    );

    return force_arrayref( $res->{Collections}, 'Collection' );
}

sub GetInCabLogsByUsrn {
    my ($self, $usrn, $log_from_date) = @_;

    my $res = $self->call('GetInCabLogs', "$usrn $log_from_date",
        inCabLogInput => ixhash( Usrn => $usrn, LogFromDate => $log_from_date, LogTypeID => [] ));

    my $logs = force_arrayref( $res->{InCabLogs}, 'InCabLogs' );

    return $logs;
}

sub GetInCabLogsByUprn {
    my ($self, $uprn, $log_from_date) = @_;

    my $res = $self->call('GetInCabLogs', "$uprn $log_from_date",
        inCabLogInput => ixhash( Uprn => $uprn, LogFromDate => $log_from_date, LogTypeID => [] ));

    my $logs = force_arrayref( $res->{InCabLogs}, 'InCabLogs' );

    return $logs;
}

sub GetStreets {
    my ($self, $postcode) = @_;

    my $res = $self->call('GetStreets', $postcode,
        getStreetInput => ixhash( streetName => '', townName => '', postcode => $postcode ));

    my $streets = force_arrayref($res->{StreetArray}, 'Street');

    return $streets;
}

sub GetSiteIncidents {
    my ($self, $uprn) = @_;

    my $res = $self->call('GetSiteIncidents', $uprn,
        roundIncidentInput => ixhash( Uprn => $uprn ));

    return $res->{RoundIncidents}->{RoundIncidents};
}

sub GetFullWorksheetDetails {
    my ( $self, $ws_id ) = @_;

    my $res = $self->call( 'GetFullWorksheetDetails', $ws_id,
        fullworksheetDetailsInput => ixhash( WorksheetId => $ws_id ) );

    return $res->{FullWSDetails};
}

sub GetCollectionSlots {
    my ( $self, $uprn, $from, $to ) = @_;
    my $res = $self->call( 'GetCollectionSlots', "$uprn $from $to",
        collectionSlotsInputInput => ixhash(
            Uprn => $uprn,
            ServiceId => 78,
            NextCollectionFromDate => $from,
            NextCollectionToDate => $to,
        )
    );
    $self->log($res);
    return force_arrayref($res->{ApiAdHocRoundInstances}, 'ApiAdHocRoundInstance');;
}

1;
