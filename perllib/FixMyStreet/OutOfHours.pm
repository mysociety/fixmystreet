package FixMyStreet::OutOfHours;

use Moo;
use Time::Piece;

# Default is 0-8 and 18-24 Monday to Friday, all day weekends and Bank Holidays
# 1 is Sunday, 7 is Saturday, 8 is Bank Holidays.
my $DEFAULT = [
    [ 1, 0, 1440 ],
    [ 2, 0, 480 ],
    [ 2, 1080, 1440 ],
    [ 3, 0, 480 ],
    [ 3, 1080, 1440 ],
    [ 4, 0, 480 ],
    [ 4, 1080, 1440 ],
    [ 5, 0, 480 ],
    [ 5, 1080, 1440 ],
    [ 6, 0, 480 ],
    [ 6, 1080, 1440 ],
    [ 7, 0, 1440 ],
    [ 8, 0, 1440 ],
];

has times => (
    is => 'ro',
    default => sub { $DEFAULT },
    coerce => sub { ref $_[0] eq 'ARRAY' ? $_[0] : $DEFAULT },
);

has holidays => (
    is => 'ro',
    default => sub { [] },
);

sub active {
    my $self = shift;
    my $now = localtime;
    my $time = $now->hour * 60 + $now->min;
    foreach (@{$self->times}) {
        my ($day, $s, $e) = @$_;
        if ($time >= $s - 5 && $time < $e) {
            return 1 if $day eq $now->wday;
            return 1 if $day eq $now->ymd;
            return 1 if $day eq '8' && $self->is_public_holiday($now);
        }
    }
    return 0;
}

sub is_public_holiday {
    my ($self, $date) = @_;
    $date = $date->date;
    foreach (@{$self->holidays}) {
        return 1 if $_ eq $date;
    }
    return 0;
}

1;
