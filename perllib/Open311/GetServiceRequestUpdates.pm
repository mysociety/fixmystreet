package Open311::GetServiceRequestUpdates;

use Moo;
use Open311;
use FixMyStreet::DB;
use FixMyStreet::App::Model::PhotoSet;
use DateTime::Format::W3CDTF;

has system_user => ( is => 'rw' );
has start_date => ( is => 'ro', default => sub { undef } );
has end_date => ( is => 'ro', default => sub { undef } );
has suppress_alerts => ( is => 'rw', default => 0 );
has verbose => ( is => 'ro', default => 0 );
has schema => ( is =>'ro', lazy => 1, default => sub { FixMyStreet::DB->schema->connect } );

Readonly::Scalar my $AREA_ID_BROMLEY     => 2482;
Readonly::Scalar my $AREA_ID_OXFORDSHIRE => 2237;

sub fetch {
    my $self = shift;

    my $bodies = $self->schema->resultset('Body')->search(
        {
            send_method     => 'Open311',
            send_comments   => 1,
            comment_user_id => { '!=', undef },
            endpoint        => { '!=', '' },
        }
    );

    while ( my $body = $bodies->next ) {

        my $o = Open311->new(
            endpoint     => $body->endpoint,
            api_key      => $body->api_key,
            jurisdiction => $body->jurisdiction,
        );

        # custom endpoint URLs because these councils have non-standard paths
        if ( $body->areas->{$AREA_ID_BROMLEY} ) {
            my $endpoints = $o->endpoints;
            $endpoints->{update} = 'update.xml';
            $endpoints->{service_request_updates} = 'update.xml';
            $o->endpoints( $endpoints );
        } elsif ( $body->areas->{$AREA_ID_OXFORDSHIRE} ) {
            my $endpoints = $o->endpoints;
            $endpoints->{service_request_updates} = 'open311_service_request_update.cgi';
            $o->endpoints( $endpoints );
        }

        $self->suppress_alerts( $body->suppress_alerts );
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
        next unless $request_id;

        my $comment_time = eval {
            DateTime::Format::W3CDTF->parse_datetime( $request->{updated_datetime} || "" );
        };
        next if $@;
        my $updated = DateTime::Format::W3CDTF->format_datetime($comment_time->clone->set_time_zone('UTC'));
        next if @args && ($updated lt $args[0] || $updated gt $args[1]);

        my $problem;
        my $criteria = {
            external_id => $request_id,
        };
        $problem = $self->schema->resultset('Problem')->to_body($body)->search( $criteria );

        if (my $p = $problem->first) {
            next unless defined $request->{update_id};
            my $c = $p->comments->search( { external_id => $request->{update_id} } );

            if ( !$c->first ) {
                my $state = $self->map_state( $request->{status} );
                my $comment = $self->schema->resultset('Comment')->new(
                    {
                        problem => $p,
                        user => $self->system_user,
                        external_id => $request->{update_id},
                        text => $self->comment_text_for_request($request, $p, $state),
                        mark_fixed => 0,
                        mark_open => 0,
                        anonymous => 0,
                        name => $self->system_user->name,
                        confirmed => $comment_time,
                        created => $comment_time,
                        state => 'confirmed',
                    }
                );

                if ($request->{media_url}) {
                    my $ua = LWP::UserAgent->new;
                    my $res = $ua->get($request->{media_url});
                    if ( $res->is_success && $res->content_type eq 'image/jpeg' ) {
                        my $photoset = FixMyStreet::App::Model::PhotoSet->new({
                            data_items => [ $res->decoded_content ],
                        });
                        $comment->photo($photoset->data);
                    }
                }

                # if the comment is older than the last update
                # do not change the status of the problem as it's
                # tricky to determine the right thing to do.
                if ( $comment->created > $p->lastupdate ) {
                    # don't update state unless it's an allowed state and it's
                    # actually changing the state of the problem
                    if ( FixMyStreet::DB::Result::Problem->visible_states()->{$state} && $p->state ne $state &&
                        # For Oxfordshire, don't allow changes back to Open from other open states
                        !( $body->areas->{$AREA_ID_OXFORDSHIRE} && $state eq 'confirmed' && $p->is_open ) &&
                        # Don't let it change between the (same in the front end) fixed states
                        !( $p->is_fixed && FixMyStreet::DB::Result::Problem->fixed_states()->{$state} ) ) {
                        if ($p->is_visible) {
                            $p->state($state);
                        }
                        $comment->problem_state($state);
                    }
                }

                $p->lastupdate( $comment->created );
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
        }
    }

    return 1;
}

sub comment_text_for_request {
    my ($self, $request, $problem, $state) = @_;

    return $request->{description} if $request->{description};

    if (my $template = $problem->response_templates->search({
        auto_response => 1,
        'me.state' => $state
    })->first) {
        return $template->text;
    }

    print STDERR "Couldn't determine update text for $request->{update_id} (report " . $problem->id . ")\n";
    return "";
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
        closed                        => 'fixed - council'
    );

    return $state_map{$incoming_state} || $incoming_state;
}

1;
