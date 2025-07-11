=head1 NAME

Integrations::Bartec::Booking - Bartec specific code for booking slots

=head1 SYNOPSIS

This handles checking slots are available in the Bartec backend for bulky
collections.

=head1 DESCRIPTION

=cut

package Integrations::Bartec::Booking;

use Moo;

has cobrand => ( is => 'ro' );
has service_id => ( is => 'ro' );
has event_type_id => ( is => 'ro' );
has property => ( is => 'ro' );

=item * We return a maximum of 2 date options to users when they are booking
a bulky waste collection

=cut

sub max_bulky_collection_dates       {2}

=item * Bulky workpack name is of the form 'Waste-BULKY WASTE-<date>' or
'Waste-WHITES-<date>'

=cut

sub bulky_workpack_name {
    qr/Waste-(BULKY WASTE|WHITES)-(?<date_suffix>\d{6})/;
}

# XXX
# Error handling
# Holidays, bank holidays?
# Monday limit, Tuesday limit etc.?
# Check which bulky collections are pending, open
sub find_available_slots {
    my ( $cls, $last_earlier_date_str ) = @_;
    my $property = $cls->property;
    my $self = $cls->cobrand;
    my $c = $self->{c};

    my $key
        = 'peterborough:bartec:available_slots:'
        . ( $last_earlier_date_str ? 'later' : 'earlier' ) . ':'
        . $property->{uprn};
    my $data = $c->waste_cache_get($key);
    return $data if $data;

    my $bartec = $self->feature('bartec');
    $bartec = Integrations::Bartec->new(%$bartec);

    my $window = $self->_bulky_collection_window($last_earlier_date_str);
    if ( $window->{error} ) {
        # XXX Handle error gracefully
        die $window->{error};
    }
    my $workpacks = $bartec->Premises_FutureWorkpacks_Get(
        date_from => $window->{date_from},
        date_to   => $window->{date_to},
        uprn      => $property->{uprn},
    );

    my @available_slots;
    my %seen_dates;

    my $last_workpack_date;
    for my $workpack (@$workpacks) {
        # Depending on the Collective API version (R1531 or R1611),
        # $workpack->{Actions} can be an arrayref or a hashref.
        # If a hashref, it may be an action structure of the form
        # { 'ActionName' => ... },
        # or it may have the key {Action}.
        # $workpack->{Actions}{Action} can also be an arrayref or hashref.
        # From this variety of structures, we want to get an arrayref of
        # action hashrefs of the form [ { 'ActionName' => ... }, {...} ].
        my $action_data = $workpack->{Actions};
        if ( ref $action_data eq 'HASH' ) {
            if ( exists $action_data->{Action} ) {
                $action_data = $action_data->{Action};
                $action_data = [$action_data] if ref $action_data eq 'HASH';
            } else {
                $action_data = [$action_data];
            }
        }

        my %action_hash = map {
            my $action_name = $_->{ActionName} // '';
            $action_name = $self->service_name_override()->{$action_name}
                // $action_name;

            $action_name => $_;
        } @$action_data;

        # We only want dates that coincide with black bin collections
        next if !exists $action_hash{'Black Bin'};

        # This case shouldn't occur, but in case there are multiple black bin
        # workpacks for the same date, we only take the first into account
        next if $workpack->{WorkPackDate} eq ( $last_workpack_date // '' );

        # Only include if max jobs not already reached
        if ($cls->check_slot_available($workpack->{WorkPackDate}, bartec => $bartec)) {
            push @available_slots, {
                workpack_id => $workpack->{id},
                date        => $workpack->{WorkPackDate},
            };
            $seen_dates{$workpack->{WorkPackDate}} = 1;
        }

        $last_workpack_date = $workpack->{WorkPackDate};

        # Provision of $last_earlier_date_str implies we want to fetch all
        # remaining available slots in the given window, so we ignore the
        # limit
        last
            if !$last_earlier_date_str
            && @available_slots == max_bulky_collection_dates();
    }

    if (my $amend = $c->stash->{amending_booking}) {
        my $date = $amend->get_extra_field_value('DATE');
        if (!$seen_dates{$date}) {
            unshift @available_slots, { date => $date };
        }
    }

    return $c->waste_cache_set($key, \@available_slots);
}

# Checks if there is a slot available for a given date
sub check_slot_available {
    my ( $cls, $date, %args ) = @_;
    my $self = $cls->cobrand;

    my $bartec = $args{bartec};

    unless ($bartec) {
        $bartec = $self->feature('bartec');
        $bartec = Integrations::Bartec->new(%$bartec);
    }

    my $suffix_date_parser = DateTime::Format::Strptime->new( pattern => '%d%m%y' );
    my $workpack_dt = $self->_bulky_date_to_dt($date);
    next unless $workpack_dt;

    my $now = DateTime->now( time_zone => FixMyStreet->local_time_zone );
    my $cutoff = $self->_bulky_cancellation_cutoff_date($workpack_dt);
    return 0 if $now > $cutoff;

    my $date_from = $workpack_dt->clone->strftime('%FT%T');
    my $date_to = $workpack_dt->clone->set(
        hour   => 23,
        minute => 59,
        second => 59,
    )->strftime('%FT%T');
    my $workpacks_for_day = $bartec->WorkPacks_Get(
        date_from => $date_from,
        date_to   => $date_to,
    );

    my %jobs_per_uprn;
    for my $wpfd (@$workpacks_for_day) {
        next if $wpfd->{Name} !~ bulky_workpack_name();

        # Ignore workpacks with names with faulty date suffixes
        my $suffix_dt = $suffix_date_parser->parse_datetime( $+{date_suffix} );

        next
            if !$suffix_dt
            || $workpack_dt->date ne $suffix_dt->date;

        my $jobs = $bartec->Jobs_Get_for_workpack( $wpfd->{ID} ) || [];

        # Group jobs by UPRN. For a bulky workpack, a UPRN/premises may
        # have multiple jobs (equivalent to item slots); these all count
        # as a single bulky collection slot.
        $jobs_per_uprn{ $_->{Job}{UPRN} }++ for @$jobs;
    }

    my $total_collection_slots = keys %jobs_per_uprn;

    return $total_collection_slots < $self->bulky_daily_slots;
}

1;
