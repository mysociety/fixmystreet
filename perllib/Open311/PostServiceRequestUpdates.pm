package Open311::PostServiceRequestUpdates;

use Moose;
use FixMyStreet::App;
use Open311;

has open311 => ( is => 'rw' );
has body => ( is => 'rw' );
has verbose => ( is => 'ro', default => 0 );

# ? send_method config values found in by-area config data, for selecting to appropriate method
Readonly::Scalar my $SEND_METHOD_OPEN311 => 'Open311';

Readonly::Scalar my $AREA_ID_BROMLEY     => 2482;
Readonly::Scalar my $AREA_ID_OXFORDSHIRE => 2237;

sub send {
    my $self = shift;

    my $bodies = FixMyStreet::App->model('DB::Body')->search( {
        send_method => $SEND_METHOD_OPEN311,
        send_comments => 1,
    } );

    while ( my $body = $bodies->next ) {
        # Oxfordshire (OCC) is special:
        # we do *receive* service_request_updates (aka comments) for OCC, but we never *send* them, so skip this pass
        next if $body->areas->{$AREA_ID_OXFORDSHIRE};

        $self->body( $body );
        $self->setup_endpoint();
        $self->send_body();
    }
}

sub setup_endpoint {
    my $self = shift;

    my $use_extended = 0;
    if ( $self->body->areas->{$AREA_ID_BROMLEY} ) {
        $use_extended = 1;
    }

    my %open311_conf = (
        endpoint => $self->body->endpoint,
        jurisdiction => $self->body->jurisdiction,
        api_key => $self->body->api_key,
        use_extended_updates => $use_extended,
    );

    if ( $self->body->send_extended_statuses ) {
        $open311_conf{extended_statuses} = 1;
    }

    my $o = Open311->new( %open311_conf );

    if ( $self->body->areas->{$AREA_ID_BROMLEY} ) {
        my $endpoints = $o->endpoints;
        $endpoints->{update} = 'update.xml';
        $endpoints->{service_request_updates} = 'update.xml';
        $o->endpoints( $endpoints );
    }

    $self->open311( $o );
}

sub send_body {
    my $self = shift;

    my $comments = FixMyStreet::App->model('DB::Comment')->search( {
            'me.whensent'    => undef,
            'me.external_id' => undef,
            'me.state'          => 'confirmed',
            'me.confirmed'      => { '!=' => undef },
            'problem.whensent'    => { '!=' => undef },
            'problem.external_id'  => { '!=' => undef },
            'problem.bodies_str' => { -like => '%' . $self->body->id . '%' },
            'problem.send_method_used' => 'Open311',
        },
        {
            join => 'problem',
        }
    );

    while ( my $comment = $comments->next ) {
        $self->send_comment( $comment );
    }
}

sub send_comment {
    my ( $self, $comment ) = @_;

    # my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($comment->cobrand)->new();
    #
    # TODO actually this should be OK for any devolved endpoint if original Open311->can_be_devolved, presumably
    #if ( 0 ) { # Check can_be_devolved and do this properly if set
    #    my $sender = $cobrand->get_body_sender( $self->body, $comment->problem->category );
    #    my $config = $sender->{config};
    #    $o = Open311->new(
    #            endpoint => $config->endpoint,
    #            jurisdiction => $config->jurisdiction,
    #            api_key => $config->api_key,
    #            use_extended_updates => 1, # FMB uses extended updates
    #    );
    #}

    return if $comment->send_fail_count && $self->retry_timeout( $comment );

    if ( $self->body->areas->{$AREA_ID_BROMLEY} ) {
        my $extra = $comment->extra || {};
        unless ( $extra->{title} ) {
            $extra->{title} = $comment->user->title;
            $comment->extra( $extra );
        }
    }

    my $id = $self->open311->post_service_request_update( $comment );

    if ( $id ) {
        $comment->update( {
            external_id => $id,
            whensent    => \'ms_current_timestamp()',
        } );
    } else {
        $comment->update( {
            send_fail_count => $comment->send_fail_count + 1,
            send_fail_timestamp => \'ms_current_timestamp()',
            send_fail_reason => 'Failed to post over Open311',
        } );
    }
}

sub retry_timeout {
    my ( $self, $row ) = @_;

    my $tz = DateTime::TimeZone->new( name => 'local' );
    my $now = DateTime->now( time_zone => $tz );
    my $diff = $now - $row->send_fail_timestamp;
    if ( $diff->in_units( 'minutes' ) < 30 ) {
        return 1;
    }

    return 0;
}
