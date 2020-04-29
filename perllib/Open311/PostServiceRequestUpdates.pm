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
has current_open311 => ( is => 'rw' );

sub send {
    my $self = shift;

    my $bodies = $self->fetch_bodies;
    foreach my $body (values %$bodies) {
        $self->construct_open311($body);
        $self->process_body($body);
    }
}

sub fetch_bodies {
    my $bodies = FixMyStreet::DB->resultset('Body')->search( {
        send_method => SEND_METHOD_OPEN311,
        send_comments => 1,
    }, { prefetch => 'body_areas' } );
    my %bodies;
    while ( my $body = $bodies->next ) {
        my $cobrand = $body->get_cobrand_handler;
        next if $cobrand && $cobrand->call_hook('open311_post_update_skip');
        $bodies{$body->id} = $body;
    }
    return \%bodies;
}

sub construct_open311 {
    my ($self, $body) = @_;
    my $o = Open311->new($self->open311_params($body));
    $self->current_open311($o);
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

    my $params = $self->construct_query($self->verbose);

    my $db = FixMyStreet::DB->schema->storage;
    $db->txn_do(sub {
        my $comments = FixMyStreet::DB->resultset('Comment')->to_body($body)->search($params, {
            for => \'UPDATE SKIP LOCKED',
            order_by => [ 'confirmed', 'id' ],
        });

        while ( my $comment = $comments->next ) {
            $self->process_update($body, $comment);
        }
    });
}

sub construct_query {
    my ($self, $debug) = @_;
    my $params = {
        'me.whensent' => undef,
        'me.external_id' => undef,
        'me.state' => 'confirmed',
        'me.confirmed' => { '!=' => undef },
        'me.extra' => [ undef, { -not_like => '%cobrand_skipped_sending%' } ],
        'problem.whensent' => { '!=' => undef },
        'problem.external_id' => { '!=' => undef },
        'problem.send_method_used' => { -like => '%Open311%' },
    };
    if (!$debug) {
        $params->{'-or'} = [
            'me.send_fail_count' => 0,
            'me.send_fail_timestamp' => { '<', \"current_timestamp - '30 minutes'::interval" },
        ];
    }
    return $params;
}

sub process_update {
    my ($self, $body, $comment) = @_;

    my $cobrand = $body->get_cobrand_handler || $comment->get_cobrand_logged;

    # Some cobrands (e.g. Buckinghamshire) don't want to receive updates
    # from anyone except the original problem reporter.
    if (my $skip = $cobrand->call_hook(should_skip_sending_update => $comment)) {
        if ($skip ne 'WAIT' && !defined $comment->get_extra_metadata('cobrand_skipped_sending')) {
            $comment->set_extra_metadata(cobrand_skipped_sending => 1);
            $comment->update;
        }
        $self->log($comment, 'Skipping');
        return;
    }

    my $o = $self->current_open311;

    $cobrand->call_hook(open311_pre_send => $comment, $o);

    my $id = $o->post_service_request_update( $comment );

    if ( $id ) {
        $comment->update( {
            external_id => $id,
            whensent => \'current_timestamp',
        } );
        $self->log($comment, 'Send successful');
    } else {
        $comment->update( {
            send_fail_count => $comment->send_fail_count + 1,
            send_fail_timestamp => \'current_timestamp',
            send_fail_reason => "Failed to post over Open311\n\n" . $o->error,
        } );
        $self->log($comment, 'Send failed');
    }
}

sub log {
    my ($self, $comment, $msg) = @_;
    return unless $self->verbose;
    STDERR->print("[fmsd] [" . $comment->id . "] $msg\n");
}

1;
