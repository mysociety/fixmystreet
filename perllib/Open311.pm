package Open311;

use utf8;
use URI;
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use XML::Simple;
use LWP::Simple;
use LWP::UserAgent;
use DateTime::Format::W3CDTF;
use HTTP::Request::Common qw(POST);
use FixMyStreet::Cobrand;
use FixMyStreet::DB;

has jurisdiction => ( is => 'ro', isa => Str );;
has api_key => ( is => 'ro', isa => Str );
has endpoint => ( is => 'ro', isa => Str );
has test_mode => ( is => 'ro', isa => Bool );
has test_uri_used => ( is => 'rw', 'isa' => Str );
has test_req_used => ( is => 'rw' );
has test_get_returns => ( is => 'rw' );
has endpoints => ( is => 'rw', default => sub { { services => 'services.xml', requests => 'requests.xml', service_request_updates => 'servicerequestupdates.xml', update => 'servicerequestupdates.xml' } } );
has debug => ( is => 'ro', isa => Bool, default => 0 );
has debug_details => ( is => 'rw', 'isa' => Str, default => '' );
has success => ( is => 'rw', 'isa' => Bool, default => 0 );
has error => ( is => 'rw', 'isa' => Str, default => '' );
has always_send_latlong => ( is => 'ro', isa => Bool, default => 1 );
has send_notpinpointed => ( is => 'ro', isa => Bool, default => 0 );
has extended_description => ( is => 'ro', isa => Str, default => 1 );
has use_service_as_deviceid => ( is => 'ro', isa => Bool, default => 0 );
has use_extended_updates => ( is => 'ro', isa => Bool, default => 0 );
has extended_statuses => ( is => 'ro', isa => Bool, default => 0 );

before [
    qw/get_service_list get_service_meta_info get_service_requests get_service_request_updates
      send_service_request post_service_request_update/
  ] => sub {
    shift->debug_details('');
  };

sub get_service_list {
    my $self = shift;

    my $service_list_xml = $self->_get( $self->endpoints->{services} );

    if ( $service_list_xml ) {
        return $self->_get_xml_object( $service_list_xml );
    } else {
        return undef;
    }
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
                my $request_id = $obj->{request}->{service_request_id};

                unless ( ref $request_id ) {
                    return $request_id;
                }
            } else {
                my $token = $obj->{ request }->{ token };
                if ( $token ) {
                    return $self->get_service_request_id_from_token( $token );
                }
            }
        }

        warn sprintf( "Failed to submit problem %s over Open311, response\n: %s\n%s", $problem->id, $response, $self->debug_details )
            unless $problem->send_fail_count;
    } else {
        warn sprintf( "Failed to submit problem %s over Open311, details:\n%s", $problem->id, $self->error)
            unless $problem->send_fail_count;
    }
    return 0;
}

sub _populate_service_request_params {
    my $self = shift;
    my $problem = shift;
    my $extra = shift;
    my $service_code = shift;

    my $description;
    if ( $self->extended_description ) {
        $description = $self->_generate_service_request_description(
            $problem, $extra
        );
    } else {
        $description = $problem->detail;
    }

    my ( $firstname, $lastname ) = ( $problem->name =~ /(\w+)\.?\s+(.+)/ );

    my $params = {
        email => $problem->user->email,
        description => $description,
        service_code => $service_code,
        first_name => $firstname,
        last_name => $lastname || '',
    };

    # if you click nearby reports > skip map then it's possible
    # to end up with used_map = f and nothing in postcode
    if ( $problem->used_map || $self->always_send_latlong
        || ( !$self->send_notpinpointed && !$problem->used_map
             && !$problem->postcode ) )
    {
        $params->{lat} = $problem->latitude;
        $params->{long} = $problem->longitude;
    # this is a special case for sending to Bromley so they can
    # report accuracy levels correctly. We include easting and
    # northing as attributes elsewhere.
    } elsif ( $self->send_notpinpointed && !$problem->used_map
              && !$problem->postcode )
    {
        $params->{address_id} = '#NOTPINPOINTED#';
    } else {
        $params->{address_string} = $problem->postcode;
    }

    if ( $problem->user->phone ) {
        $params->{ phone } = $problem->user->phone;
    }

    if ( $extra->{image_url} ) {
        $params->{media_url} = $extra->{image_url};
    }

    if ( $self->use_service_as_deviceid && $problem->service ) {
        $params->{deviceid} = $problem->service;
    }

    for my $attr ( @{$problem->get_extra_fields} ) {
        my $attr_name = $attr->{name};
        if ( $attr_name eq 'first_name' || $attr_name eq 'last_name' ) {
            $params->{$attr_name} = $attr->{value} if $attr->{value};
            next if $attr_name eq 'first_name';
        }
        $attr_name =~ s/fms_extra_//;
        my $name = sprintf( 'attribute[%s]', $attr_name );
        $params->{ $name } = $attr->{value};
    }

    return $params;
}

