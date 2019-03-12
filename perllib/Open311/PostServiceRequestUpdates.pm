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

has verbose => ( is => 'ro', default => 0 );

sub send {
    my $self = shift;

    my $bodies = FixMyStreet::DB->resultset('Body')->search( {
        send_method => SEND_METHOD_OPEN311,
        send_comments => 1,
    } );

    while ( my $body = $bodies->next ) {
        my $cobrand = $body->get_cobrand_handler;
        next if $cobrand && $cobrand->call_hook('open311_post_update_skip');
        $self->process_body($body);
    }
}

sub open311_params {
    my ($self, $body) = @_;

    my %open311_conf = (
        endpoint => $body->endpoint,
        jurisdiction => $body->jurisdiction,
        api_key => $body->api_key,
        extended_statuses => $body->send_extended_statuses,
        fixmystreet_body => $body,
    );

    my $cobrand = $body->get_cobrand_handler;
    $cobrand->call_hook(open311_config_updates => \%open311_conf)
        if $cobrand;

    return %open311_conf;
}

sub process_body {
    my ($self, $body) = @_;

    my $o = Open311->new( $self->open311_params($body) );

    my $comments = FixMyStreet::DB->resultset('Comment')->to_body($body)->search( {
            'me.whensent' => undef,
            'me.external_id' => undef,
            'me.state' => 'confirmed',
            'me.confirmed' => { '!=' => undef },
            'problem.whensent' => { '!=' => undef },
            'problem.external_id' => { '!=' => undef },
            'problem.send_method_used' => { -like => '%Open311%' },
        },
        {
            order_by => [ 'confirmed', 'id' ],
        }
    );

    while ( my $comment = $comments->next ) {
        my $cobrand = $body->get_cobrand_handler || $comment->get_cobrand_logged;

        # Some cobrands (e.g. Buckinghamshire) don't want to receive updates
        # from anyone except the original problem reporter.
        if ($cobrand->call_hook(should_skip_sending_update => $comment)) {
            unless (defined $comment->get_extra_metadata('cobrand_skipped_sending')) {
                $comment->set_extra_metadata(cobrand_skipped_sending => 1);
                $comment->update;
            }
            next;
        }

        next if !$self->verbose && $comment->send_fail_count && retry_timeout($comment);

        $self->process_update($body, $o, $comment, $cobrand);
    }
}

sub process_update {
    my ($self, $body, $o, $comment, $cobrand) = @_;

    $cobrand->call_hook(open311_pre_send => $comment, $o);

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
