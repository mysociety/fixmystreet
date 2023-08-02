package FixMyStreet::Script::SendDaemon;

use v5.14;
use warnings;
use Try::Tiny;
use FixMyStreet::DB;
use FixMyStreet::Script::Reports;
use FixMyStreet::Queue::Item::Report;
use Open311::PostServiceRequestUpdates;

my $verbose = 0;
my $changeverboselevel;

sub look_for_report {
    my ($opts) = @_;

    my $params = FixMyStreet::Script::Reports::construct_query($opts->debug);
    my $unsent = FixMyStreet::DB->resultset('Problem')->search($params, {
        for => \'UPDATE SKIP LOCKED',
        rows => 1,
        order_by => \'RANDOM()'
    } )->single or return;

    print_log('debug', "Trying to send report " . $unsent->id);
    my $item = FixMyStreet::Queue::Item::Report->new(
        report => $unsent,
        verbose => $opts->verbose,
        nomail => $opts->nomail,
    );
    try {
        $item->process;
    } catch {
        $unsent->update_send_failed($_ || 'unknown error');
        print_log('info', '[', $unsent->id, "] Send failed: $_");
    };
}

sub look_for_update {
    my ($opts) = @_;

    my $updates = Open311::PostServiceRequestUpdates->new(
        verbose => $opts->verbose,
    );

    my $bodies = $updates->fetch_bodies;
    my $params = $updates->construct_query($opts->debug);
    my $comment = FixMyStreet::DB->resultset('Comment')
        ->search($params, {
            for => \'UPDATE SKIP LOCKED',
            rows => 1,
            order_by => \'RANDOM()'
        })->single or return;

    my $problem = $comment->problem;
    my ($body) = grep { $bodies->{$_} } @{$problem->bodies_str_ids};
    if (!$body) {
        $comment->update({ send_state => 'processed' });
        print_log('debug', '[', $comment->id, '] marking as processed due to non matching bodies_str');
    } elsif (!$problem->whensent && !$problem->is_open) {
        $comment->update({ send_state => 'processed' });
        print_log('debug', '[', $comment->id, '] marking as processed due to unsent problem, non-open problem state');
    } elsif (!$problem->whensent) {
        # Might just not be sent yet
    } else {
        # Okay to send!
        $body = $bodies->{$body};
        print_log('debug', "Trying to send update " . $comment->id);
        $updates->process_update($body, $comment);
    }
}

sub setverboselevel { $verbose = shift || 0; }
sub changeverboselevel { ++$changeverboselevel; }

sub print_log {
    my $prio = shift;

    if ($changeverboselevel) {
        $verbose = ($verbose + $changeverboselevel) % 3;
        STDERR->print("fmsd: info: verbose level now $verbose\n");
        $changeverboselevel = 0;
    }

    if ($verbose < 2) {
        return if ($prio eq 'noise');
        return if ($verbose < 1 && $prio eq 'debug');
        return if ($verbose < 0 && $prio eq 'info');
    }
    STDERR->print("[fmsd] [$prio] ", join("", @_), "\n");
}

1;