sub _generate_service_request_description {
    my $self = shift;
    my $problem = shift;
    my $extra = shift;

    my $description = "";
    if ($extra->{easting_northing}) { # Proxy for cobrand being in the UK
        $description .= "detail: " . $problem->detail . "\n\n";
        $description .= "url: " . $extra->{url} . "\n\n";
        $description .= "Submitted via FixMyStreet\n";
        if ($self->extended_description ne 'oxfordshire') {
            $description = "title: " . $problem->title . "\n\n$description";
        }
    } elsif ($problem->cobrand eq 'fixamingata') {
        $description .= "Beskrivning: " . $problem->detail . "\n\n";
        $description .= "Länk till ärendet: " . $extra->{url} . "\n\n";
        $description .= "Skickad via FixaMinGata\n";
    } else {
        $description .= $problem->title . "\n\n";
        $description .= $problem->detail . "\n\n";
        $description .= $extra->{url} . "\n";
    }

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

    my $params = {
        api_key => $self->api_key,
    };

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

        warn sprintf( "Failed to submit comment %s over Open311, response - %s\n%s\n", $comment->id, $response, $self->debug_details )
            unless $comment->send_fail_count;
    } else {
        warn sprintf( "Failed to submit comment %s over Open311, details\n%s\n", $comment->id, $self->error)
            unless $comment->send_fail_count;
    }
    return 0;
}

sub _populate_service_request_update_params {
    my $self = shift;
    my $comment = shift;

    my $name = $comment->name || $comment->user->name;
    my ( $firstname, $lastname ) = ( $name =~ /(\w+)\.?\s+(.+)/ );
    $lastname ||= '-';

    # fall back to problem state as it's probably correct
    my $state = $comment->problem_state || $comment->problem->state;

    my $status = 'OPEN';
    if ( $self->extended_statuses ) {
        if ( FixMyStreet::DB::Result::Problem->fixed_states()->{$state} ) {
            $status = 'FIXED';
        } elsif ( $state eq 'in progress' ) {
            $status = 'IN_PROGRESS';
        } elsif ($state eq 'action scheduled'
            || $state eq 'planned' ) {
            $status = 'ACTION_SCHEDULED';
        } elsif ( $state eq 'investigating' ) {
            $status = 'INVESTIGATING';
        } elsif ( $state eq 'duplicate' ) {
            $status = 'DUPLICATE';
        } elsif ( $state eq 'not responsible' ) {
            $status = 'NOT_COUNCILS_RESPONSIBILITY';
        } elsif ( $state eq 'unable to fix' ) {
            $status = 'NO_FURTHER_ACTION';
        } elsif ( $state eq 'internal referral' ) {
            $status = 'INTERNAL_REFERRAL';
        }
    } else {
        if ( !FixMyStreet::DB::Result::Problem->open_states()->{$state} ) {
            $status = 'CLOSED';
        }
    }

    my $params = {
        updated_datetime => DateTime::Format::W3CDTF->format_datetime($comment->confirmed->set_nanosecond(0)),
        service_request_id => $comment->problem->external_id,
        status => $status,
        email => $comment->user->email,
        description => $comment->text,
        last_name => $lastname,
        first_name => $firstname,
    };

    if ( $self->use_extended_updates ) {
        $params->{public_anonymity_required} = $comment->anonymous ? 'TRUE' : 'FALSE',
        $params->{update_id_ext} = $comment->id;
        $params->{service_request_id_ext} = $comment->problem->id;
    } else {
        $params->{update_id} = $comment->id;
    }

    if ( $comment->photo ) {
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($comment->cobrand)->new();
        my $email_base_url = $cobrand->base_url($comment->cobrand_data);
        my $url = $email_base_url . '/photo/c/' . $comment->id . '.full.jpeg';
        $params->{media_url} = $url;
    }

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

    $params->{ jurisdiction_id } = $self->jurisdiction
        if $self->jurisdiction;
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
            $self->error( sprintf(
                "request failed: %s\n%s\n",
                $res->status_line,
                $uri->as_string
            ) );
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

    $params->{jurisdiction_id} = $self->jurisdiction
        if $self->jurisdiction;
    $params->{api_key} = $self->api_key
        if $self->api_key;
    my $req = POST $uri->as_string, $params;

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
            "request failed: %s\nerror: %s\n%s\n",
            $res->status_line,
            $self->_process_error( $res->decoded_content ),
            $self->debug_details
        ) );
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
        $obj = $simple ->parse_string( $xml, ForceArray => [ qr/^key$/, qr/^name$/ ]  );
    };

    return $obj;
}
1;
