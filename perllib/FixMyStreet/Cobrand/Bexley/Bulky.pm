=head1 NAME

FixMyStreet::Cobrand::Bexley::Bulky - code specific to Bexley WasteWorks Bulky Waste

=cut

package FixMyStreet::Cobrand::Bexley::Bulky;

use DateTime::Format::Strptime;
use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::BulkyWaste';

sub bulky_allowed_property {
    my ($self, $property) = @_;
    my $class = $property->{class} || '';
    return $class =~ /^RD/ ? 1 : 0;
}

sub bulky_cancellation_cutoff_time { { hours => 23, minutes => 59, working_days => 1 } }
sub bulky_collection_time { { hours => 6, minutes => 0 } }
sub bulky_collection_window_days { 56 }

sub collection_date {
    my ($self, $p) = @_;
    return $self->_bulky_date_to_dt($p->get_extra_field_value('Collection_Date'));
}

sub bulky_free_collection_available { 0 }

sub _bulky_date_to_dt {
    my ($self, $date) = @_;
    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T', time_zone => FixMyStreet->local_time_zone);
    my $dt = $parser->parse_datetime($date);
    return $dt ? $dt->truncate( to => 'day' ) : undef;
}

# We will send and then cancel if payment not received

sub bulky_send_before_payment { 1 }

# No earlier/later (make this Peterborough only?)

sub bulky_hide_later_dates { 1 }

sub bulky_disabled_item_photos { 1 }
sub bulky_disabled_location_photo { 1 }

# Look up slots

sub find_available_bulky_slots {
    my ( $self, $property, $last_earlier_date_str, $no_cache ) = @_;

    my $key = $self->council_url . ":whitespace:available_bulky_slots:" . $property->{id};
    if (!$no_cache) {
        my $data = $self->{c}->waste_cache_get($key);
        return $data if $data;
    }

    my $ws = $self->whitespace;
    my $window = $self->_bulky_collection_window($last_earlier_date_str);
    my @available_slots;
    my $slots = $ws->GetCollectionSlots($property->{uprn}, $window->{date_from}, $window->{date_to});
    foreach (@$slots) {
        my $date = $_->{AdHocRoundInstanceDate};
        $date = $self->_bulky_date_to_dt($date);
        next if FixMyStreet::Cobrand::UK::is_public_holiday(date => $date);
        push @available_slots, {
            date => $date->datetime,
            id => $_->{AdHocRoundInstanceID},
        };
    }

    # Make sure there's a Saturday XXX TODO remove
    push @available_slots, { date => '2025-07-26T00:00:00', id => 'saturday' };

    $self->{c}->waste_cache_set($key, \@available_slots) if !$no_cache;

    return \@available_slots;
}

# Pricing

sub bulky_points_per_item_pricing { 1 }
sub bulky_items_maximum { 104 } # XXX for oap, 52 for non

sub bulky_item_points_total {
    my ($self, $data) = @_;
    my %points = map { $_->{name} => $_->{points} } @{ $self->bulky_items_master_list };
    my $points = 0;
    my $max = $self->bulky_items_maximum;
    for (1..$max) {
        my $item = $data->{"item_$_"} or next;
        $points += $points{$item};
    }
    return $points;
}

sub bulky_points_to_price {
    my ($self, $points, $levels) = @_;
    my $total = 0;
    foreach (@$levels) {
        if ($points >= $_->{min}) {
            $total = $_->{price};
        }
    }
    return $total;
}

sub bulky_pricing_model {
    my ($self, $data) = @_;
    my $cfg = $self->wasteworks_config;

    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T' );
    my $dt = $parser->parse_datetime($data->{chosen_date});
    my $saturday = $dt->day_of_week == 6 ? 'yes' : 'no';

    my $pension = lc $data->{pension};

    my $points = $cfg->{points}{$saturday}{$pension};
    return $points;
}

1;
