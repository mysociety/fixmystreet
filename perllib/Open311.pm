package Open311;

use utf8;
use URI;
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use XML::Simple;
use LWP::Simple;
use LWP::UserAgent;
use DateTime::Format::W3CDTF;
use Encode;
use HTTP::Request::Common qw(GET POST);
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use Utils;
use Path::Tiny 'path';
use FixMyStreet::App::Model::PhotoSet;

has jurisdiction => ( is => 'ro', isa => Str );;
has api_key => ( is => 'ro', isa => Str );
has endpoint => ( is => 'ro', isa => Str );
has endpoints => ( is => 'rw', default => sub { { services => 'services.xml', requests => 'requests.xml', service_request_updates => 'servicerequestupdates.xml', update => 'servicerequestupdates.xml' } } );
has debug => ( is => 'ro', isa => Bool, default => 0 );
has debug_details => ( is => 'rw', 'isa' => Str, default => '' );
has success => ( is => 'rw', 'isa' => Bool, default => 0 );
has error => ( is => 'rw', 'isa' => Str, default => '' );
has always_send_latlong => ( is => 'ro', isa => Bool, default => 1 );
has send_notpinpointed => ( is => 'ro', isa => Bool, default => 0 );
has extended_description => ( is => 'ro', isa => Str, default => 1 );
has use_service_as_deviceid => ( is => 'ro', isa => Bool, default => 0 );
has extended_statuses => ( is => 'ro', isa => Bool, default => 0 );
has always_send_email => ( is => 'ro', isa => Bool, default => 0 );
has multi_photos => ( is => 'ro', isa => Bool, default => 0 );
has upload_files => ( is => 'ro', isa => Bool, default => 0 );
has upload_files_for_updates => ( is => 'ro', isa => Bool, default => 0 );
has always_upload_photos => ( is => 'ro', isa => Bool, default => 0 );
has use_customer_reference => ( is => 'ro', isa => Bool, default => 0 );
has mark_reopen => ( is => 'ro', isa => Bool, default => 0 );
has fixmystreet_body => ( is => 'ro', isa => InstanceOf['FixMyStreet::DB::Result::Body'] );
has service_code => ( is => 'ro', 'isa' => Str, default => '' );

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

sub ignore_failure {
    my $problem = shift;
    return unless $problem->cobrand =~ /fixmystreet|bristol|westminster/;
    my $bodies = $problem->bodies;
    return unless %$bodies;
    my $body = (values %$bodies)[0];
    return unless $body->areas->{2561} || $body->areas->{2504};
    return 1;
}

sub warn_failure {
    my ($obj, $problem) = @_;
    # Special case a poorly behaving Open311 server
    return 0 if ignore_failure($problem || $obj);
    my $threshold = 1;
    return $obj->send_fail_count && $obj->send_fail_count == $threshold;
}

