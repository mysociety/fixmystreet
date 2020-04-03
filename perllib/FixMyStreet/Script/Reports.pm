package FixMyStreet::Script::Reports;

use Moo;
use CronFns;
use FixMyStreet;
use FixMyStreet::DB;
use FixMyStreet::Queue::Item::Report;

has verbose => ( is => 'ro' );

has unconfirmed_data => ( is => 'ro', default => sub { {} } );
has test_data => ( is => 'ro', default => sub { {} } );

# Static method, used by send-reports cron script and tests.
# Creates a manager object from provided data and processes it.
sub send {
    my ($verbose, $nomail, $debug) = @_;

    my $manager = __PACKAGE__->new(
        verbose => $verbose,
    );

    my $site = CronFns::site(FixMyStreet->config('BASE_URL'));
    my $states = [ FixMyStreet::DB::Result::Problem::open_states() ];
    $states = [ 'submitted', 'confirmed', 'in progress', 'feedback pending', 'external', 'wish' ] if $site eq 'zurich';

    my $unsent = FixMyStreet::DB->resultset('Problem')->search( {
        state => $states,
        whensent => undef,
        bodies_str => { '!=', undef },
    } );

    $manager->log("starting to loop through unsent problem reports...");
    my $unsent_count = 0;
    while (my $row = $unsent->next) {
        $unsent_count++;
        my $item = FixMyStreet::Queue::Item::Report->new(
            report => $row,
            manager => $manager,
            verbose => $verbose,
            nomail => $nomail,
            debug => $debug,
        );
        $item->process;
    }

    $manager->end_line($unsent_count);
    $manager->end_summary_unconfirmed;

    return $manager->test_data;
}

sub end_line {
    my ($self, $unsent_count) = @_;
    return unless $self->verbose;

    if ($unsent_count) {
        $self->log("processed all unsent reports (total: $unsent_count)");
    } else {
        $self->log("no unsent reports were found (must have whensent=null and suitable bodies_str & state) -- nothing to send");
    }
}

sub end_summary_unconfirmed {
    my $self = shift;
    return unless $self->verbose;

    my %unconfirmed_data = %{$self->unconfirmed_data};
    print "Council email addresses that need checking:\n" if keys %unconfirmed_data;
    foreach my $e (keys %unconfirmed_data) {
        foreach my $c (keys %{$unconfirmed_data{$e}}) {
            my $data = $unconfirmed_data{$e}{$c};
            print "    " . $data->{count} . " problem, to $e category $c (" . $data->{note} . ")\n";
        }
    }
}

sub end_summary_failures {
    my $self = shift;

    my $sending_errors = '';
    my $unsent = FixMyStreet::DB->resultset('Problem')->search( {
        state => [ FixMyStreet::DB::Result::Problem::open_states() ],
        whensent => undef,
        bodies_str => { '!=', undef },
        send_fail_count => { '>', 0 }
    } );
    while (my $row = $unsent->next) {
        my $base_url = FixMyStreet->config('BASE_URL');
        $sending_errors .= "\n" . '=' x 80 . "\n\n" . "* " . $base_url . "/report/" . $row->id . ", failed "
            . $row->send_fail_count . " times, last at " . $row->send_fail_timestamp
            . ", reason " . $row->send_fail_reason . "\n";
    }
    if ($sending_errors) {
        print "The following reports had problems sending:\n$sending_errors";
    }
}

sub log {
    my ($self, $msg) = @_;
    return unless $self->verbose;
    STDERR->print("[fmsd] $msg\n");
}

1;
