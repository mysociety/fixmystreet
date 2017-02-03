package FixMyStreet::SendReport::Open311;

use Moo;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::SendReport'; }

use DateTime::Format::W3CDTF;
use Open311;
use Readonly;

Readonly::Scalar my $COUNCIL_ID_OXFORDSHIRE => 2237;
Readonly::Scalar my $COUNCIL_ID_WARWICKSHIRE => 2243;
Readonly::Scalar my $COUNCIL_ID_GREENWICH => 2493;
Readonly::Scalar my $COUNCIL_ID_BROMLEY => 2482;

has open311_test_req_used => (
    is => 'rw',
);

sub send {
    my $self = shift;
    my ( $row, $h ) = @_;

    my $result = -1;

    foreach my $body ( @{ $self->bodies } ) {
        my $conf = $self->body_config->{ $body->id };

        my $always_send_latlong = 1;
        my $send_notpinpointed  = 0;
        my $use_service_as_deviceid = 0;

        my $extended_desc = 1;

        my $extra = $row->get_extra_fields();

        # Extra bromley fields
        if ( $row->bodies_str eq $COUNCIL_ID_BROMLEY ) {
            push @$extra, { name => 'report_url', value => $h->{url} };
            push @$extra, { name => 'report_title', value => $row->title };
            push @$extra, { name => 'public_anonymity_required', value => $row->anonymous ? 'TRUE' : 'FALSE' };
            push @$extra, { name => 'email_alerts_requested', value => 'FALSE' }; # always false as can never request them
            push @$extra, { name => 'requested_datetime', value => DateTime::Format::W3CDTF->format_datetime($row->confirmed->set_nanosecond(0)) };
            push @$extra, { name => 'email', value => $row->user->email };
            # make sure we have last_name attribute present in row's extra, so
            # it is passed correctly to Bromley as attribute[]
            if ( $row->cobrand ne 'bromley' ) {
                my ( $firstname, $lastname ) = ( $row->name =~ /(\w+)\.?\s+(.+)/ );
                push @$extra, { name => 'last_name', value => $lastname };
            }
            $always_send_latlong = 0;
            $send_notpinpointed = 1;
            $extended_desc = 0;
        } elsif ( $row->bodies_str =~ /\b$COUNCIL_ID_OXFORDSHIRE\b/ ) {
            # Oxfordshire doesn't have category metadata to fill these
            $extended_desc = 'oxfordshire';
            push @$extra, { name => 'external_id', value => $row->id };
            push @$extra, { name => 'closest_address', value => $h->{closest_address} } if $h->{closest_address};
            if ( $row->used_map || ( !$row->used_map && !$row->postcode ) ) {
                push @$extra, { name => 'northing', value => $h->{northing} };
                push @$extra, { name => 'easting', value => $h->{easting} };
            }
        } elsif ( $row->bodies_str =~ /\b$COUNCIL_ID_WARWICKSHIRE\b/ ) {
            $extended_desc = 'warwickshire';
            push @$extra, { name => 'closest_address', value => $h->{closest_address} } if $h->{closest_address};
        } elsif ( $row->bodies_str == $COUNCIL_ID_GREENWICH ) {
            # Greenwich doesn't have category metadata to fill this
            push @$extra, { name => 'external_id', value => $row->id };
        }

        # Try and fill in some ones that we've been asked for, but not asked the user for

        my $contact = $row->result_source->schema->resultset("Contact")->find( {
            deleted => 0,
            body_id => $body->id,
            category => $row->category
        } );

        my $id_field = $contact->id_field;
        foreach (@{$contact->get_extra_fields}) {
            if ($_->{code} eq $id_field) {
                push @$extra, { name => $id_field, value => $row->id };
            } elsif ($_->{code} eq 'closest_address' && $h->{closest_address}) {
                push @$extra, { name => $_->{code}, value => $h->{$_->{code}} };
            } elsif ($_->{code} =~ /^(easting|northing)$/) {
                if ( $row->used_map || ( !$row->used_map && !$row->postcode ) ) {
                    push @$extra, { name => $_->{code}, value => $h->{$_->{code}} };
                }
            }
        }

        $row->set_extra_fields( @$extra ) if @$extra;

        my %open311_params = (
            jurisdiction            => $conf->jurisdiction,
            endpoint                => $conf->endpoint,
            api_key                 => $conf->api_key,
            always_send_latlong     => $always_send_latlong,
            send_notpinpointed      => $send_notpinpointed,
            use_service_as_deviceid => $use_service_as_deviceid,
            extended_description    => $extended_desc,
        );
        if (FixMyStreet->test_mode) {
            my $test_res = HTTP::Response->new();
            $test_res->code(200);
            $test_res->message('OK');
            $test_res->content('<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>');
            $open311_params{test_mode} = 1;
            $open311_params{test_get_returns} = { 'requests.xml' => $test_res };
        }

        my $open311 = Open311->new( %open311_params );

        # non standard west berks end points
        if ( $row->bodies_str =~ /2619/ ) {
            $open311->endpoints( { services => 'Services', requests => 'Requests' } );
        }

        # non-standard Oxfordshire endpoint (because it's just a script, not a full Open311 service)
        if ( $row->bodies_str =~ /$COUNCIL_ID_OXFORDSHIRE/ ) {
            $open311->endpoints( { requests => 'open311_service_request.cgi' } );
        }

        # required to get round issues with CRM constraints
        if ( $row->bodies_str =~ /2218/ ) {
            $row->user->name( $row->user->id . ' ' . $row->user->name );
        }

        my $resp = $open311->send_service_request( $row, $h, $contact->email );
        if (FixMyStreet->test_mode) {
            $self->open311_test_req_used($open311->test_req_used);
        }

        # make sure we don't save user changes from above
        $row->discard_changes();

        if ( $resp ) {
            $row->external_id( $resp );
            $row->send_method_used('Open311');
            $result *= 0;
            $self->success( 1 );
        } else {
            $result *= 1;
            $self->error( "Failed to send over Open311\n" ) unless $self->error;
            $self->error( $self->error . "\n" . $open311->error );
        }
    }


    return $result;
}

1;