sub send_service_request {
    my $self = shift;
    my $problem = shift;
    my $extra = shift;
    my $service_code = $extra->{alternative_service_code} || shift;

    my $params = $self->_populate_service_request_params(
        $problem, $extra, $service_code
    );
    my $uploads = $self->_populate_service_request_uploads($problem, $params);

    my $response = $self->_post( $self->endpoints->{requests}, $params, $uploads );

    if ( $response ) {
        my $obj = $self->_get_xml_object( $response );

        if ( $obj ) {
            if ( my $request_id = $obj->{request}->[0]->{service_request_id} ) {
                return $request_id unless ref $request_id;
            } elsif ( my $token = $obj->{request}->[0]->{token} ) {

                my $service_request_id;
                my $polling_interval = FixMyStreet->config('O311_POLLING_INTERVAL') // 2;
                my $polling_max_tries = FixMyStreet->config('O311_POLLING_MAX_TRIES') || 5;

                for (1..$polling_max_tries) {
                    sleep $polling_interval;
                    $service_request_id = $self->get_service_request_id_from_token( $token );
                    last if $service_request_id;
                }
                if ($service_request_id) {
                    return $service_request_id;
                } else {
                    my $timeout_warning = "Timed out while trying to fetch service_request_id for token $token"
                        . " and create remote case for FMS problem ID " . $problem->id;
                    $self->error($self->error . $timeout_warning);
                    warn "$timeout_warning\n" unless FixMyStreet->test_mode;
                    return 0;
                }
            }
        }

        warn sprintf( "Failed to submit problem %s over Open311, response\n: %s\n%s", $problem->id, $response, $self->debug_details )
            if warn_failure($problem);
    } else {
        warn sprintf( "Failed to submit problem %s over Open311, details:\n%s", $problem->id, $self->error)
            if warn_failure($problem);
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

    my ( $firstname, $lastname ) = $self->split_name( $problem->name );

    my $params = {
        description => $description,
        service_code => $service_code,
        first_name => $firstname,
        last_name => $lastname,
    };

    $params->{phone} = $problem->phone_waste if $problem->phone_waste;
    $params->{email} = $problem->user->email if $problem->user->email;

    $params->{account_id} = $extra->{account_id} if defined $extra->{account_id};

    # Some endpoints don't follow the Open311 spec correctly and require an
    # email address for service requests.
    if ($self->always_send_email && !$params->{email}) {
        $params->{email} = FixMyStreet->config('DO_NOT_REPLY_EMAIL');
    }

    # if you click nearby reports > skip map then it's possible
    # to end up with used_map = f and nothing in postcode
    if ( $problem->used_map || $self->always_send_latlong
        || ( !$self->send_notpinpointed && !$problem->used_map
             && !$problem->postcode ) )
    {
        $params->{lat} = Utils::truncate_coordinate($problem->latitude);
        $params->{long} = Utils::truncate_coordinate($problem->longitude);
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

    if ( $extra->{image_url} ) {
        if ( $self->multi_photos ) {
            $params->{media_url} = $extra->{all_image_urls};
        } else {
            $params->{media_url} = $extra->{image_url};
        }
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

sub _populate_service_request_uploads {
    my $self = shift;
    my $problem = shift;
    my $params = shift;

    return unless $self->upload_files;

    my $uploads = {};

    if ( $problem->get_extra_metadata('enquiry_files') ) {
        my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
        my $dir = $cfg ? $cfg->{UPLOAD_DIR} : FixMyStreet->config('UPLOAD_DIR');
        $dir = path($dir, "enquiry_files")->absolute(FixMyStreet->path_to());

        my $files = $problem->get_extra_metadata('enquiry_files') || {};
        for my $key (keys %$files) {
            my $name = $files->{$key};
            $uploads->{"file_$key"} = [ path($dir, $key)->canonpath, encode('UTF-8', $name) ];
        }
    }

    %$uploads = (%$uploads, %{$self->_add_photos_to_upload($problem, $params)});

    return $uploads;
}

sub _add_photos_to_upload {
    my ($self, $obj, $params) = @_;

    my $non_public;
    if (ref $obj eq 'FixMyStreet::DB::Result::Problem') {
        $non_public = $obj->non_public
    } elsif (ref $obj eq 'FixMyStreet::DB::Result::Comment') {
        $non_public = $obj->problem->non_public;
    };

    my $uploads = {};

    if ( $self->always_upload_photos || ( $obj->photo && $non_public ) ) {
        # open311-adapter won't be able to download any photos if they're on
        # a private report or on a comment on a private report, so instead of sending the media_url parameter
        # send the actual photo content with the POST request.
        my $i = 0;
        my $photoset = $obj->get_photoset;
        for ( $photoset->all_ids ) {
            my $photo = $photoset->get_image_data( num => $i++, size => 'full' );
            $uploads->{"photo$i"} = [ undef, $_, Content_Type => $photo->{content_type}, Content => $photo->{data} ];
        }
        delete $params->{media_url};
    }

    if (my $cobrand = $self->fixmystreet_body->get_cobrand_handler || $obj->get_cobrand_logged) {
        $cobrand->call_hook(open311_munge_uploads => $uploads, $obj);
    }

    return $uploads;
}


sub _generate_service_request_description {
    my $self = shift;
    my $problem = shift;
    my $extra = shift;

    my $description = "";
    if ($extra->{easting}) { # Proxy for cobrand being in the UK
        $description .= "detail: " . $problem->detail . "\n\n";
        $description .= "url: " . $extra->{url} . "\n\n";
        $description .= "Submitted via FixMyStreet\n";
        if ($problem->cobrand eq 'brent') {
            $description = "location of problem: " . $problem->title . "\n\n$description";
        } else {
            $description = "title: " . $problem->title . "\n\n$description";
        }
    } elsif ($problem->cobrand eq 'fixamingata') {
        $description .= "Titel: " . $problem->title . "\n\n";
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
    my $args = shift;

    my $params = {};

    if ( $args->{report_ids} ) {
        $params->{service_request_id} = join ',', @{$args->{report_ids}};
        delete $args->{report_ids};
    }

    $params = {
      %$params,
      %$args
    };

    my $service_request_xml = $self->_get( $self->endpoints->{requests}, $params || undef );
    my $requests = $self->_get_xml_object( $service_request_xml );
    return $requests->{request};
}

sub get_service_request_id_from_token {
    my $self = shift;
    my $token = shift;

    my $service_token_xml = $self->_get( "tokens/$token.xml" );

    my $obj = $self->_get_xml_object( $service_token_xml );

    if ( $obj && $obj->{request}->[0]->{service_request_id} ) {
        return $obj->{request}->[0]->{service_request_id};
    } else {
        return 0;
    }
}

sub get_service_request_updates {
    my $self = shift;
    my $start_date = shift;
    my $end_date = shift;

    my $params = {
        api_key => $self->api_key || '',
    };

    if ( $start_date || $end_date ) {
        return 0 unless $start_date && $end_date;

        $params->{start_date} = $start_date;
        $params->{end_date} = $end_date;
    }

    my $xml = $self->_get( $self->endpoints->{service_request_updates}, $params || undef );
    my $service_requests = $self->_get_xml_object( $xml );
    return $service_requests->{request_update};
}

sub post_service_request_update {
    my $self = shift;
    my $comment = shift;

    my $params = $self->_populate_service_request_update_params( $comment );

    my $response;
    if ($self->upload_files_for_updates && $comment->photo) {
        my $uploads = $self->_add_photos_to_upload($comment, $params);
        $response = $self->_post( $self->endpoints->{update}, $params, $uploads);
    } else {
        $response = $self->_post( $self->endpoints->{update}, $params);
    }

    if ( $response ) {
        my $obj = $self->_get_xml_object( $response );

        if ( $obj ) {
            if ( my $update_id = $obj->{request_update}->[0]->{update_id} ) {
                return $update_id unless ref $update_id;
            } else {
                if ( my $token = $obj->{request_update}->[0]->{token} ) {
                    return $self->get_service_request_id_from_token( $token );
                }
            }
        }

        warn sprintf( "Failed to submit comment %s over Open311, response - %s\n%s\n", $comment->id, $response, $self->debug_details )
            if warn_failure($comment, $comment->problem);
    } else {
        warn sprintf( "Failed to submit comment %s over Open311, details\n%s\n", $comment->id, $self->error)
            if warn_failure($comment, $comment->problem);
    }
    return 0;
}

sub add_media {
    my ($self, $url, $object) = @_;

    $url = [ $url ] unless ref $url;

    my @photos;
    foreach (@$url) {
        if ($_ =~ /^data:/) {
            my @parts = split ',', $_, 2;
            push @photos, $parts[1];
        } else {
            my $ua = LWP::UserAgent->new;
            my $res = $ua->get($_);
            if ( $res->is_success && $res->content_type =~ m{image/(jpeg|pjpeg|gif|tiff|png)} ) {
                push @photos, $res->decoded_content;
            }
        }
    }
    if (@photos) {
        my $photoset = FixMyStreet::App::Model::PhotoSet->new({
            data_items => \@photos,
        });
        $object->photo($photoset->data);
    }
}

sub map_state {
    my $self           = shift;
    my $incoming_state = shift;

    $incoming_state = lc($incoming_state);
    $incoming_state =~ s/_/ /g;

    my %state_map = (
        fixed                         => 'fixed - council',
        'not councils responsibility' => 'not responsible',
        'no further action'           => 'unable to fix',
        open                          => 'confirmed',
        closed                        => $self->extended_statuses ? 'closed' : 'fixed - council',
    );

    return $state_map{$incoming_state} || $incoming_state;
}

sub _populate_service_request_update_params {
    my $self = shift;
    my $comment = shift;

    my $name = $comment->name || $comment->user->name;
    my ( $firstname, $lastname ) = $self->split_name( $name );
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
        } elsif ( $state eq 'for triage' ) {
            $status = 'FOR_TRIAGE';
        } elsif ( $state eq 'closed' ) {
            $status = 'CLOSED';
        } elsif ( $state eq 'cancelled' ) {
            $status = 'CANCELLED';
        } elsif ($comment->mark_open && $self->mark_reopen) {
            $status = 'REOPEN';
        }
    } else {
        if ( !FixMyStreet::DB::Result::Problem->open_states()->{$state} ) {
            $status = 'CLOSED';
        }
    }

    my $service_request_id = $comment->problem->external_id;
    if ( $self->use_customer_reference ) {
        my $customer_ref = $comment->problem->get_extra_metadata('customer_reference');
        $service_request_id = $customer_ref || $service_request_id;
    }
    my $params = {
        updated_datetime => DateTime::Format::W3CDTF->format_datetime($comment->confirmed->set_nanosecond(0)),
        service_request_id => $service_request_id,
        status => $status,
        description => $comment->text,
        last_name => $lastname,
        first_name => $firstname,
    };

    $params->{phone} = $comment->user->phone if $comment->user->phone;
    $params->{email} = $comment->user->email if $comment->user->email;
    $params->{update_id} = $comment->id;

    my $cobrand = $self->fixmystreet_body->get_cobrand_handler || $comment->get_cobrand_logged;
    $cobrand->call_hook(open311_munge_update_params => $params, $comment, $self->fixmystreet_body);
    $params->{service_code} = $self->service_code if $self->service_code;

    if ( $comment->photo ) {
        my $cobrand = $comment->get_cobrand_logged;
        my $email_base_url = $cobrand->base_url($comment->cobrand_data);
        if ($self->multi_photos) {
            my @all_images = map { $email_base_url . $_->{url_full} } @{ $comment->photos };
            $params->{media_url} = \@all_images;
        } else {
            my $url = $email_base_url . $comment->photos->[0]->{url_full};
            $params->{media_url} = $url;
        }
    }

    # The following will only set by UK in Bromley/Bromley cobrands
    if ( $comment->extra && $comment->extra->{title} && ( $comment->problem->cobrand_data || '' ) ne 'waste' ) {
        $params->{'email_alerts_requested'}
            = $comment->extra->{email_alerts_requested} ? 'TRUE' : 'FALSE';
        $params->{'title'} = $comment->extra->{title};

        $params->{first_name} = $comment->extra->{first_name} if $comment->extra->{first_name};
        $params->{last_name} = $comment->extra->{last_name} if $comment->extra->{last_name};
    }

    my $extra = $comment->get_extra_metadata;
    foreach (grep { /^fms_extra_/ } keys %$extra) {
        my $attr_name = $_;
        $attr_name =~ s/fms_extra_//;
        my $name = sprintf( 'attribute[%s]', $attr_name );
        $params->{ $name } = $extra->{$_};
    }

    return $params;
}

sub split_name {
    my ( $self, $name ) = @_;

    return ('', '') unless $name;

    my ( $first, $last ) = ( $name =~ /(\S+)(?:\.?\s+(.+))?/ );

    return ( $first || '', $last || '');
}

sub _params_to_string {
    my( $self, $params, $request_string ) = @_;

    my $undefined;

    my $string = join("\n", map {
        $undefined .= "$_ undefined\n" unless defined $params->{$_};
        "$_: " . ( $params->{$_} // '' );
    } keys %$params);

    warn "$request_string $undefined $string" if $undefined;

    return $string;
}

sub _request {
    my $self = shift;
    my $method = shift;
    my $path = shift;
    my $params = shift || {};
    my $uploads = shift;
    my $uri = URI->new( $self->endpoint );
    $uri->path( $uri->path . $path );

    $params->{jurisdiction_id} = $self->jurisdiction
        if $self->jurisdiction;
    $params->{api_key} = ($self->api_key || '')
        if $method eq 'POST' && $self->api_key;

    my $debug_request = $method . ' ' . $uri->as_string . "\n\n";

    my $req = do {
        $params = {
            map {
                my $value = $params->{$_};
                $_ => ref $value eq 'ARRAY'
                        ? [ map { encode('UTF-8', $_) } @$value ]
                        : encode('UTF-8', $value)
            } keys %$params
        };
        if ($method eq 'GET') {
            $uri->query_form( $params );
            GET $uri->as_string;
        } elsif ($method eq 'POST') {
            if ($uploads && %$uploads) {
                # HTTP::Request::Common needs to be constructed slightly
                # differently if there are files to upload.

                # HTTP::Request::Common treats an arrayref as a filespec,
                # so we need to flatten these into repeated field names with different
                # values so it doesn't get confused...
                # https://stackoverflow.com/questions/50705344/perl-httprequestcommon-post-file-and-array
                my @flattened_params;
                while (my ($key, $value) = each %$params) {
                    if (ref $value eq 'ARRAY') {
                        foreach my $element (@$value) {
                            push @flattened_params, ( $key => $element );
                        }
                        delete $params->{$key};
                    }
                }

                $params = {
                    Content_Type => 'form-data',
                    Content => [
                        %$params,
                        @flattened_params,
                        %$uploads
                    ]
                };
                POST $uri->as_string, %$params;
            } else {
                POST $uri->as_string, $params;
            }
        }
    };

    $debug_request .= $self->_params_to_string($params, $debug_request);
    $self->debug_details( $self->debug_details . $debug_request );

    my $res = $self->_make_request($req);

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
        return;
    }
}

sub _make_request {
    my ($self, $req) = @_;
    my $ua = LWP::UserAgent->new( timeout => 300 );
    my $res = $ua->request( $req );
    return $res;
}

sub _get {
    my $self = shift;
    return $self->_request(GET => @_);
}

sub _post {
    my $self = shift;
    return $self->_request(POST => @_);
}

sub _process_error {
    my $self = shift;
    my $error = shift;

    my $obj = $self->_get_xml_object( $error );

    my $msg = '';
    if ( ref $obj && exists $obj->{error} ) {
        for (@{ $obj->{error} }) {
            my $code = $_->{code} || '???';
            my $desc = $_->{description} || 'unknown error';
            $msg .= sprintf("%s: %s\n", $code, $desc);
        }
    }

    return $msg || 'unknown error';
}

sub _get_xml_object {
    my ($self, $xml) = @_;

    # Of these, services/service_requests/service_request_updates are root
    # elements, so GroupTags has no effect, but this is used in ForceArray too.
    my $group_tags = {
        services => 'service',
        attributes => 'attribute',
        values => 'value',
        service_requests => 'request',
        errors => 'error',
        service_request_updates => 'request_update',
        groups => 'group',
    };
    my $simple = XML::Simple->new(
        ForceArray => [ values %$group_tags ],
        KeyAttr => {},
        GroupTags => $group_tags,
        SuppressEmpty => undef,
    );
    my $obj = eval {
        $simple->parse_string($xml);
    };
    return $obj;
}

1;
