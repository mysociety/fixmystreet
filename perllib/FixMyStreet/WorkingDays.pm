package FixMyStreet::WorkingDays;

use Moo;

=head1 FixMyStreet::WorkingDays

Given a list of public holiday dates, creates an object that can be used to
add/subtract days from a date, only counting working days (excluding public
holidays and weekends or Sundays).

=over

=cut

has public_holidays => (
    is => 'ro',
    default => sub { [] },
    coerce => sub {
        return { map { $_ => 1 } @{$_[0]} };
    },
);

# Set to true if Saturdays are a working day
has saturdays => (
    is => 'ro',
    default => 0,
);

=item add_days

Given a DateTime object and a number of days, returns a new DateTime object
that many working days (excluding public holidays and weekends) later.

=cut

sub add_days {
    my ( $self, $dt, $days, $subtract ) = @_;
    $dt = $dt->clone;
    while ( $days > 0 ) {
        $dt->add ( days => $subtract ? -1 : 1 );
        next if $self->is_non_working_day($dt);
        $days--;
    }
    return $dt;
}

=item sub_days

Given a DateTime object and a number of days, returns a new DateTime object
that many working days (excluding public holidays and weekends) earlier.

=cut

sub sub_days {
    my $self = shift;
    return $self->add_days(@_, 1);
}

=item is_non_working_day

Given a DateTime object, return true if it's a non-working day.

=cut

sub is_non_working_day {
    my ( $self, $dt ) = @_;
    return $self->is_public_holiday($dt) || $self->is_sunday($dt) || (!$self->saturdays && $self->is_weekend($dt));
}

=item is_public_holiday

Given a DateTime object, return true if it is a public holiday.

=cut

sub is_public_holiday {
    my ($self, $dt) = @_;
    return $self->public_holidays->{$dt->ymd};
}

=item is_sunday

Given a DateTime object, return true if it is a Sunday.

=cut

sub is_sunday {
    my ($self, $dt) = @_;
    return $dt->dow == 7;
}

=item is_weekend

Given a DateTime object, return true if it is a weekend.

=cut

sub is_weekend {
    my ($self, $dt) = @_;
    return $dt->dow > 5;
}

1;

=back

