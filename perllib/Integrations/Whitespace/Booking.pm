=head1 NAME

Integrations::Whitespace::Booking - Echo specific code for booking slots

=head1 SYNOPSIS

This handles reserving and checking slots are still available in the Whitespace
backend, for both bulky and small items collections.

=head1 DESCRIPTION

=cut

package Integrations::Whitespace::Booking;

use Moo;
use Types::Standard qw(Enum);

has cobrand => ( is => 'ro' );
has property => ( is => 'ro' );
has type => ( is => 'ro', isa => Enum['bulky', 'small_items'] );

has config => ( is => 'lazy', default => sub { $_[0]->cobrand->feature('whitespace') });
has ws => ( is => 'lazy', default => sub { Integrations::Whitespace->new(%{$_[0]->config}) });

sub find_available_slots {
    my ( $self, $last_earlier_date_str, $no_cache ) = @_;

    my $c = $self->cobrand->{c};
    my $key = $self->cobrand->council_url . ":whitespace:available_bulky_slots:" . $self->property->{id};

    if (!$no_cache) {
        my $data = $c->waste_cache_get($key);
        return $data if $data;
    }

    my $window = $self->cobrand->_bulky_collection_window($last_earlier_date_str);
    my @available_slots;
    my $slots = $self->ws->GetCollectionSlots($self->property->{uprn}, $window->{date_from}, $window->{date_to});
    foreach (@$slots) {
        (my $date = $_->{AdHocRoundInstanceDate}) =~ s/T00:00:00//;
        $date = $self->cobrand->_bulky_date_to_dt($date);
        next if FixMyStreet::Cobrand::UK::is_public_holiday(date => $date);
        next if $_->{SlotsFree} <= 0;
        push @available_slots, {
            date => $date->date,
            reference => $_->{AdHocRoundInstanceID},
            expiry => '',
        };
    }

    $c->waste_cache_set($key, \@available_slots) if !$no_cache;

    return \@available_slots;
}

sub check_slot_available {
    my ( $self, $chosen_date_string, %args ) = @_;

    my $c = $self->cobrand->{c};
    # chosen_date_string is of the form
    # '2023-08-29;12345;'
    my ( $collection_date) = $chosen_date_string =~ /[^;]+/g;

    my $available_slots = $self->find_available_slots(undef, 'no_cache');

    my ($slot) = grep { $_->{date} eq $collection_date } @$available_slots;
    if ($slot) {
        # We don't need new references like Echo, so no need to update chosen_date. If we did,
        # it'd be something like this:
        # $args{form}->saved_data->{chosen_date} = $slot->{date} . ';' . $slot->{reference} . ';';
        return 1;
    } else {
        return 0;
    }
}

1;
