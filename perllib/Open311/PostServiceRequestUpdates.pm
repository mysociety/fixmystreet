package Open311::PostServiceRequestUpdates;

use strict;
use warnings;
use v5.14;

use DateTime;
use Moo;
use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use Open311;

use constant SEND_METHOD_OPEN311 => 'Open311';

use constant COUNCIL_ID_OXFORDSHIRE => 2237;
use constant COUNCIL_ID_BROMLEY => 2482;
use constant COUNCIL_ID_LEWISHAM => 2492;
use constant COUNCIL_ID_BUCKS => 2217;

has verbose => ( is => 'ro', default => 0 );
has site => ( is => 'ro', default => '' );

sub send {
    my $self = shift;

    my $bodies = FixMyStreet::DB->resultset('Body')->search( {
        send_method => SEND_METHOD_OPEN311,
        send_comments => 1,
    } );

    while ( my $body = $bodies->next ) {
        # XXX Cobrand specific - see also list in Problem->updates_sent_to_body
        if ($self->site eq 'fixmystreet.com') {
            # Lewisham does not yet accept updates
            next if $body->areas->{+COUNCIL_ID_LEWISHAM};
        }

        $self->process_body($body);
    }
}

sub open311_params {
    my ($self, $body) = @_;

    my $use_extended = 0;
    if ( $self->site eq 'fixmystreet.com' && $body->areas->{+COUNCIL_ID_BROMLEY} ) {
        $use_extended = 1;
    }

    my %open311_conf = (
        endpoint => $body->endpoint,
        jurisdiction => $body->jurisdiction,
        api_key => $body->api_key,
        use_extended_updates => $use_extended,
    );

    if ( $body->areas->{+COUNCIL_ID_OXFORDSHIRE} ) {
        $open311_conf{use_customer_reference} = 1;
    }

    if ( $body->areas->{+COUNCIL_ID_BUCKS} ) {
        $open311_conf{mark_reopen} = 1;
    }

    if ( $body->send_extended_statuses ) {
        $open311_conf{extended_statuses} = 1;
    }

    return %open311_conf;
}

sub process_body {
    my ($self, $body) = @_;

    my $o = Open311->new( $self->open311_params($body) );

    if ( $self->site eq 'fixmystreet.com' && $body->areas->{+COUNCIL_ID_BROMLEY} ) {
        my $endpoints = $o->endpoints;
        $endpoints->{update} = 'update.xml';
        $endpoints->{service_request_updates} = 'update.xml';
        $o->endpoints( $endpoints );
    }

    my $comments = FixMyStreet::DB->resultset('Comment')->search( {
            'me.whensent' => undef,
            'me.external_id' => undef,
            'me.state' => 'confirmed',
            'me.confirmed' => { '!=' => undef },
            'problem.whensent' => { '!=' => undef },
            'problem.external_id' => { '!=' => undef },
            'problem.bodies_str' => { -like => '%' . $body->id . '%' },
            'problem.send_method_used' => 'Open311',
        },
        {
            join => 'problem',
            order_by => [ 'confirmed', 'id' ],
        }
    );

    while ( my $comment = $comments->next ) {
        my $cobrand = $body->get_cobrand_handler ||
                      FixMyStreet::Cobrand->get_class_for_moniker($comment->cobrand)->new();

        # Some cobrands (e.g. Buckinghamshire) don't want to receive updates
        # from anyone except the original problem reporter.
        if ($cobrand->call_hook(should_skip_sending_update => $comment)) {
            unless (defined $comment->get_extra_metadata('cobrand_skipped_sending')) {
                $comment->set_extra_metadata(cobrand_skipped_sending => 1);
                $comment->update;
            }
            next;
        }

        # Oxfordshire stores the external id of the problem as a customer reference
        # in metadata
        if ($body->areas->{+COUNCIL_ID_OXFORDSHIRE} &&
            !$comment->problem->get_extra_metadata('customer_reference') ) {
            next;
        }

        next if !$self->verbose && $comment->send_fail_count && retry_timeout($comment);

        $self->process_update($body, $o, $comment);
    }
}

sub process_update {
    my ($self, $body, $o, $comment) = @_;

    if ( $self->site eq 'fixmystreet.com' && $body->areas->{+COUNCIL_ID_BROMLEY} ) {
        my $extra = $comment->extra;
        $extra = {} if !$extra;

        unless ( $extra->{title} ) {
            $extra->{title} = $comment->user->title;
            $comment->extra( $extra );
        }
    }

    my $id = $o->post_service_request_update( $comment );

    if ( $id ) {
        $comment->update( {
            external_id => $id,
            whensent => \'current_timestamp',
        } );
    } else {
        $comment->update( {
            send_fail_count => $comment->send_fail_count + 1,
            send_fail_timestamp => \'current_timestamp',
            send_fail_reason => "Failed to post over Open311\n\n" . $o->error,
        } );

        if ( $self->verbose && $o->error ) {
            warn $o->error;
        }
    }
}

sub retry_timeout {
    my $row = shift;

    my $tz = FixMyStreet->local_time_zone;
    my $now = DateTime->now( time_zone => $tz );
    my $diff = $now - $row->send_fail_timestamp;
    if ( $diff->in_units( 'minutes' ) < 30 ) {
        return 1;
    }

    return 0;
}

1;
