package Open311::PostServiceRequestUpdates;

=head1 NAME

Open31::PostServiceRequestUpdates - send updates via Open311 extension

=head1 DESCRIPTION

This package contains the code needed to find the relevant updates in the
database that need sending via Open311, and show updates waiting to be sent.

=head1 STATE

Comments have a send_state column that this code uses for processing. The main
query looks for all B<unprocessed> confirmed updates, on reports that have been
sent somewhere. (It also has a backoff unless running with debug set.)

If a report doesn't have an external_id, or does not contain Open311 in its
send_method_used, then we know we don't need to worry about this comment again,
so mark it as B<processed> and move on.

Some cobrands can ask for certain updates to be skipped; if that's the case,
mark the comment as B<skipped> and move on.

Otherwise, try and send the update via Open311. If it succeeds, mark the
comment as B<sent>; if not, leave as B<unprocessed> so it will be looked at
again.

=head1 FUNCTIONS

=cut

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

=head2 send

Used by the send-comments command line script (and tests) to send updates on
all relevant bodies.

=cut

sub send {
    my $self = shift;

    my $bodies = $self->fetch_bodies;
    foreach my $body (values %$bodies) {
        $self->process_body($body);
    }
}

=head2 fetch_bodies

Returns all bodies from the database who send reports via Open311 and have the
send_comments flag set.

=cut

sub fetch_bodies {
    my $bodies = FixMyStreet::DB->resultset('Body')->search( {
        send_method => SEND_METHOD_OPEN311,
        send_comments => 1,
    }, { prefetch => 'body_areas' } );
    my %bodies;
    while ( my $body = $bodies->next ) {
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

=head2 process_body

Given a body, queries the database for all relevant updates and processes them.
Used by the command line script.

=cut

sub process_body {
    my ($self, $body) = @_;

    my $params = $self->construct_query($self->verbose);

    my $db = FixMyStreet::DB->schema->storage;
    $db->txn_do(sub {
        my $comments = FixMyStreet::DB->resultset('Comment')->to_body($body)->search($params, {
            for => \'UPDATE SKIP LOCKED',
            prefetch => 'problem',
            order_by => [ 'me.confirmed', 'me.id' ],
        });

        while ( my $comment = $comments->next ) {
            next unless $comment->problem->whensent;
            $self->process_update($body, $comment);
        }
    });
}

=head2 construct_query

Returns the database search parameters needed to locate relevant updates.

=cut

sub construct_query {
    my ($self, $debug) = @_;
    my $params = {
        'me.send_state' => 'unprocessed',
        'me.state' => 'confirmed',
    };
    if (!$debug) {
        $params->{'-or'} = [
            'me.send_fail_count' => 0,
            'me.send_fail_timestamp' => { '<', \"current_timestamp - '30 minutes'::interval" },
        ];
    }
    return $params;
}

=head2 process_update

Given a body and an update from the database, process it and either mark it as
processed, skipped, sent, or left as unprocessed if sending failed.

=cut

sub process_update {
    my ($self, $body, $comment) = @_;

    my $cobrand = $body->get_cobrand_handler || $comment->get_cobrand_logged;

    # We only care about updates on reports sent by Open311 with an external_id
    # We know the report has been sent to get here, so if it lacks either of
    # those it is one that will not be sent, so we can mark as done and finish.
    my $problem = $comment->problem;
    if (!$problem->external_id || $problem->send_method_used !~ /Open311/) {
        $comment->send_state('processed');
        $comment->update;
        $self->log($comment, 'Marking as processed');
        return;
    }

    # Comments are ordered randomly.
    # Some cobrands/APIs do not handle ordering by age their end (e.g.
    # Northumberland + Alloy) so we skip comment for now if an older unsent
    # one exists for the problem. Otherwise an older update may overwrite a
    # newer one in Alloy etc.
    my $formatter = FixMyStreet::DB->schema->storage->datetime_parser;
    my @unsent_comments_for_problem
        = $problem->comments->search(
            {
                state => 'confirmed',
                send_state => 'unprocessed',
                confirmed => { '<' =>
                        $formatter->format_datetime( $comment->confirmed ) },
            }
        )->order_by('confirmed');

    if (@unsent_comments_for_problem) {
        $self->log( $comment,
            'Skipping for now because of older unprocessed update' );
        return;
    }

    # Some cobrands (e.g. Buckinghamshire) don't want to receive updates
    # from anyone except the original problem reporter.
    if (my $skip = $cobrand->call_hook(should_skip_sending_update => $comment)) {
        if ($skip eq 'WAIT') {
            # Mark this as a failure, so that it is not constantly retried
            $comment->update_send_failed("Skipping posting due to wait");
        } elsif ($comment->send_state eq 'unprocessed') {
            $comment->send_state('skipped');
            $comment->update;
        }
        $self->log($comment, 'Skipping');
        return;
    }

    my $o = $self->construct_open311($body, $comment);

    $cobrand->call_hook(open311_pre_send_updates => $comment);

    my $id = $o->post_service_request_update( $comment );

    $cobrand->call_hook(open311_post_send_updates => $comment, $id);

    if ( $id ) {
        $comment->update( {
            external_id => $id,
            whensent => \'current_timestamp',
            send_state => 'sent',
        } );
        $self->log($comment, 'Send successful');
    } else {
        $comment->update_send_failed("Failed to post over Open311\n\n" . $o->error);
        $self->log($comment, 'Send failed');
    }
}

=head2 summary_failures

Provides a textual output of all updates waiting to be sent and their reasons
for failure.

=cut

sub summary_failures {
    my $self = shift;
    my $bodies = $self->fetch_bodies;
    my $params = $self->construct_query(1);
    my $u = FixMyStreet::DB->resultset("Comment")
        ->to_body([ keys %$bodies ])
        ->search({ "me.send_fail_count" => { '>', 0 } })
        ->search($params, { prefetch => 'problem' });

    my $base_url = FixMyStreet->config('BASE_URL');
    my $sending_errors;
    while (my $row = $u->next) {
        next unless $row->problem->whensent;
        next if $row->send_fail_reason eq "Skipping posting due to wait" && $row->send_fail_count < 5;
        next if $row->problem->to_body_named('Bromley') && $row->send_fail_reason =~ /Invalid ActionType specified/; # Bromley issue with certain updates
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
