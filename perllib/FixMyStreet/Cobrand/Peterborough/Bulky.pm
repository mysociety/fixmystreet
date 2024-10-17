=head1 NAME

FixMyStreet::Cobrand::Peterborough::Bulky - code specific to the Peterborough cobrand bulky waste collection

=head1 SYNOPSIS

Functions specific to Peterborough bulky waste collections.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Peterborough::Bulky;
use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::BulkyWaste';

use utf8;
use DateTime;
use DateTime::Format::Strptime;
use FixMyStreet;
use Integrations::Bartec;
use JSON::MaybeXS;
use FixMyStreet::Email;

=head3 Defaults & constants for bulky waste

=over 4

=item * We search for available bulky collection dates 56 days into the future

=cut

sub bulky_collection_window_days     {56}

=item * We return a maximum of 2 date options to users when they are booking
a bulky waste collection

=cut

sub max_bulky_collection_dates       {2}

=item * Max length of location details text is 250 characters

=cut

sub bulky_location_max_length {250}

=item * Bulky workpack name is of the form 'Waste-BULKY WASTE-<date>' or
'Waste-WHITES-<date>'

=cut

sub bulky_workpack_name {
    qr/Waste-(BULKY WASTE|WHITES)-(?<date_suffix>\d{6})/;
}

=item * User can amend/refund/cancel up to 14:00 the working day before the bulky collection

=cut

sub bulky_cancellation_cutoff_time { { hours => 14, minutes => 0, working_days => 1 } }
sub bulky_amendment_cutoff_time { { hours => 14, minutes => 0, working_days => 1 } }
sub bulky_refund_cutoff_time { { hours => 14, minutes => 0, working_days => 1 } }

=item * Bulky collections start at 6:45 each (working) day

=cut

sub bulky_collection_time { { hours => 6, minutes => 45 } }

sub bulky_daily_slots { $_[0]->wasteworks_config->{daily_slots} || 40 }

