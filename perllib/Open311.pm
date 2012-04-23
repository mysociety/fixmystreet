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
has test_mode => ( is => 'ro', isa => 'Bool' );
has test_uri_used => ( is => 'rw', 'isa' => 'Str' );
has test_req_used => ( is => 'rw' );
has test_get_returns => ( is => 'rw' );
has endpoints => ( is => 'rw', default => sub { { services => 'services.xml', requests => 'requests.xml', service_request_updates => 'update.xml', update => 'update.xml' } } );
has debug => ( is => 'ro', isa => 'Bool', default => 0 );
has debug_details => ( is => 'rw', 'isa' => 'Str', default => '' );
has success => ( is => 'rw', 'isa' => 'Bool', default => 0 );
has error => ( is => 'rw', 'isa' => 'Str', default => '' );
has extended_sendrequest => ( is => 'ro', isa => 'Bool', default => 0 );

sub get_service_list {
    my $self = shift;

    my $service_list_xml = $self->_get( $self->endpoints->{services} );

    return $self->_get_xml_object( $service_list_xml );
}

sub get_service_meta_info {
    my $self = shift;
    my $service_id = shift;

    my $service_meta_xml = $self->_get( "services/$service_id.xml" );
    return $self->_get_xml_object( $service_meta_xml );
}

sub send_service_request {
    my $self = shift;
    my $problem = shift;
    my $extra = shift;
    my $service_code = shift;

    my $params = $self->_populate_service_request_params(
        $problem, $extra, $service_code
    );

    my $response = $self->_post( $self->endpoints->{requests}, $params );

    if ( $response ) {
        my $obj = $self->_get_xml_object( $response );

        if ( $obj ) {
            if ( $obj->{ request }->{ service_request_id } ) {
                return $obj->{ request }->{ service_request_id };
            } else {
                my $token = $obj->{ request }->{ token };
                if ( $token ) {
                    return $self->get_service_request_id_from_token( $token );
                }
            }
        }

        warn sprintf( "Failed to submit problem %s over Open311, response\n: %s\n%s", $problem->id, $response, $self->debug_details );
        return 0;
    }
}

sub _populate_service_request_params {
    my $self = shift;
    my $problem = shift;
    my $extra = shift;
    my $service_code = shift;

    my $description = $self->_generate_service_request_description(
        $problem, $extra
    );

    my ( $firstname, $lastname ) = ( $problem->user->name =~ /(\w+)\s+(.+)/ );

    my $params = {
        lat => $problem->latitude,
        long => $problem->longitude,
        email => $problem->user->email,
        description => $description,
        service_code => $service_code,
        first_name => $firstname,
        last_name => $lastname || '',
    };

    if ( $problem->user->phone ) {
        $params->{ phone } = $problem->user->phone;
    }

    if ( $extra->{image_url} ) {
        $params->{media_url} = $extra->{image_url};
    }

    if ( $self->extended_sendrequest ) {
        $params->{northing}               = $extra->{northing};
        $params->{easting}                = $extra->{easting};
        $params->{report_url}             = $extra->{url};
        $params->{service_request_id_ext} = $problem->id;
        $params->{report_title}           = $problem->title;
        $params->{email_alerts_requested} = 'FALSE';              # always false
        $params->{requested_datetime}     = $problem->confirmed;

        $params->{public_anonymity_required} = $problem->anonymous ? 'TRUE' : 'FALSE';
    }

    if ( $problem->extra ) {
        my $extras = $problem->extra;

        for my $attr ( @$extras ) {
            my $attr_name = $attr->{name};
            if ( $self->extended_sendrequest ) {
                if ( $attr_name eq 'first_name' || $attr_name eq 'last_name' ) {
                    $params->{$attr_name} = $attr->{value} if $attr->{value};
                    next;
                }
                if ( $attr_name eq 'fms_extra_title' ) {
                    $params->{title} = $attr->{value} if $attr->{value};
                    next;
                }
            }
            $attr_name =~ s/fms_extra_//;
            my $name = sprintf( 'attribute[%s]', $attr_name );
            $params->{ $name } = $attr->{value};
        }
    }

    return $params;
}

sub _generate_service_request_description {
    my $self = shift;
    my $problem = shift;
    my $extra = shift;

    my $description = <<EOT;
title: @{[$problem->title()]}

detail: @{[$problem->detail()]}

url: $extra->{url}

Submitted via FixMyStreet
EOT
;

    return $description;
}

sub get_service_requests {
    my $self = shift;
    my $report_ids = shift;

    my $params = {};

    if ( $report_ids ) {
        $params->{service_request_id} = join ',', @$report_ids;
    }

    my $service_request_xml = $self->_get( $self->endpoints->{requests}, $params || undef );
    return $self->_get_xml_object( $service_request_xml );
}

sub get_service_request_id_from_token {
    my $self = shift;
    my $token = shift;

    my $service_token_xml = $self->_get( "tokens/$token.xml" );

    my $obj = $self->_get_xml_object( $service_token_xml );

    if ( $obj && $obj->{ request }->{ service_request_id } ) {
        return $obj->{ request }->{ service_request_id };
    } else {
        return 0;
    }
}

