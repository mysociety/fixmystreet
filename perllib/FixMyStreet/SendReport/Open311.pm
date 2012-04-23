package FixMyStreet::SendReport::Open311;

use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::SendReport'; }

use FixMyStreet::App;
use mySociety::Config;
use Open311;

sub should_skip {
    my $self = shift;
    my $row  = shift;

    if ( $row->send_fail_count > 0 ) {
        if ( bromley_retry_timeout($row) ) {
            return 1;
        }
    }
}

sub send {
    my $self = shift;
    my ( $row, $h, $to, $template, $recips, $nomail ) = @_;

    my $result = -1;

    foreach my $council ( keys %{ $self->councils } ) {
        my $conf = FixMyStreet::App->model("DB::Open311conf")->search( { area_id => $council, endpoint => { '!=', '' } } )->first;

        my $extended_sendrequest = 0;
        # Extra bromley fields
        if ( $row->council =~ /2482/ ) {
            $extended_sendrequest = 1;
        }

        # FIXME: we've already looked this up before
        my $contact = FixMyStreet::App->model("DB::Contact")->find( {
            deleted => 0,
            area_id => $conf->area_id,
            category => $row->category
        } );

        my $open311 = Open311->new(
            jurisdiction         => $conf->jurisdiction,
            endpoint             => $conf->endpoint,
            api_key              => $conf->api_key,
            extended_sendrequest => $extended_sendrequest,
        );

        # non standard west berks end points
        if ( $row->council =~ /2619/ ) {
            $open311->endpoints( { services => 'Services', requests => 'Requests' } );
        }

        # required to get round issues with CRM constraints
        if ( $row->council =~ /2218/ ) {
            $row->user->name( $row->user->id . ' ' . $row->user->name );
        }

        my $resp = $open311->send_service_request( $row, $h, $contact->email );

        # make sure we don't save user changes from above
        if ( $row->council =~ /2218/ || $row->council =~ /2482/ ) {
            $row->discard_changes();
        }

        if ( $resp ) {
            $row->external_id( $resp );
            $result *= 0;
            $self->success( 1 );
        } else {
            $result *= 1;
            # temporary fix to resolve some issues with west berks
            if ( $row->council =~ /2619/ ) {
                $result *= 0;
            }
        }
    }

    $self->error( 'Failed to send over Open311' ) unless $self->success;

    return $result;
}

sub bromley_retry_timeout {
    my $row = shift;

    my $tz = DateTime::TimeZone->new( name => 'local' );
    my $now = DateTime->now( time_zone => $tz );
    my $diff = $now - $row->send_fail_timestamp;
    if ( $diff->in_units( 'minutes' ) < 30 ) {
        return 1;
    }

    return 0;
}

1;