# XXX
# Error handling
# Holidays, bank holidays?
# Monday limit, Tuesday limit etc.?
# Check which bulky collections are pending, open
sub find_available_bulky_slots {
    my ( $self, $property, $last_earlier_date_str ) = @_;
    my $c = $self->{c};

    my $key
        = 'peterborough:bartec:available_bulky_slots:'
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
        if ($self->check_bulky_slot_available($workpack->{WorkPackDate}, bartec => $bartec)) {
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

sub collection_date {
    my ($self, $p) = @_;
    return $self->_bulky_date_to_dt($p->get_extra_field_value('DATE'));
}

sub _bulky_date_to_dt {
    my ($self, $date) = @_;
    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T', time_zone => FixMyStreet->local_time_zone);
    my $dt = $parser->parse_datetime($date);
    return $dt ? $dt->truncate( to => 'day' ) : undef;
}

# Checks if there is a slot available for a given date
sub check_bulky_slot_available {
    my ( $self, $date, %args ) = @_;

    my $bartec = $args{bartec};

    unless ($bartec) {
        $bartec = $self->feature('bartec');
        $bartec = Integrations::Bartec->new(%$bartec);
    }

    my $suffix_date_parser = DateTime::Format::Strptime->new( pattern => '%d%m%y' );
    my $workpack_dt = $self->_bulky_date_to_dt($date);
    next unless $workpack_dt;

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

sub bulky_cancellation_report {
    my ( $self, $collection ) = @_;

    return unless $collection && $collection->external_id;

    my $original_sr_number = $collection->external_id =~ s/Bartec-//r;

    # A cancelled collection will have a corresponding cancellation report
    # linked via external_id / ORIGINAL_SR_NUMBER
    return $self->problems->find({
        category => 'Bulky cancel',
        extra => {
            '@>' => encode_json({ _fields => [ { name => 'ORIGINAL_SR_NUMBER', value => $original_sr_number } ] })
        },
    });
}

sub bulky_can_refund_collection {
    my ($self, $p) = @_;
    my $c    = $self->{c};

    # Skip refund eligibility check for bulky goods soft launch; just
    # assume if a collection can be cancelled, it can be refunded
    # (see https://3.basecamp.com/4020879/buckets/26662378/todos/5870058641)
    return $self->within_bulky_cancel_window($p)
        if $self->bulky_enabled_staff_only;

    return $p->get_extra_field_value('CHARGEABLE') ne 'FREE'
        && $self->within_bulky_refund_window($p);
}

sub waste_munge_bulky_data {
    my ($self, $data) = @_;

    my $c = $self->{c};

    $data->{title} = "Bulky goods collection";
    $data->{detail} = "Address: " . $c->stash->{property}->{address};
    $data->{category} = "Bulky collection";
    $data->{extra_DATE} = $data->{chosen_date};

    my $max = $self->bulky_items_maximum;
    for (1..$max) {
        my $two = sprintf("%02d", $_);
        $data->{"extra_ITEM_$two"} = $data->{"item_$_"};
    }

    $self->bulky_total_cost($data);

    $data->{"extra_CREW NOTES"} = $data->{location};
}

sub waste_reconstruct_bulky_data {
    my ($self, $p) = @_;

    my $saved_data = {
        "chosen_date" => $p->get_extra_field_value('DATE'),
        "location" => $p->get_extra_field_value('CREW NOTES'),
        "location_photo" => $p->get_extra_metadata("location_photo"),
    };
    my @fields = grep { $_->{name} =~ /ITEM_/ } @{$p->get_extra_fields};
    foreach (@fields) {
        my ($id) = $_->{name} =~ /ITEM_(\d+)/;
        $saved_data->{"item_" . ($id+0)} = $_->{value};
        $saved_data->{"item_photo_" . ($id+0)} = $p->get_extra_metadata("item_photo_" . ($id+0));
    }

    $saved_data->{name} = $p->name;
    $saved_data->{email} = $p->user->email;
    $saved_data->{phone} = $p->phone_waste;
    $saved_data->{resident} = 'Yes';

    return $saved_data;
}

sub waste_munge_bulky_amend {
    my ($self, $p, $data) = @_;
    $p->update_extra_field({ name => 'DATE', value => $data->{chosen_date} });
    $p->update_extra_field({ name => 'CREW NOTES', value => $data->{location} });

    my $max = $self->{c}->cobrand->bulky_items_maximum;
    for (1..$max) {
        my $two = sprintf("%02d", $_);
        $p->update_extra_field({ name => "ITEM_$two", value => $data->{"item_$_"} || '' });
    }
}

sub waste_munge_bulky_cancellation_data {
    my ( $self, $data ) = @_;

    my $c = $self->{c};
    my $collection_report = $c->stash->{cancelling_booking} || $c->stash->{amending_booking};
    my $original_sr_number = $collection_report->external_id =~ s/Bartec-//r;

    $data->{title}    = 'Bulky goods cancellation';
    $data->{category} = 'Bulky cancel';
    $data->{detail} .= " | Original report ID: $original_sr_number (WasteWorks " . $collection_report->id . ")";

    $c->set_param( 'COMMENTS', 'Cancellation at user request' );
    $c->set_param( 'ORIGINAL_SR_NUMBER', $original_sr_number );
}

sub bulky_free_collection_available {
    my $self = shift;
    my $c = $self->{c};

    my $cfg = $self->wasteworks_config;

    my $attributes = $c->stash->{property}->{attributes};
    my $free_collection_available = !$attributes->{'FREE BULKY USED'};

    return $cfg->{free_mode} && $free_collection_available;
}

sub bulky_allowed_property {
    my ($self, $property) = @_;

    return
           $self->bulky_enabled
        && $property->{has_black_bin}
        && !$property->{commercial_property};
}

sub bulky_available_feature_types {
    my $self = shift;

    return unless $self->bulky_enabled;

    my $cfg = $self->feature('bartec');
    my $bartec = Integrations::Bartec->new(%$cfg);
    my @types = @{ $bartec->Features_Types_Get() };

    # Limit to the feature types that are for bulky waste
    my $waste_cfg = $self->body->get_extra_metadata("wasteworks_config", {});
    if ( my $classes = $waste_cfg->{bulky_feature_classes} ) {
        my %classes = map { $_ => 1 } @$classes;
        @types = grep { $classes{$_->{FeatureClass}->{ID}} } @types;
    }
    return { map { $_->{ID} => $_->{Name} } @types };
}

sub bulky_nice_item_list {
    my ($self, $report) = @_;

    my @fields = grep { $_->{value} && $_->{name} =~ /ITEM_/ } @{$report->get_extra_fields};

    my $items_extra = $self->bulky_items_extra;

    return [
        map {
            value       => $_->{value},
            message     => $items_extra->{ $_->{value} }{message},
        },
        @fields,
    ];
}

sub unset_free_bulky_used {
    my $self = shift;

    my $c = $self->{c};

    return
        unless $c->stash->{cancelling_booking}
        ->get_extra_field_value('CHARGEABLE') eq 'FREE';

    my $bartec = $self->feature('bartec');
    $bartec = Integrations::Bartec->new(%$bartec);

    # XXX At the time of writing, there does not seem to be a
    # 'FREE BULKY USED' attribute defined in Bartec
    $bartec->delete_premise_attribute( $c->stash->{property}{uprn},
        'FREE BULKY USED' );
}

1;
