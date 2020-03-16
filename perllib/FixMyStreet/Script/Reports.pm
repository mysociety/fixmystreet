package FixMyStreet::Script::Reports;

use Moo;
use CronFns;
use FixMyStreet;
use FixMyStreet::DB;
use FixMyStreet::Queue::Item::Report;

has verbose => ( is => 'ro' );
has debug_mode => ( is => 'ro' );

has debug_unsent_count => ( is => 'rw', default => 0 );
has unconfirmed_data => ( is => 'ro', default => sub { {} } );
has test_data => ( is => 'ro', default => sub { {} } );

# Static method, used by send-reports cron script and tests.
# Creates a manager object from provided data and processes it.
sub send(;$) {
    my ($site_override) = @_;
    my $rs = FixMyStreet::DB->resultset('Problem');

    # Set up site, language etc.
    my ($verbose, $nomail, $debug_mode) = CronFns::options();

    my $manager = __PACKAGE__->new(
        verbose => $verbose,
        debug_mode => $debug_mode,
    );

    my $base_url = FixMyStreet->config('BASE_URL');
    my $site = $site_override || CronFns::site($base_url);

    my $states = [ FixMyStreet::DB::Result::Problem::open_states() ];
    $states = [ 'submitted', 'confirmed', 'in progress', 'feedback pending', 'external', 'wish' ] if $site eq 'zurich';
    my $unsent = $rs->search( {
        state => $states,
        whensent => undef,
        bodies_str => { '!=', undef },
    } );

    $manager->debug_print("starting to loop through unsent problem reports...");
    while (my $row = $unsent->next) {
        my $item = FixMyStreet::Queue::Item::Report->new(
            report => $row,
            manager => $manager,
            nomail => $nomail,
            debug_mode => $debug_mode,
        );
        $item->process;
    }

    $manager->end_debug_line;
    $manager->end_summary_unconfirmed;

    return $manager->test_data;
}

sub end_debug_line {
    my $self = shift;
    return unless $self->debug_mode;

    print "\n";
    if ($self->debug_unsent_count) {
        $self->debug_print("processed all unsent reports (total: " . $self->debug_unsent_count . ")");
    } else {
        $self->debug_print("no unsent reports were found (must have whensent=null and suitable bodies_str & state) -- nothing to send");
    }
}

sub end_summary_unconfirmed {
    my $self = shift;
    return unless $self->verbose || $self->debug_mode;

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

sub debug_print {
    my $self = shift;
    return unless $self->debug_mode;

    my $msg = shift;
    my $id = shift || '';
    $id = "report $id: " if $id;
    print "[] $id$msg\n";
}

1;
