package FixMyStreet::DateRange;

use DateTime;
use DateTime::Format::Flexible;
use Moo;
use Try::Tiny;

my $one_day = DateTime::Duration->new( days => 1 );

has start_date => ( is => 'ro' );

has start_default => ( is => 'ro' );

has end_date => ( is => 'ro' );

has parser => (
    is => 'ro',
    default => sub { DateTime::Format::Flexible->new }
);

has formatter => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        return $self->parser;
    }
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

sub start {
    my $self = shift;
    $self->_dt($self->start_date) || $self->start_default
}

sub end {
    my $self = shift;
    my $d = $self->_dt($self->end_date);
    $d += $one_day if $d;
    return $d;
}

sub _formatted {
    my ($self, $dt) = @_;
    return unless $dt;
    $self->formatter->format_datetime($dt);
}

sub start_formatted { $_[0]->_formatted($_[0]->start) }
sub end_formatted { $_[0]->_formatted($_[0]->end) }

sub sql {
    my ($self, $default) = @_;
    my $sql = {};
    if (my $start = $self->start_formatted) {
        $sql->{'>='} = $start;
    }
    if (my $end = $self->end_formatted) {
        $sql->{'<'} = $end;
    }
    return $sql;
}

1;
