package FixMyStreet::SendReport::Open311;

use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::SendReport'; }

use FixMyStreet::App;
use mySociety::Config;
use DateTime::Format::W3CDTF;
use Open311;
use Readonly;

Readonly::Scalar my $COUNCIL_ID_OXFORDSHIRE => 2237;

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
    my ( $row, $h ) = @_;

    my $result = -1;

    foreach my $council ( keys %{ $self->councils } ) {
        my $conf = $self->councils->{$council}->{config};

        my $always_send_latlong = 1;
        my $send_notpinpointed  = 0;
        my $use_service_as_deviceid = 0;

        my $extended_desc = 1;

        # Extra bromley fields
        if ( $row->council =~ /2482/ ) {

            my $extra = $row->extra;
            if ( $row->used_map || ( !$row->used_map && !$row->postcode ) ) {
                push @$extra, { name => 'northing', value => $h->{northing} };
                push @$extra, { name => 'easting', value => $h->{easting} };
            }
            push @$extra, { name => 'report_url', value => $h->{url} };
            push @$extra, { name => 'service_request_id_ext', value => $row->id };
            push @$extra, { name => 'report_title', value => $row->title };
            push @$extra, { name => 'public_anonymity_required', value => $row->anonymous ? 'TRUE' : 'FALSE' };
            push @$extra, { name => 'email_alerts_requested', value => 'FALSE' }; # always false as can never request them
            push @$extra, { name => 'requested_datetime', value => DateTime::Format::W3CDTF->format_datetime($row->confirmed_local->set_nanosecond(0)) };
            push @$extra, { name => 'email', value => $row->user->email };
            $row->extra( $extra );

            $always_send_latlong = 0;
            $send_notpinpointed = 1;
            $use_service_as_deviceid = 0;

            # make sure we have last_name attribute present in row's extra, so
            # it is passed correctly to Bromley as attribute[]
            if ( $row->cobrand ne 'bromley' ) {
                my ( $firstname, $lastname ) = ( $row->user->name =~ /(\w+)\.?\s+(.+)/ );
                push @$extra, { name => 'last_name', value => $lastname };
            }

            $extended_desc = 0;
        }

        # extra Oxfordshire fields: send nearest street, postcode, northing and easting, and the FMS id
        if ( $row->council =~ /$COUNCIL_ID_OXFORDSHIRE/ ) {
            my ($postcode, $nearest_street) = ('', '');
            for ($h->{closest_address}) {
                $postcode = sprintf("%-10s", $1) if /Nearest postcode [^:]+: ((\w{1,4}\s?\w+|\w+))/;
                    # use partial postcode or comma as delimiter, strip leading number (possible letter 221B) off too
                    #    "99 Foo Street, London N11 1XX" becomes Foo Street
                    #    "99 Foo Street N11 1XX" becomes Foo Street
                $nearest_street = $1 if /Nearest road [^:]+: (?:\d+\w? )?(.*?)(\b[A-Z]+\d|,|$)/m;
            }
            $postcode = mySociety::PostcodeUtil::is_valid_postcode($h->{query})
                ? $h->{query} : $postcode; # use given postcode if available

            my $extra = $row->extra;
            push @$extra, { name => 'external_id', value => $row->id };
            push @$extra, { name => 'postcode', value => $postcode } if $postcode;
            push @$extra, { name => 'nearest_street', value => $nearest_street } if $nearest_street;
            if ( $row->used_map || ( !$row->used_map && !$row->postcode ) ) {
                push @$extra, { name => 'northing', value => $h->{northing} };
                push @$extra, { name => 'easting', value => $h->{easting} };
            }
            $row->extra( $extra );

            $extended_desc = 'oxfordshire';
        }

        # FIXME: we've already looked this up before
        my $contact = FixMyStreet::App->model("DB::Contact")->find( {
            deleted => 0,
            area_id => $conf->area_id,
            category => $row->category
        } );

        my $open311 = Open311->new(
            jurisdiction            => $conf->jurisdiction,
            endpoint                => $conf->endpoint,
            api_key                 => $conf->api_key,
            always_send_latlong     => $always_send_latlong,
            send_notpinpointed      => $send_notpinpointed,
            use_service_as_deviceid => $use_service_as_deviceid,
            extended_description    => $extended_desc,
        );

        # non standard west berks end points
        if ( $row->council =~ /2619/ ) {
            $open311->endpoints( { services => 'Services', requests => 'Requests' } );
        }

        # non-standard Oxfordshire endpoint (because it's just a script, not a full Open311 service)
        if ( $row->council =~ /$COUNCIL_ID_OXFORDSHIRE/ ) {
            $open311->endpoints( { requests => 'open311_service_request.cgi' } );
        }

        # required to get round issues with CRM constraints
        if ( $row->council =~ /2218/ ) {
            $row->user->name( $row->user->id . ' ' . $row->user->name );
        }

        if ($row->cobrand eq 'fixmybarangay') {
            # FixMyBarangay endpoints expect external_id as an attribute, as do Oxfordshire
            $row->extra( [ { 'name' => 'external_id', 'value' => $row->id  } ]  );
        }

        my $resp = $open311->send_service_request( $row, $h, $contact->email );

        # make sure we don't save user changes from above
        if ( $row->council =~ /(2218|2482|$COUNCIL_ID_OXFORDSHIRE)/ || $row->cobrand eq 'fixmybarangay') {
            $row->discard_changes();
        }

        if ( $resp ) {
            $row->external_id( $resp );
            $row->send_method_used('Open311');
            if ($row->cobrand eq 'fixmybarangay') {
                # currently the only external body using Open311 is DPS
                # (this will change when we have 'body' logic in place, meanwhile: hardcoded)
                $row->external_body("DPS");
            }
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
