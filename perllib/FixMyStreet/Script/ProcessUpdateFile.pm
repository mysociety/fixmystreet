package FixMyStreet::Script::ProcessUpdateFile;

use v5.14;

use Moo;
use DateTime;
use DateTime::Format::W3CDTF;
use Getopt::Long::Descriptive;
use JSON::MaybeXS;
use Path::Tiny;
use Types::Standard qw(InstanceOf Maybe);

use FixMyStreet::DB;
use Open311::GetServiceRequestUpdates;

has verbose => ( is => 'ro', default => 0 );

has commit => ( is => 'ro', default => 0 );

has suppress_alerts => ( is => 'ro', default => 0 );

has body_name => ( is => 'ro' );

has file => ( is => 'ro' );

has body => (
    is => 'lazy',
    isa => Maybe[InstanceOf['FixMyStreet::DB::Result::Body']],
    default => sub {
        my $self = shift;
        my $body = FixMyStreet::DB->resultset('Body')->find({ name => $self->body_name });
        return $body;
    }
);

has start_date => (
    is => 'rw',
    default => '2010-01-01T00:00:00Z',
);

has end_date => (
    is => 'rw',
    default => sub {
        my $formatter = DateTime::Format::W3CDTF->new;
        return $formatter->format_datetime(DateTime->now);
    },
);

has data => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $string = path($self->file)->slurp_utf8;
        my $json = JSON::MaybeXS->new(utf8 => 1);
        my $data = $json->decode($string);

        return $data;
    }
);

sub process {
    my $self = shift;

    die "Problem loading body\n" unless $self->body;

    print "Dry run, not adding comments. Use --commit to add\n" unless $self->commit;

    my $updates = Open311::GetServiceRequestUpdates->new(
        verbose => $self->verbose,
        commit => $self->commit,
    );
    $updates->initialise_body($self->body);
    $updates->suppress_alerts(1) if $self->suppress_alerts;

    $updates->process_requests( $self->data, [$self->start_date, $self->end_date] );

    printf("added %d comments\n", $updates->comments_created);
}

1;
