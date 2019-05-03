package Open311::GetServiceRequestUpdates;

use Moo;
use Open311;
use FixMyStreet::DB;
use FixMyStreet::App::Model::PhotoSet;
use DateTime::Format::W3CDTF;

has system_user => ( is => 'rw' );
has start_date => ( is => 'ro', default => sub { undef } );
has end_date => ( is => 'ro', default => sub { undef } );
has body => ( is => 'ro', default => sub { undef } );
has suppress_alerts => ( is => 'rw', default => 0 );
has verbose => ( is => 'ro', default => 0 );
has schema => ( is =>'ro', lazy => 1, default => sub { FixMyStreet::DB->schema->connect } );
has blank_updates_permitted => ( is => 'rw', default => 0 );

Readonly::Scalar my $AREA_ID_BROMLEY     => 2482;
Readonly::Scalar my $AREA_ID_OXFORDSHIRE => 2237;

sub fetch {
    my ($self, $open311) = @_;

    my $bodies = $self->schema->resultset('Body')->search(
        {
            send_method     => 'Open311',
            send_comments   => 1,
            comment_user_id => { '!=', undef },
            endpoint        => { '!=', '' },
        }
    );

    if ( $self->body ) {
        $bodies = $bodies->search( { name => $self->body } );
    }

    while ( my $body = $bodies->next ) {

        my %open311_conf = (
            endpoint => $body->endpoint,
            api_key => $body->api_key,
            jurisdiction => $body->jurisdiction,
            extended_statuses => $body->send_extended_statuses,
        );

        my $cobrand = $body->get_cobrand_handler;
        $cobrand->call_hook(open311_config_updates => \%open311_conf)
            if $cobrand;

        my $o = $open311 || Open311->new(%open311_conf);

        $self->suppress_alerts( $body->suppress_alerts );
        $self->blank_updates_permitted( $body->blank_updates_permitted );
        $self->system_user( $body->comment_user );
        $self->update_comments( $o, $body );
    }
}