sub get_service_request_updates {
    my $self = shift;
    my $start_date = shift;
    my $end_date = shift;

    my $params = {};

    if ( $start_date || $end_date ) {
        return 0 unless $start_date && $end_date;

        $params->{start_date} = $start_date;
        $params->{end_date} = $end_date;
    }

    my $xml = $self->_get( $self->endpoints->{service_request_updates}, $params || undef );
    my $service_requests = $self->_get_xml_object( $xml );
    my $requests;
    if ( ref $service_requests->{request_update } eq 'ARRAY' ) {
        $requests = $service_requests->{request_update};
    }
    else {
        $requests = [ $service_requests->{request_update} ];
    }

    return $requests;
}

sub post_service_request_update {
    my $self = shift;
    my $comment = shift;

    my $params = $self->_populate_service_request_update_params( $comment );

    my $response = $self->_post( $self->endpoints->{update}, $params );

    if ( $response ) {
        my $obj = $self->_get_xml_object( $response );

        if ( $obj ) {
            if ( $obj->{ request_update }->{ update_id } ) {
                my $update_id = $obj->{request_update}->{update_id};

                # if there's nothing in the update_id element we get a HASHREF back
                unless ( ref $update_id ) {
                    return $obj->{ request_update }->{ update_id };
                }
            } else {
                my $token = $obj->{ request_update }->{ token };
                if ( $token ) {
                    return $self->get_service_request_id_from_token( $token );
                }
            }
        }

        warn sprintf( "Failed to submit comment %s over Open311, response - %s\n%s", $comment->id, $response, $self->debug_details );
        return 0;
    }
}

sub _populate_service_request_update_params {
    my $self = shift;
    my $comment = shift;

    my $name = $comment->name || $comment->user->name;
    my ( $firstname, $lastname ) = ( $name =~ /(\w+)\s+(.+)/ );

    my $params = {
        update_id_ext => $comment->id,
        updated_datetime => $comment->confirmed,
        service_request_id => $comment->problem->external_id,
        service_request_id_ext => $comment->problem->id,
        status => $comment->problem->is_open ? 'OPEN' : 'CLOSED',
        email => $comment->user->email,
        description => $comment->text,
        public_anonymity_required => $comment->anonymous ? 'TRUE' : 'FALSE',
        last_name => $lastname,
        first_name => $firstname,
    };

    if ( $comment->extra ) {
        $params->{'email_alerts_requested'}
            = $comment->extra->{email_alerts_requested} ? 'TRUE' : 'FALSE';
        $params->{'title'} = $comment->extra->{title};

        $params->{first_name} = $comment->extra->{first_name} if $comment->extra->{first_name};
        $params->{last_name} = $comment->extra->{last_name} if $comment->extra->{last_name};
    }

    return $params;
}

sub _get {
    my $self   = shift;
    my $path   = shift;
    my $params = shift || {};

    my $uri = URI->new( $self->endpoint );

    $params->{ jurisdiction_id } = $self->jurisdiction;
    $uri->path( $uri->path . $path );
    $uri->query_form( $params );

    $self->debug_details( $self->debug_details . "\nrequest:" . $uri->as_string );

    my $content;
    if ( $self->test_mode ) {
        $self->success(1);
        $content = $self->test_get_returns->{ $path };
        $self->test_uri_used( $uri->as_string );
    } else {
        my $ua = LWP::UserAgent->new;

        my $req = HTTP::Request->new(
            GET => $uri->as_string
        );

        my $res = $ua->request( $req );

        if ( $res->is_success ) {
            $content = $res->decoded_content;
            $self->success(1);
        } else {
            $self->success(0);
            $self->error( $res->status_line );
        }
    }

    return $content;
}

sub _post {
    my $self = shift;
    my $path   = shift;
    my $params = shift;

    my $uri = URI->new( $self->endpoint );
    $uri->path( $uri->path . $path );

    my $req = POST $uri->as_string,
    [
        jurisdiction_id => $self->jurisdiction,
        api_key => $self->api_key,
        %{ $params }
    ];

    $self->debug_details( $self->debug_details . "\nrequest:" . $req->as_string );

    my $ua = LWP::UserAgent->new();
    my $res;

    if ( $self->test_mode ) {
        $res = $self->test_get_returns->{ $path };
        $self->test_req_used( $req );
    } else {
        $res = $ua->request( $req );
    }

    if ( $res->is_success ) {
        $self->success(1);
        return $res->decoded_content;
    } else {
        $self->success(0);
        $self->error( sprintf( 
            "request failed: %s\nerror: %s\n%s",
            $res->status_line,
            $self->_process_error( $res->decoded_content ),
            $self->debug_details
        ) );
        warn $self->error;
        return 0;
    }
}

sub _process_error {
    my $self = shift;
    my $error = shift;

    my $obj = $self->_get_xml_object( $error );

    my $msg = '';
    if ( ref $obj && exists $obj->{error} ) {
        my $errors = $obj->{error};
        $errors = [ $errors ] if ref $errors ne 'ARRAY';
        $msg .= sprintf( "%s: %s\n", $_->{code}, $_->{description} ) for @{ $errors };
    }

    return $msg || 'unknown error';
}

sub _get_xml_object {
    my $self = shift;
    my $xml= shift;

    my $simple = XML::Simple->new();
    my $obj;

    eval {
        $obj = $simple ->XMLin( $xml );
    };

    return $obj;
}
1;
