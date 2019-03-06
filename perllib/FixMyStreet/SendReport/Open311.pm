package FixMyStreet::SendReport::Open311;

use Moo;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::SendReport'; }

use Open311;

has open311_test_req_used => (
    is => 'rw',
);

sub send {
    my $self = shift;
    my ( $row, $h ) = @_;

    my $result = -1;

    foreach my $body ( @{ $self->bodies } ) {
        my $conf = $self->body_config->{ $body->id };

        my %open311_params = (
            jurisdiction            => $conf->jurisdiction,
            endpoint                => $conf->endpoint,
            api_key                 => $conf->api_key,
            always_send_latlong     => 1,
            send_notpinpointed      => 0,
            use_service_as_deviceid => 0,
            extended_description    => 1,
            multi_photos            => 0,
            fixmystreet_body => $body,
        );

        my $cobrand = $body->get_cobrand_handler || $row->get_cobrand_logged;
        $cobrand->call_hook(open311_config => $row, $h, \%open311_params);

        # Try and fill in some ones that we've been asked for, but not asked the user for

        my $contact = $row->result_source->schema->resultset("Contact")->not_deleted->find( {
            body_id => $body->id,
            category => $row->category
        } );

        my $extra = $row->get_extra_fields();

        my $id_field = $contact->id_field;
        foreach (@{$contact->get_extra_fields}) {
            if ($_->{code} eq $id_field) {
                push @$extra, { name => $id_field, value => $row->id };
            } elsif ($_->{code} eq 'closest_address' && $h->{closest_address}) {
                push @$extra, { name => $_->{code}, value => "$h->{closest_address}" };
            } elsif ($_->{code} =~ /^(easting|northing)$/) {
                # NB If there's ever a cobrand with always_send_latlong=0 and
                # send_notpinpointed=0 then this line will need changing to
                # consider the send_notpinpointed check, as per the
                # '#NOTPINPOINTED#' code in perllib/Open311.pm.
                if ( $row->used_map || $open311_params{always_send_latlong} || (
                    !$row->used_map && !$row->postcode && $open311_params{send_notpinpointed}
                ) ) {
                    push @$extra, { name => $_->{code}, value => $h->{$_->{code}} };
                }
            }
        }

        $row->set_extra_fields( @$extra ) if @$extra;

        if (FixMyStreet->test_mode) {
            my $test_res = HTTP::Response->new();
            $test_res->code(200);
            $test_res->message('OK');
            $test_res->content('<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>');
            $open311_params{test_mode} = 1;
            $open311_params{test_get_returns} = { 'requests.xml' => $test_res };
        }

        my $open311 = Open311->new( %open311_params );

        $cobrand->call_hook(open311_pre_send => $row, $open311);

        my $resp = $open311->send_service_request( $row, $h, $contact->email );
        if (FixMyStreet->test_mode) {
            $self->open311_test_req_used($open311->test_req_used);
        }

        # make sure we don't save user changes from above
        $row->discard_changes();

        if ( $resp ) {
            $row->external_id( $resp );
            $result *= 0;
            $self->success( 1 );
        } else {
            $result *= 1;
            $self->error( "Failed to send over Open311\n" ) unless $self->error;
            $self->error( $self->error . "\n" . $open311->error );
        }

        $cobrand->call_hook(open311_post_send => $row, $h);
    }


    return $result;
}

1;