sub update_comments {
    my ( $self, $open311, $body ) = @_;

    my @args = ();

    if ( $self->start_date || $self->end_date ) {
        return 0 unless $self->start_date && $self->end_date;

        push @args, $self->start_date;
        push @args, $self->end_date;
    # default to asking for last 2 hours worth if not Bromley
    } elsif ( ! $body->areas->{$AREA_ID_BROMLEY} ) {
        my $end_dt = DateTime->now();
        # Oxfordshire uses local time and not UTC for dates
        FixMyStreet->set_time_zone($end_dt) if ( $body->areas->{$AREA_ID_OXFORDSHIRE} );
        my $start_dt = $end_dt->clone;
        $start_dt->add( hours => -2 );

        push @args, DateTime::Format::W3CDTF->format_datetime( $start_dt );
        push @args, DateTime::Format::W3CDTF->format_datetime( $end_dt );
    }

    my $requests = $open311->get_service_request_updates( @args );

    unless ( $open311->success ) {
        warn "Failed to fetch ServiceRequest Updates for " . $body->name . ":\n" . $open311->error
            if $self->verbose;
        return 0;
    }

    for my $request (@$requests) {
        my $request_id = $request->{service_request_id};

        # If there's no request id then we can't work out
        # what problem it belongs to so just skip
        next unless $request_id || $request->{fixmystreet_id};

        my $comment_time = eval {
            DateTime::Format::W3CDTF->parse_datetime( $request->{updated_datetime} || "" )
                ->set_time_zone(FixMyStreet->local_time_zone);
        };
        next if $@;
        my $updated = DateTime::Format::W3CDTF->format_datetime($comment_time->clone->set_time_zone('UTC'));
        next if @args && ($updated lt $args[0] || $updated gt $args[1]);

        my $problem;
        my $match_field = 'external_id';
        my $criteria = {
            external_id => $request_id,
        };

        # in some cases we only have the FMS id and not the request id so use that
        if ( $request->{fixmystreet_id} ) {
            unless ( $request->{fixmystreet_id} =~ /^\d+$/ ) {
                warn "skipping bad fixmystreet id in updates for " . $body->name . ": [" . $request->{fixmystreet_id} . "], external id is $request_id\n";
                next;
            }

            $criteria = {
                id => $request->{fixmystreet_id},
            };
            $match_field = 'fixmystreet id';
        }

        $problem = $self->schema->resultset('Problem')->to_body($body)->search( $criteria );

        if (my $p = $problem->first) {
            next unless defined $request->{update_id};
            my $c = $p->comments->search( { external_id => $request->{update_id} } );

            if ( !$c->first ) {
                my $state = $open311->map_state( $request->{status} );
                my $old_state = $p->state;
                my $external_status_code = $request->{external_status_code} || '';
                my $customer_reference = $request->{customer_reference} || '';
                my $old_external_status_code = $p->get_extra_metadata('external_status_code') || '';
                my $comment = $self->schema->resultset('Comment')->new(
                    {
                        problem => $p,
                        user => $self->system_user,
                        external_id => $request->{update_id},
                        text => $self->comment_text_for_request(
                            $request, $p, $state, $old_state,
                            $external_status_code, $old_external_status_code
                        ),
                        mark_fixed => 0,
                        mark_open => 0,
                        anonymous => 0,
                        name => $self->system_user->name,
                        confirmed => $comment_time,
                        created => $comment_time,
                        state => 'confirmed',
                    }
                );

                # Some Open311 services, e.g. Confirm via open311-adapter, provide
                # a more fine-grained status code that we use within FMS for
                # response templates.
                if ( $external_status_code ) {
                    $comment->set_extra_metadata(external_status_code => $external_status_code);
                    $p->set_extra_metadata(external_status_code => $external_status_code);
                }

                # if the customer reference to display in the report metadata is
                # not the same as the external_id
                if ( $customer_reference ) {
                    $p->set_extra_metadata( customer_reference => $customer_reference );
                }

                $open311->add_media($request->{media_url}, $comment)
                    if $request->{media_url};

                # don't update state unless it's an allowed state
                if ( FixMyStreet::DB::Result::Problem->visible_states()->{$state} &&
                    # For Oxfordshire, don't allow changes back to Open from other open states
                    !( $body->areas->{$AREA_ID_OXFORDSHIRE} && $state eq 'confirmed' && $p->is_open ) &&
                    # Don't let it change between the (same in the front end) fixed states
                    !( $p->is_fixed && FixMyStreet::DB::Result::Problem->fixed_states()->{$state} ) ) {

                    $comment->problem_state($state);

                    # if the comment is older than the last update do not
                    # change the status of the problem as it's tricky to
                    # determine the right thing to do. Allow the same time in
                    # case report/update created at same time (in external
                    # system). Only do this if the report is currently visible.
                    if ( $comment->created >= $p->lastupdate && $p->state ne $state && $p->is_visible ) {
                        $p->state($state);
                    }
                }

                # If nothing to show (no text, photo, or state change), don't show this update
                $comment->state('hidden') unless $comment->text || $comment->photo
                    || ($comment->problem_state && $state ne $old_state);

                # As comment->created has been looked at above, its time zone has been shifted
                # to TIME_ZONE (if set). We therefore need to set it back to local before
                # insertion. We also then need a clone, otherwise the setting of lastupdate
                # will *also* reshift comment->created's time zone to TIME_ZONE.
                my $created = $comment->created->set_time_zone(FixMyStreet->local_time_zone);
                $p->lastupdate($created->clone);
                $p->update;
                $comment->insert();

                if ( $self->suppress_alerts ) {
                    my @alerts = $self->schema->resultset('Alert')->search( {
                        alert_type => 'new_updates',
                        parameter  => $p->id,
                        confirmed  => 1,
                        user_id    => $p->user->id,
                    } );

                    for my $alert (@alerts) {
                        my $alerts_sent = $self->schema->resultset('AlertSent')->find_or_create( {
                            alert_id  => $alert->id,
                            parameter => $comment->id,
                        } );
                    }
                }
            }
        # we get lots of comments that are not related to FMS issues from Lewisham so ignore those otherwise
        # way too many warnings.
        } elsif (FixMyStreet->config('STAGING_SITE') and $body->name !~ /Lewisham/) {
            warn "Failed to match comment to problem with $match_field $request_id for " . $body->name . "\n";
        }
    }

    return 1;
}

sub comment_text_for_request {
    my ($self, $request, $problem, $state, $old_state,
        $ext_code, $old_ext_code) = @_;

    return $request->{description} if $request->{description};

    # Response templates are only triggered if the state/external status has changed.
    # And treat any fixed state as fixed.
    my $state_changed = $state ne $old_state
        && !( $problem->is_fixed && FixMyStreet::DB::Result::Problem->fixed_states()->{$state} );
    my $ext_code_changed = $ext_code ne $old_ext_code;
    if ($state_changed || $ext_code_changed) {
        my $state_params = {
            'me.state' => $state
        };
        if ($ext_code) {
            $state_params->{'me.external_status_code'} = $ext_code;
        };

        if (my $template = $problem->response_templates->search({
            auto_response => 1,
            -or => $state_params,
        })->first) {
            return $template->text;
        }
    }

    return "" if $self->blank_updates_permitted;

    print STDERR "Couldn't determine update text for $request->{update_id} (report " . $problem->id . ")\n";
    return "";
}

1;
