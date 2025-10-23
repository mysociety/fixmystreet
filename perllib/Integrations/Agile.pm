=head1 NAME

Integrations::Agile - Agile Applications API integration

=head1 DESCRIPTION

This module provides an interface to the Agile Applications API

=cut

package Integrations::Agile;

use strict;
use warnings;

use HTTP::Request;
use JSON::MaybeXS;
use LWP::UserAgent;
use Moo;
use URI;

has url => ( is => 'ro' );

# TODO Logging

sub call {
    my ( $self, %args ) = @_;

    my $action = $args{action};
    my $controller = $args{controller};
    my $data = $args{data};
    my $method = 'POST';

    my $body = {
        Method     => $method,
        Controller => $controller,
        Action     => $action,
        Data       => $data,
    };
    my $body_json = encode_json($body);

    my $uri = URI->new( $self->{url} );

    my $req = HTTP::Request->new( $method, $uri );
    $req->content_type('application/json; charset=UTF-8');
    $req->content($body_json);

    my $ua = LWP::UserAgent->new;
    my $res = $ua->request($req);

    if ( $res->is_success ) {
        return decode_json( $res->content );
    } else {
        return {
            error => $res->code,
            error_message => $res->content
        };
    }
}

sub IsAddressFree {
    my ( $self, $uprn ) = @_;

    return $self->call(
        action     => 'isaddressfree',
        controller => 'customer',
        data       => { UPRN => $uprn },
    );
}

sub CustomerSearch {
    my ( $self, $uprn ) = @_;

    return $self->call(
        action     => 'search',
        controller => 'customer',
        data       => { ServiceContractUPRN => $uprn },
    );
}

sub LastCancelled {
    my ( $self, $days ) = @_;

    my $response = $self->call(
        action     => 'lastCancelled',
        controller => 'servicecontract',
        data       => { NumberOfDays => $days },
    );

    if (ref $response eq 'HASH' && exists $response->{error}) {
        return $response;
    }

    # TODO: Confirm which format is correct, the documentation suggests a hash
    # with a ServiceContracts key but the actual response is an array. This
    # is a workaround to handle both formats.
    if (ref $response eq 'HASH' && exists $response->{ServiceContracts}) {
        return $response->{ServiceContracts};
    }
    if (ref $response eq 'ARRAY') {
        return $response;
    }

    warn "Unexpected response format from Agile LastCancelled\n";
    return { error => "Unexpected response format from Agile LastCancelled" };
}

1;
