=head1 NAME

FixMyStreet::Cobrand::Peterborough::Bulky - code specific to the Peterborough cobrand bulky waste collection

=head1 SYNOPSIS

Functions specific to Peterborough bulky waste collections.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Peterborough::Bulky;
use Moo::Role;

use utf8;
use strict;
use warnings;
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

=item * Bulky workpack name is of the form 'Waste-BULKY WASTE-<date>' or
'Waste-WHITES-<date>'

=cut

sub bulky_workpack_name {
    qr/Waste-(BULKY WASTE|WHITES)-(?<date_suffix>\d{6})/;
}

=item * User can cancel bulky collection up to 15:00 before the day of
collection

=cut

sub bulky_cancellation_cutoff_time {
    {   hours   => 15,
        minutes => 0,
    }
}

=item * Bulky collections start at 6:45 each (working) day

=back

=cut

sub bulky_collection_time {
    {   hours   => 6,
        minutes => 45,
    }
}

sub bulky_items_master_list { $_[0]->wasteworks_config->{item_list} || [] }
sub bulky_items_maximum { $_[0]->wasteworks_config->{items_per_collection_max} || 5 }
sub bulky_daily_slots { $_[0]->wasteworks_config->{daily_slots} || 40 }

sub bulky_items_extra {
    my $self = shift;

    my $per_item = $self->bulky_per_item_costs;

    my $json = JSON::MaybeXS->new;
    my %hash;
    for my $item ( @{ $self->bulky_items_master_list } ) {
        $hash{ $item->{name} }{message} = $item->{message} if $item->{message};
        $hash{ $item->{name} }{price} = $item->{price} if $item->{price} && $per_item;
        $hash{ $item->{name} }{max} = $item->{max} if $item->{max};
        $hash{ $item->{name} }{json} = $json->encode($hash{$item->{name}}) if $hash{$item->{name}};
    }
    return \%hash;
}

sub bulky_per_item_costs {
    my $self = shift;
    my $cfg  = $self->body->get_extra_metadata( 'wasteworks_config', {} );
    return $cfg->{per_item_costs};
}

# Should only be a single open collection for a given property, but in case
# there isn't, return the most recent
sub find_pending_bulky_collection {
    my ( $self, $property ) = @_;

    return FixMyStreet::DB->resultset('Problem')->to_body( $self->body )
        ->find(
        {   category => 'Bulky collection',
            extra    => { '@>' => encode_json({ "_fields" => [ { name => 'uprn', value => $property->{uprn} } ] }) },
            state =>
                { '=', [ FixMyStreet::DB::Result::Problem->open_states ] },
        },
        { order_by => { -desc => 'id' } },
        );
}

sub bulky_can_view_collection {
    my ( $self, $p ) = @_;

    my $c = $self->{c};

    # logged out users can't see anything
    return unless $p && $c->user_exists;

    # superusers and staff can see it
    # XXX do we want a permission for this?
    return 1 if $c->user->is_superuser || $c->user->belongs_to_body($self->body->id);

    # otherwise only the person who booked the collection can view
    return $c->user->id == $p->user_id;
}

sub bulky_can_view_cancellation {
    my ( $self, $p ) = @_;

    my $c = $self->{c};

    return unless $p && $c->user_exists;

    # Staff only
    # XXX do we want a permission for this?
    return 1
        if $c->user->is_superuser
        || $c->user->belongs_to_body( $self->body->id );
}

# XXX
# Error handling
# Holidays, bank holidays?
# Monday limit, Tuesday limit etc.?
# Check which bulky collections are pending, open
sub find_available_bulky_slots {
    my ( $self, $property, $last_earlier_date_str ) = @_;

    my $key
        = 'peterborough:bartec:available_bulky_slots:'
        . ( $last_earlier_date_str ? 'later' : 'earlier' ) . ':'
        . $property->{uprn};
    return $self->{c}->session->{$key} if $self->{c}->session->{$key};

    my $bartec = $self->feature('bartec');
    $bartec = Integrations::Bartec->new(%$bartec);

    my $window = _bulky_collection_window($last_earlier_date_str);
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
        push @available_slots => {
            workpack_id => $workpack->{id},
            date        => $workpack->{WorkPackDate},
            }
            if $self->check_bulky_slot_available( $workpack->{WorkPackDate},
            $bartec );

        $last_workpack_date = $workpack->{WorkPackDate};

        # Provision of $last_earlier_date_str implies we want to fetch all
        # remaining available slots in the given window, so we ignore the
        # limit
        last
            if !$last_earlier_date_str
            && @available_slots == max_bulky_collection_dates();
    }

    $self->{c}->session->{$key} = \@available_slots;

    return \@available_slots;
}

