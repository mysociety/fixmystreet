=head1 NAME

FixMyStreet::DateRange - little wrapper of an inclusive date range

=head1 SYNOPSIS

Given a start/end date, this can be used to return DBIx::Class parameters for
searching within that date range, inclusive of both start and end dates.

=head1 DESCRIPTION

=cut

package FixMyStreet::DateRange;

use DateTime;
use DateTime::Format::Flexible;
use Moo;
use Try::Tiny;

my $one_day = DateTime::Duration->new( days => 1 );

=over 4

=item * start_date and end_date - provided start and end dates, to be parsed

=cut

has start_date => ( is => 'ro' );

=item * start_default - default to use if start_date not provided

=cut

has start_default => ( is => 'ro' );

has end_date => ( is => 'ro' );

=item * parser - defaults to DateTime::Format::Flexible

=cut

has parser => (
    is => 'ro',
    default => sub { DateTime::Format::Flexible->new }
);

=item * formatter - defaults to same as parser

=cut

has formatter => (
    is => 'lazy',
    default => sub { $_[0]->parser }
);

sub _dt {
    my ($self, $date) = @_;
    my %params;
    $params{european} = 1 if $self->parser->isa('DateTime::Format::Flexible');
    my $d = try {
        $self->parser->parse_datetime($date, %params)
    };
    return $d;
}

=back

=head2 METHODS

=over 4

=item * start / end - provides DateTimes of the start/end of the range

=cut

has start => (
    is => 'lazy',
    default => sub {
        $_[0]->_dt($_[0]->start_date) || $_[0]->start_default
    }
);

has end => (
    is => 'lazy',
    default => sub {
        my $d = $_[0]->_dt($_[0]->end_date);
        $d += $one_day if $d;
        return $d;
    }
);

sub _formatted {
    my ($self, $dt) = @_;
    return unless $dt;
    $self->formatter->format_datetime($dt);
}

=item * start_formatted / end_formatted - formatted timestamps

=cut

has start_formatted => (
    is => 'lazy',
    default => sub { $_[0]->_formatted($_[0]->start) }
);

has end_formatted => (
    is => 'lazy',
    default => sub { $_[0]->_formatted($_[0]->end) }
);

=item * sql - returns a hashref of two comparison operators for the range

=back

=cut

has sql => (
    is => 'lazy',
    default => sub {
        my $sql = {};
        if (my $start = $_[0]->start_formatted) {
            $sql->{'>='} = $start;
        }
        if (my $end = $_[0]->end_formatted) {
            $sql->{'<'} = $end;
        }
        return $sql;
    }
);

1;
