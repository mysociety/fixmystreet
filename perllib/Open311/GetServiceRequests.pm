package Open311::GetServiceRequests;

use Moo;
use Open311;
use FixMyStreet::DB;
use FixMyStreet::MapIt;
use FixMyStreet::App::Model::PhotoSet;
use DateTime::Format::W3CDTF;

has system_user => ( is => 'rw' );
has start_date => ( is => 'ro', default => sub { undef } );
has end_date => ( is => 'ro', default => sub { undef } );
has fetch_all => ( is => 'rw', default => 0 );
has verbose => ( is => 'ro', default => 0 );
has schema => ( is =>'ro', lazy => 1, default => sub { FixMyStreet::DB->schema->connect } );
has convert_latlong => ( is => 'rw', default => 0 );

sub fetch {
    my $self = shift;

    my $bodies = $self->schema->resultset('Body')->search(
        {
            send_method     => 'Open311',
            fetch_problems  => 1,
            comment_user_id => { '!=', undef },
            endpoint        => { '!=', '' },
        }
    );

    while ( my $body = $bodies->next ) {
        my $o = $self->create_open311_object( $body );

        $self->system_user( $body->comment_user );
        $self->convert_latlong( $body->convert_latlong );
        $self->fetch_all( $body->get_extra_metadata('fetch_all_problems') );
        $self->create_problems( $o, $body );
    }
}

# this is so we can test
sub create_open311_object {
    my ($self, $body) = @_;

    my $o = Open311->new(
        endpoint     => $body->endpoint,
        api_key      => $body->api_key,
        jurisdiction => $body->jurisdiction,
    );

    return $o;
}

sub create_problems {
    my ( $self, $open311, $body ) = @_;

    my $args = {};

    if ( $self->start_date || $self->end_date ) {
        return 0 unless $self->start_date && $self->end_date;

        $args->{start_date} = DateTime::Format::W3CDTF->format_datetime( $self->start_date );
        $args->{end_date} = DateTime::Format::W3CDTF->format_datetime( $self->end_date );
    } elsif ( !$self->fetch_all ) {
        my $end_dt = DateTime->now();
        my $start_dt = $end_dt->clone;
        $start_dt->add( hours => -1 );

        $args->{start_date} = DateTime::Format::W3CDTF->format_datetime( $start_dt );
        $args->{end_date} = DateTime::Format::W3CDTF->format_datetime( $end_dt );
    }

    my $requests = $open311->get_service_requests( $args );

    unless ( $open311->success ) {
        warn "Failed to fetch ServiceRequest Updates for " . $body->name . ":\n" . $open311->error
            if $self->verbose;
        return 0;
    }

    my $contacts = $self->schema->resultset('Contact')
        ->active
        ->search( { body_id => $body->id } );

    for my $request (@{$requests->{request}}) {
        # no point importing if we can't put it on the map
        unless ($request->{service_request_id} && $request->{lat} && $request->{long}) {
            warn "Not creating request '$request->{description}' for @{[$body->name]} as missing one of id, lat or long"
                if $self->verbose;
            next;
        }
        my $request_id = $request->{service_request_id};

        my ($latitude, $longitude) = ( $request->{lat}, $request->{long} );

        ($latitude, $longitude) = Utils::convert_en_to_latlon_truncated( $longitude, $latitude )
            if $self->convert_latlong;

        my $all_areas =
          FixMyStreet::MapIt::call('point', "4326/$longitude,$latitude");

        # skip if it doesn't look like it's for this body
        my @areas = grep { $all_areas->{$_->area_id} } $body->body_areas;
        unless (@areas) {
            warn "Not creating request id $request_id for @{[$body->name]} as outside body area"
                if $self->verbose;
            next;
        }

        my $updated_time = eval {
            DateTime::Format::W3CDTF->parse_datetime(
                $request->{updated_datetime} || ""
            )->set_time_zone(FixMyStreet->local_time_zone);
        };
        if ($@) {
            warn "Not creating problem $request_id for @{[$body->name]}, bad update time"
                if $self->verbose;
            next;
        }
        my $updated = DateTime::Format::W3CDTF->format_datetime(
            $updated_time->clone->set_time_zone('UTC')
        );

        my $created_time = eval {
            DateTime::Format::W3CDTF->parse_datetime(
                $request->{requested_datetime} || ""
            )->set_time_zone(FixMyStreet->local_time_zone);
        };
        $created_time = $updated_time if $@;

        # Updated time must not be before created time, check and adjust as necessary.
        # (This has happened with some fetched reports, oddly.)
        $updated_time = $created_time if $updated_time lt $created_time;

        my $problems;
        my $criteria = {
            external_id => $request_id,
        };

        # Skip if this problem already exists (e.g. it may have originated from FMS and is being mirrored back!)
        next if $self->schema->resultset('Problem')->to_body($body)->search( $criteria )->count;

        if ($args->{start_date} && $args->{end_date} && ($updated lt $args->{start_date} || $updated gt $args->{end_date}) ) {
            warn "Problem id $request_id for @{[$body->name]} has an invalid time, not creating: "
                . "$updated either less than $args->{start_date} or greater than $args->{end_date}"
                if $self->verbose;
            next;
        }

        if ( my $cobrand = $body->get_cobrand_handler ) {
            my $filtered = $cobrand->call_hook('filter_report_description', $request->{description});
            $request->{description} = $filtered if defined $filtered;
        }

        my @contacts = grep { $request->{service_code} eq $_->email } $contacts->all;
        my $contact = $contacts[0] ? $contacts[0]->category : 'Other';

        my $state = $open311->map_state($request->{status});

        my $non_public = $request->{non_public} ? 1 : 0;

        my $problem = $self->schema->resultset('Problem')->new(
            {
                user => $self->system_user,
                external_id => $request_id,
                detail => $request->{description} || $request->{service_name} . ' problem',
                title => $request->{title} || $request->{service_name} . ' problem',
                anonymous => 0,
                name => $self->system_user->name,
                confirmed => $created_time,
                created => $created_time,
                lastupdate => $updated_time,
                whensent => $created_time,
                state => $state,
                postcode => '',
                used_map => 1,
                latitude => $latitude,
                longitude => $longitude,
                areas => ',' . $body->id . ',',
                bodies_str => $body->id,
                send_method_used => 'Open311',
                category => $contact,
                send_questionnaire => 0,
                non_public => $non_public,
            }
        );

        $open311->add_media($request->{media_url}, $problem)
            if $request->{media_url};

        $problem->insert();
    }

    return 1;
}

1;