# Checks if there is a slot available for a given date
sub check_bulky_slot_available {
    my ( $self, $date, $bartec ) = @_;

    unless ($bartec) {
        $bartec = $self->feature('bartec');
        $bartec = Integrations::Bartec->new(%$bartec);
    }

    my $suffix_date_parser = DateTime::Format::Strptime->new( pattern => '%d%m%y' );
    my $workpack_date_pattern = '%FT%T';
    my $workpack_dt
        = DateTime::Format::Strptime->new( pattern => $workpack_date_pattern )
        ->parse_datetime($date);
    next unless $workpack_dt;

    my $date_from
        = $workpack_dt->clone->set( hour => 0, minute => 0, second => 0 )
        ->strftime($workpack_date_pattern);
    my $date_to = $workpack_dt->clone->set(
        hour   => 23,
        minute => 59,
        second => 59,
    )->strftime($workpack_date_pattern);
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

sub _bulky_collection_window {
    my $last_earlier_date_str = shift;
    my $fmt = '%F';

    my $now = DateTime->now( time_zone => FixMyStreet->local_time_zone );
    my $tomorrow = $now->clone->truncate( to => 'day' )->add( days => 1 );

    my $start_date;
    if ($last_earlier_date_str) {
        $start_date
            = DateTime::Format::Strptime->new( pattern => $fmt )
            ->parse_datetime($last_earlier_date_str);

        return { error => 'Invalid date provided' } unless $start_date;

        $start_date->add( days => 1 );
    } else {
        $start_date = $tomorrow->clone;

        # If now is past cutoff time, push start date one day later
        my $cutoff_time = bulky_cancellation_cutoff_time();
        if ((      $now->hour == $cutoff_time->{hours}
                && $now->minute >= $cutoff_time->{minutes}
            )
            || $now->hour > $cutoff_time->{hours}
        ){
            $start_date->add( days => 1 );
        }
    }

    my $date_to
        = $tomorrow->clone->add( days => bulky_collection_window_days() );

    return {
        date_from => $start_date->strftime($fmt),
        date_to => $date_to->strftime($fmt),
    };
}

# Returns whether a collection can be cancelled, irrespective of logged-in
# user or lack thereof
sub bulky_collection_can_be_cancelled {
    # There is an $ignore_external_id option because we display some
    # cancellation messaging without needing a report in Bartec
    my ( $self, $collection, $ignore_external_id ) = @_;

    return
           $collection
        && $collection->is_open
        && ( $collection->external_id || $ignore_external_id )
        && $self->within_bulky_cancel_window($collection);
}

sub bulky_cancellation_report {
    my ( $self, $collection ) = @_;

    return unless $collection && $collection->external_id;

    my $original_sr_number = $collection->external_id =~ s/Bartec-//r;

    # A cancelled collection will have a corresponding cancellation report
    # linked via external_id / ORIGINAL_SR_NUMBER
    return FixMyStreet::DB->resultset('Problem')->find(
        {   extra => {
                '@>' => encode_json({ _fields => [ { name => 'ORIGINAL_SR_NUMBER', value => $original_sr_number } ] })
            },
        },
    );
}

sub bulky_can_refund {
    my $self = shift;
    my $c    = $self->{c};

    # Skip refund eligibility check for bulky goods soft launch; just
    # assume if a collection can be cancelled, it can be refunded
    # (see https://3.basecamp.com/4020879/buckets/26662378/todos/5870058641)
    return $self->within_bulky_cancel_window
        if $self->bulky_enabled_staff_only;

    return $c->stash->{property}{pending_bulky_collection}
        ->get_extra_field_value('CHARGEABLE') ne 'FREE'
        && $self->within_bulky_refund_window;
}

# A cancellation made less than 24 hours before the collection is scheduled to
# begin is not entitled to a refund.
sub within_bulky_refund_window {
    my $self = shift;
    my $c    = $self->{c};

    my $open_collection = $c->stash->{property}{pending_bulky_collection};
    return 0 unless $open_collection;

    my $now_dt = DateTime->now( time_zone => FixMyStreet->local_time_zone );

    my $collection_date_str = $open_collection->get_extra_field_value('DATE');
    my $collection_dt       = DateTime::Format::Strptime->new(
        pattern   => '%FT%T',
        time_zone => FixMyStreet->local_time_zone,
    )->parse_datetime($collection_date_str);

    return $self->_check_within_bulky_refund_window( $now_dt,
        $collection_dt );
}

sub _check_within_bulky_refund_window {
    my ( undef, $now_dt, $collection_dt ) = @_;

    my $collection_time = bulky_collection_time();
    my $cutoff_dt       = $collection_dt->clone->set(
        hour   => $collection_time->{hours},
        minute => $collection_time->{minutes},
    )->subtract( hours => 24 );

    return $now_dt <= $cutoff_dt;
}

sub within_bulky_cancel_window {
    my ( $self, $collection ) = @_;

    my $c = $self->{c};
    $collection //= $c->stash->{property}{pending_bulky_collection};
    return 0 unless $collection;

    my $now_dt = DateTime->now( time_zone => FixMyStreet->local_time_zone );

    my $collection_date_str = $collection->get_extra_field_value('DATE');
    my $collection_dt       = DateTime::Format::Strptime->new(
        pattern   => '%FT%T',
        time_zone => FixMyStreet->local_time_zone,
    )->parse_datetime($collection_date_str);

    return _check_within_bulky_cancel_window( $now_dt,
        $collection_dt );
}

sub _check_within_bulky_cancel_window {
    my ( $now_dt, $collection_dt ) = @_;
    my $cutoff_dt = _bulky_cancellation_cutoff_date($collection_dt);
    return $now_dt < $cutoff_dt;
}

sub _bulky_cancellation_cutoff_date {
    my $collection_date = shift;
    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T' );
    my $dt
        = $parser->parse_datetime($collection_date)->truncate( to => 'day' );

    my $cutoff_time = bulky_cancellation_cutoff_time();
    $dt->subtract( days => 1 )->set(
        hour   => $cutoff_time->{hours},
        minute => $cutoff_time->{minutes},
    );

    return $dt;
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

    return $saved_data;
}

sub waste_munge_bulky_cancellation_data {
    my ( $self, $data ) = @_;

    my $c = $self->{c};
    my $collection_report = $c->stash->{property}{pending_bulky_collection};

    $data->{title}    = 'Bulky goods cancellation';
    $data->{category} = 'Bulky cancel';
    $data->{detail} .= " | Original report ID: " . $collection_report->id;

    $c->set_param( 'COMMENTS', 'Cancellation at user request' );

    my $original_sr_number = $collection_report->external_id =~ s/Bartec-//r;
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

# For displaying before user books collection. In the case of individually
# priced items, we cannot know what the total cost will be, so we return the
# lowest cost.
sub bulky_minimum_cost {
    my $self = shift;

    my $cfg = $self->wasteworks_config;

    if ( $cfg->{per_item_costs} ) {
        # Get the item with the lowest cost
        my @sorted = sort { $a <=> $b }
            map { $_->{price} } @{ $self->bulky_items_master_list };

        return $sorted[0] // 0;
    } else {
        return $cfg->{base_price} // 0;
    }
}

sub bulky_total_cost {
    my ($self, $data) = @_;
    my $c = $self->{c};

    if ($self->bulky_free_collection_available) {
        $data->{extra_CHARGEABLE} = 'FREE';
        $c->stash->{payment} = 0;
    } else {
        $data->{extra_CHARGEABLE} = 'CHARGED';

        my $cfg = $self->wasteworks_config;
        if ($cfg->{per_item_costs}) {
            my %prices = map { $_->{name} => $_->{price} } @{ $self->bulky_items_master_list };
            my $total = 0;
            for (1..5) {
                my $item = $data->{"item_$_"} or next;
                $total += $prices{$item};
            }
            $c->stash->{payment} = $total;
        } else {
            $c->stash->{payment} = $cfg->{base_price};
        }
        $data->{"extra_payment_method"} = "credit_card";
    }
    return $c->stash->{payment};
}

sub bulky_allowed_property {
    my ($self, $property) = @_;
    return 1 if $property->{show_bulky_waste} && !$property->{commercial_property};
}

sub bulky_enabled {
    my $self = shift;

    # $self->{c} is undefined if this cobrand was instantiated by
    # get_cobrand_handler instead of being the current active cobrand
    # for this request.
    my $c = $self->{c} || FixMyStreet::DB->schema->cobrand->{c};

    my $cfg = $self->feature('waste_features') || {};

    if ($self->bulky_enabled_staff_only) {
        return $c->user_exists && (
            $c->user->is_superuser
            || ( $c->user->from_body && $c->user->from_body->name eq $self->council_name)
        );
    } else {
        return $cfg->{bulky_enabled};
    }
}

sub bulky_enabled_staff_only {
    my $self = shift;

    my $cfg = $self->feature('waste_features') || {};

    return $cfg->{bulky_enabled} && $cfg->{bulky_enabled} eq 'staff';
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

sub bulky_nice_collection_date {
    my ($self, $date) = @_;
    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T' );
    my $dt = $parser->parse_datetime($date)->truncate( to => 'day' );
    return $dt->strftime('%d %B');
}

sub bulky_nice_cancellation_cutoff_time {
    my $time = bulky_cancellation_cutoff_time();
    $time = DateTime->now->set(hour => $time->{hours}, minute => $time->{minutes})->strftime('%I:%M%P');
    $time =~ s/^0|:00//g;
    return $time;
}

sub bulky_nice_cancellation_cutoff_date {
    my ( undef, $collection_date ) = @_;
    my $cutoff_dt = _bulky_cancellation_cutoff_date($collection_date);
    return $cutoff_dt->strftime('%H:%M on %d %B %Y');
}

sub bulky_nice_collection_time {
    my $time = bulky_collection_time();
    $time = DateTime->now->set(hour => $time->{hours}, minute => $time->{minutes})->strftime('%I:%M%P');
    $time =~ s/^0|:00//g;
    return $time;
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

sub bulky_reminders {
    my ($self, $params) = @_;

    # Can't see an easy way to find these apart from loop through them all.
    # Is only daily.
    my $collections = FixMyStreet::DB->resultset('Problem')->search({
        category => 'Bulky collection',
        state => [ FixMyStreet::DB::Result::Problem->open_states ], # XXX?
    });
    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T' );
    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);

    while (my $report = $collections->next) {
        my $r1 = $report->get_extra_metadata('reminder_1');
        my $r3 = $report->get_extra_metadata('reminder_3');
        next if $r1; # No reminders left to do

        my $date = $report->get_extra_field_value('DATE');

        # Shouldn't happen, but better to be safe.
        next unless $date;

        my $dt = $parser->parse_datetime($date)->truncate( to => 'day' );

        # If booking has been cancelled (or somehow the collection date has
        # already passed) then mark this report as done so we don't see it
        # again tomorrow.
        my $cancelled = $self->bulky_cancellation_report($report);
        if ( $cancelled || $dt < $now) {
            $report->set_extra_metadata(reminder_1 => 1);
            $report->set_extra_metadata(reminder_3 => 1);
            $report->update;
            next;
        }

        my $d1 = $dt->clone->subtract(days => 1);
        my $d3 = $dt->clone->subtract(days => 3);

        my $h = {
            report => $report,
            cobrand => $self,
        };

        if (!$r3 && $now >= $d3 && $now < $d1) {
            $h->{days} = 3;
            $self->_bulky_send_reminder_email($report, $h, $params);
            $report->set_extra_metadata(reminder_3 => 1);
            $report->update;
        } elsif ($now >= $d1 && $now < $dt) {
            $h->{days} = 1;
            $self->_bulky_send_reminder_email($report, $h, $params);
            $report->set_extra_metadata(reminder_1 => 1);
            $report->update;
        }
    }
}

sub _bulky_send_reminder_email {
    my ($self, $report, $h, $params) = @_;

    my $token = FixMyStreet::DB->resultset('Token')->new({
        scope => 'email_sign_in',
        data  => {
            # This should be the view your collections page, most likely
            r => $report->url,
        }
    });
    $h->{url} = "/M/" . $token->token;

    my $result = FixMyStreet::Email::send_cron(
        FixMyStreet::DB->schema,
        'waste/bulky-reminder.txt',
        $h,
        { To => [ [ $report->user->email, $report->name ] ] },
        undef,
        $params->{nomail},
        $self,
        $report->lang,
    );
    unless ($result) {
        print "  ...success\n" if $params->{verbose};
        $token->insert();
    } else {
        print " ...failed\n" if $params->{verbose};
    }
}

sub unset_free_bulky_used {
    my $self = shift;

    my $c = $self->{c};

    return
        unless $c->stash->{property}{pending_bulky_collection}
        ->get_extra_field_value('CHARGEABLE') eq 'FREE';

    my $bartec = $self->feature('bartec');
    $bartec = Integrations::Bartec->new(%$bartec);

    # XXX At the time of writing, there does not seem to be a
    # 'FREE BULKY USED' attribute defined in Bartec
    $bartec->delete_premise_attribute( $c->stash->{property}{uprn},
        'FREE BULKY USED' );
}

1;
