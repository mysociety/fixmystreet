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

    my $bodies = $self->fetch_bodies;
    foreach my $body (values %$bodies) {
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
    my ($self, $body, $comment) = @_;
    my $o = Open311->new($self->open311_params($body, $comment));
    return $o;
}

sub open311_params {
    my ($self, $body, $comment) = @_;

    my $conf = $body;
    if ($comment) {
        my $cobrand_logged = $comment->get_cobrand_logged;
        my $sender = $cobrand_logged->get_body_sender($body, $comment->problem);
        $conf = $sender->{config};
    }

    my %open311_conf = (
        endpoint => $conf->endpoint,
        jurisdiction => $conf->jurisdiction,
        api_key => $conf->api_key,
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
        -or => [
            'me.extra' => undef,
            -not => { 'me.extra' => { '\?' => 'cobrand_skipped_sending' } }
        ],
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

    my $o = $self->construct_open311($body, $comment);

    $cobrand->call_hook(open311_pre_send_updates => $comment);

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

sub summary_failures {
    my $self = shift;
    my $bodies = $self->fetch_bodies;
    my $params = $self->construct_query(1);
    my $u = FixMyStreet::DB->resultset("Comment")
        ->to_body([ keys %$bodies ])
        ->search({ "me.send_fail_count" => { '>', 0 } })
        ->search($params, { join => "problem" });

    my $base_url = FixMyStreet->config('BASE_URL');
    my $sending_errors;
    while (my $row = $u->next) {
        my $url = $base_url . "/report/" . $row->problem_id;
        $sending_errors .= "\n" . '=' x 80 . "\n\n" . "* $url, update " . $row->id . " failed "
            . $row->send_fail_count . " times, last at " . $row->send_fail_timestamp
            . ", reason " . $row->send_fail_reason . "\n";
    }
    if ($sending_errors) {
        print '=' x 80 . "\n\n" . "The following updates failed sending:\n$sending_errors";
    }
}

sub log {
    my ($self, $comment, $msg) = @_;
    return unless $self->verbose;
    STDERR->print("[fmsd] [" . $comment->id . "] $msg\n");
}

1;
