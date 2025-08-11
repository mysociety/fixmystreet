=head1 NAME

Integrations::Echo::Booking - Echo specific code for booking slots

=head1 SYNOPSIS

This handles reserving and checking slots are still available in the Echo
backend, for both bulky and small items collections.

=head1 DESCRIPTION

=cut

package Integrations::Echo::Booking;

use Moo;
use Types::Standard qw(Enum);

has cobrand => ( is => 'ro' );
has property => ( is => 'ro' );
has type => ( is => 'ro', isa => Enum['bulky', 'small_items'] );

has config => ( is => 'lazy', default => sub { $_[0]->cobrand->feature('echo') });
has echo => ( is => 'lazy', default => sub { Integrations::Echo->new(%{$_[0]->config}) });

has service_id_key => ( is => 'lazy', default => sub { $_[0]->type . '_service_id' });
has event_type_id_key => ( is => 'lazy', default => sub { $_[0]->type . '_event_type_id' });
has service_id => ( is => 'lazy', default => sub { $_[0]->config->{$_[0]->service_id_key} });
has event_type_id => ( is => 'lazy', default => sub { $_[0]->config->{$_[0]->event_type_id_key} });

has guid_key => ( is => 'lazy', default => sub {
    my $self = shift;
    my $council_url = $self->cobrand->council_url;
    my $guid_key = $council_url . ":echo:event_guid:" . $self->service_id . ':' . $self->property->{id};
    return $guid_key;
});

sub find_available_slots {
    my ( $self, $last_earlier_date_str, $no_cache ) = @_;
    my $c = $self->cobrand->{c};
    my $council_url = $self->cobrand->council_url;

    my $key
        = $council_url . ":echo:available_slots:"
        . ( $last_earlier_date_str ? 'later' : 'earlier' ) . ':'
        . $self->service_id . ':'
        . $self->property->{id};
    if (!$no_cache) {
        my $data = $c->waste_cache_get($key);
        return $data if $data;
    }

    my $guid = $c->waste_cache_get($self->guid_key);
    unless ($guid) {
        require UUID::Tiny;
        $guid = UUID::Tiny::create_uuid_as_string();
        $c->waste_cache_set($self->guid_key, $guid);
    }

    my $window = $self->cobrand->_bulky_collection_window($last_earlier_date_str);
    my @available_slots;
    my $slots = $self->echo->ReserveAvailableSlotsForEvent($self->service_id, $self->event_type_id, $self->property->{id}, $guid, $window->{date_from}, $window->{date_to});
    $c->session->{first_date_returned} = undef;
    my $construct = $self->cobrand->can('construct_bin_date');
    foreach (@$slots) {
        my $date = $construct->($_->{StartDate})->datetime;
        push @available_slots, {
            date => $date,
            reference => $_->{Reference},
            expiry => $construct->($_->{Expiry})->datetime,
        };
        $c->session->{first_date_returned} //= $date;
    }

    $c->cobrand->call_hook('filter_booking_dates', \@available_slots);
    $c->waste_cache_set($key, \@available_slots) if !$no_cache;

    return \@available_slots;
}

sub check_slot_available {
    my ( $self, $chosen_date_string, %args ) = @_;

    my $form = $args{form};

    # chosen_date_string is of the form
    # '2023-08-29T00:00:00;AS3aUwCS7NwGCTIzMDMtMTEwMTyNVqC8SCJe+A==;2023-08-25T15:49:38'
    my ( $collection_date, undef, $slot_expiry_date )
        = $chosen_date_string =~ /[^;]+/g;

    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T' );
    my $slot_expiry_dt = $parser->parse_datetime($slot_expiry_date);

    my $now_dt = DateTime->now;

    # Note: Both $slot_expiry_dt and $now_dt are UTC
    if ( $slot_expiry_dt <= $now_dt ) {
        # Cancel the expired slots and call ReserveAvailableSlots again, try to
        # get the same collection date
        my $property = $self->cobrand->{c}->stash->{property};
        $self->cobrand->clear_cached_lookups_bulky_slots($property->{id});

        my $available_slots = $self->find_available_slots(undef, 'no_cache');

        my ($slot) = grep { $_->{date} eq $collection_date } @$available_slots;

        if ($slot) {
            $form->saved_data->{chosen_date}
                = $slot->{date} . ";"
                . $slot->{reference} . ";"
                . $slot->{expiry};

            return 1;
        } else {
            return 0;
        }
    } else {
        return 1;
    }
}

1;
