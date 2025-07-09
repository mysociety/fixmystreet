package Open311::GetServiceRequests;

use Moo;
use Open311;
use FixMyStreet::DB;
use FixMyStreet::MapIt;
use FixMyStreet::Map;
use DateTime::Format::W3CDTF;

has system_user => ( is => 'rw' );
has start_date => ( is => 'ro', default => sub { undef } );
has end_date => ( is => 'ro', default => sub { undef } );
has bodies => ( is => 'ro', default => sub { [] } );
has bodies_exclude => ( is => 'ro', default => sub { [] } );
has fetch_all => ( is => 'rw', default => 0 );
has verbose => ( is => 'ro', default => 0 );
has commit => ( is => 'ro', default => 1 );
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

    if ( @{$self->bodies} ) {
        $bodies = $bodies->search( { name => $self->bodies } );
    }
    if ( @{$self->bodies_exclude} ) {
        $bodies = $bodies->search( { name => { -not_in => $self->bodies_exclude } } );
    }

    while ( my $body = $bodies->next ) {
        my $o = $self->create_open311_object( $body );

        $self->system_user( $body->comment_user );
        $self->convert_latlong( $body->convert_latlong );
        $self->fetch_all( $body->get_extra_metadata('fetch_all_problems') );
        my $args = $self->format_args;
        my $requests = $self->get_requests($o, $body, $args);
        $self->create_problems( $o, $body, $args, $requests );
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

sub format_args {
    my $self = shift;

    my $args = {};

    my $dt = DateTime->now();
    if ($self->start_date) {
        $args->{start_date} = DateTime::Format::W3CDTF->format_datetime( $self->start_date );
    } elsif ( !$self->fetch_all ) {
        $args->{start_date} = DateTime::Format::W3CDTF->format_datetime( $dt->clone->add(hours => -1) );
    }

    if ($self->end_date) {
        $args->{end_date} = DateTime::Format::W3CDTF->format_datetime( $self->end_date );
    } elsif ( !$self->fetch_all ) {
        $args->{end_date} = DateTime::Format::W3CDTF->format_datetime( $dt );
    }

    return $args;
}

sub get_requests {
    my ( $self, $open311, $body, $args ) = @_;

    my $requests = $open311->get_service_requests( $args );

    unless ( $open311->success ) {
        warn "Failed to fetch ServiceRequests for " . $body->name . ":\n" . $open311->error
            if $self->verbose;
        return;
    }

    return $requests;
}

sub create_problems {
    my ( $self, $open311, $body, $args, $requests ) = @_;

    return unless $requests;

    my $contacts = $self->schema->resultset('Contact')
        ->not_deleted_admin
        ->search( { body_id => $body->id } );

    for my $request (@$requests) {
        # no point importing if we can't put it on the map
        unless ($request->{service_request_id} && $request->{lat} && $request->{long}) {
            warn "Not creating request '$request->{description}' for @{[$body->name]} as missing one of id, lat or long"
                if $self->verbose;
            next;
        }
        my $request_id = $request->{service_request_id};
        my $is_confirm_job = $request_id =~ /^JOB_/;

        my ($latitude, $longitude) = ( $request->{lat}, $request->{long} );

        # Body may have convert_latlong set to true if it gets *enquiries* from
        # Confirm (these use easting/northing), but *jobs* from Confirm use
        # lat & long, so conversion is not needed for them
        ( $latitude, $longitude )
            = Utils::convert_en_to_latlon_truncated( $longitude, $latitude )
            if $self->convert_latlong
            && !$is_confirm_job;

        my $all_areas =
          FixMyStreet::MapIt::call('point', "4326/$longitude,$latitude");

        # skip if it doesn't look like it's for this body
        my @areas = grep { $all_areas->{$_->area_id} } $body->body_areas;
        unless (@areas) {
            warn "Not creating request id $request_id for @{[$body->name]} as outside body area"
                if $self->verbose >= 2;
            next;
        }

        my $updated_time = eval {
            DateTime::Format::W3CDTF->parse_datetime(
                $request->{updated_datetime} || ""
            )->set_time_zone(FixMyStreet->local_time_zone);
        };
        if ($@) {
            warn "Not creating problem $request_id for @{[$body->name]}, bad update time"
                if $self->verbose >= 2;
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

        # Skip this date check for Confirm jobs, otherwise we are likely to
        # skip a bunch of valid jobs if calling the fetch script using
        # explicit start and end values
        if (   !$is_confirm_job
            && $args->{start_date}
            && $args->{end_date}
            && (   $updated lt $args->{start_date}
                || $updated gt $args->{end_date} )
            )
        {
            warn
                "Problem id $request_id for @{[$body->name]} has an invalid time, not creating: "
                . "$updated either less than $args->{start_date} or greater than $args->{end_date}"
                if $self->verbose >= 2;
            next;
        }

        my $cobrand = $body->get_cobrand_handler;
        if ( $cobrand ) {
            my $filtered = $cobrand->call_hook('filter_report_description', $request->{description});
            $request->{description} = $filtered if defined $filtered;
        }

        my @contacts = grep { $request->{service_code} eq $_->email } $contacts->all;
        my $contact = $contacts[0] ? $contacts[0]->category : 'Other';

        my $state = $open311->map_state($request->{status});

        my $non_public = $request->{non_public} ? 1 : 0;
        $non_public ||= $contacts[0] ? $contacts[0]->non_public : 0;

        my $title = $request->{title} || $cobrand && $cobrand->call_hook('open311_title_fetched_report', $request) || $request->{service_name} . ' problem';
        my $detail = $request->{description} || $title;

        my $areas = ',' . join( ',', sort keys %$all_areas ) . ',';
        my $params = {
            user => $self->system_user,
            external_id => $request_id,
            detail => $detail,
            title => $title,
            anonymous => 0,
            name => $self->system_user->name,
            confirmed => $created_time,
            created => $created_time,
            lastupdate => $updated_time,
            whensent => $created_time,
            send_state => 'processed',
            state => $state,
            postcode => '',
            used_map => 1,
            latitude => $latitude,
            longitude => $longitude,
            areas => $areas,
            bodies_str => $body->id,
            send_method_used => 'Open311',
            category => $contact,
            send_questionnaire => 0,
            service => 'Open311',
            non_public => $non_public,
        };

        # Figure out which user to associate with this report.
        my $user_from_cobrand = $cobrand && $cobrand->call_hook('open311_get_user', $request);
        if ($user_from_cobrand) {
            $params->{user} = $user_from_cobrand;
            $params->{name} = $user_from_cobrand->name;
            $params->{anonymous} = 1;
        }

        my $problem = $self->schema->resultset('Problem')->new($params);

        next if $cobrand && $cobrand->call_hook(open311_skip_report_fetch => $problem);

        next unless $self->commit;

        $open311->add_media($request->{media_url}, $problem)
            if $request->{media_url};

        $problem->insert();

        $problem->discard_changes;

        if ($user_from_cobrand) {
            $cobrand->set_lang_and_domain($problem->lang, 1);
            FixMyStreet::Map::set_map_class($cobrand);

            # Send confirmation email to user
            $problem->send_logged_email({
                report => $problem,
                cobrand => $cobrand,
            }, 0, $cobrand);

            # Sign the user up for alerts on the problem
            $self->schema->resultset('Alert')->create({
                alert_type => 'new_updates',
                parameter => $problem->id,
                user => $problem->user,
                cobrand => $cobrand->moniker,
                whensubscribed => $created_time,
            })->confirm;
        }
    }

    return 1;
}

1;
