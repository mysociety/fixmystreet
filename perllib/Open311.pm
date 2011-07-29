package Open311;

use URI;
use Moose;
use XML::Simple;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

has jurisdiction => ( is => 'ro', isa => 'Str' );;
has api_key => ( is => 'ro', isa => 'Str' );
has endpoint => ( is => 'ro', isa => 'Str' );

sub get_service_list {
    my $self = shift;

    my $service_list_xml = $self->_get( 'services.xml' );
}

sub get_service_meta_info {
    my $self = shift;
    my $service_id = shift;

    my $service_meta_xml = $self->_get( "services/$service_id.xml" );
}

sub send_service_request {
    my $self = shift;
    my $problem = shift;

    my $description = <<EOT;
title:  @{[$problem->title()]}

detail: @{[$problem->detail()]}

Submitted via FixMyStreet
EOT
;

    my $params = {
        lat => $problem->latitude,
        long => $problem->longitude,
        email => $problem->user->email,
        description => $description,
    };

    if ( $problem->user->phone ) {
        $params->{ phone } = $problem->user->phone;
    }

    if ( $problem->extra ) {
        my $extras = $problem->extra;

        for my $attr ( keys %{ $extras } ) {
            my $name = sprintf( 'attribute[%s]', $attr );
            $params->{ $name } = $extras->{ $attr };
        }
    }

    my $response = $self->_post( 'requests.xml', $params );

    my $xml = XML::Simple->new();
    my $obj = $xml->XMLin( $response );

    if ( $obj->{ request }->{ service_request_id } ) {
        return $obj->{ request }->{ service_request_id };
    } else {
        my $token = $obj->{ request }->{ token };
        return $self->get_service_request_id_from_token( $token );
    }
}

sub get_service_requests {
    my $self = shift;

    my $service_request_xml = $self->_get( 'requests.xml' );
}

sub get_service_request_id_from_token {
    my $self = shift;
    my $token = shift;

    my $service_token_xml = $self->_get( "tokens/$token.xml" );

    my $xml = XML::Simple->new();
    my $obj = $xml->XMLin( $service_token_xml );

    return $obj->{ request }->{ service_request_id };
}

sub _get {
    my $self   = shift;
    my $path   = shift;
    my $params = shift;

    my $uri = URI->new( $self->endpoint );
    $uri->path( $uri->path . $path );
    $uri->query_form( jurisdiction_id => $self->jurisdiction );

    my $content = get( $uri->as_string );

    return $content;
}

sub _post {
    my $self = shift;
    my $path   = shift;
    my $params = shift;

    my $uri = URI->new( $self->endpoint );
    $uri->path( $uri->path . $path );

    use Data::Dumper;
    my $req = POST $uri->as_string,
    [
        jurisdiction_id => $self->jurisdiction,
        api_key => $self->api_key,
        %{ $params }
    ];

    my $ua = LWP::UserAgent->new();
    my $res = $ua->request( $req );

    if ( $res->is_success ) {
        return $res->decoded_content;
    } else {
        return 0;
    }
}
1;
