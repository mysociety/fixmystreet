package FixMyStreet::Roles::Cobrand::BulkyWaste;

use Moo::Role;
use JSON::MaybeXS;
use FixMyStreet::Map;
use List::Util qw(max);

=head1 NAME

FixMyStreet::Roles::Cobrand::BulkyWaste - shared code between cobrands that use WasteWorks Bulky waste feature

=head2 bulky_enabled

Whether the bulky goods functionality is enabled for this cobrand.
Reads from the waste_features configuration.

=cut

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

sub bulky_items_master_list { $_[0]->wasteworks_config->{item_list} || [] }
sub bulky_items_maximum { $_[0]->wasteworks_config->{items_per_collection_max} || 5 }
sub bulky_per_item_costs { $_[0]->wasteworks_config->{per_item_costs} }
sub bulky_tandc_link {
    my $self = shift;
    my $cfg = $self->feature('waste_features') || {};
    return FixMyStreet::Template::SafeString->new($cfg->{bulky_tandc_link});
}
sub bulky_show_location_page {
    my ($self) = @_;

    if (my $permission = $_[0]->wasteworks_config->{show_location_page}) {
        if ($permission eq 'staff') {
            if ($self->{c}->stash->{is_staff}) {
                return 1;
            }
        } elsif ($permission eq 'users') {
            return 1;
        }
    }
};
sub bulky_show_location_field_mandatory { 0 }

sub bulky_item_notes_field_mandatory { 0 }

sub bulky_show_individual_notes { $_[0]->wasteworks_config->{show_individual_notes} };

sub bulky_points_per_item_pricing { 0 }

sub bulky_pricing_strategy {
    my $self = shift;
    my $base_price = $self->wasteworks_config->{base_price};
    my $band1_max = $self->wasteworks_config->{band1_max};
    if ($self->bulky_points_per_item_pricing) {
        my $data = $self->{c}->stash->{form}->saved_data;
        my $points = $self->bulky_pricing_model($data);
        return encode_json({ strategy => 'points', points => $points });
    } elsif ($self->bulky_per_item_costs) {
        my $min_collection_price = $self->wasteworks_config->{per_item_min_collection_price} || 0;
        return encode_json({ strategy => 'per_item', min => $min_collection_price });
    } elsif (my $band1_price = $self->wasteworks_config->{band1_price}) {
        my $max = $self->bulky_items_maximum;
        return encode_json({ strategy => 'banded', bands => [ { max => $band1_max, price => $band1_price }, { max => $max, price => $base_price } ] });
    } else {
        return encode_json({ strategy => 'single' });
    }
}

=head2 Requirements

Users of this role must supply the following:
* whether bulky collections are allowed for a particular property or not;
* time up to which cancellation can be made;
* time collections start;
* number of days to look into the future for collection dates
* function to return a report's collection date extra field as a DateTime
* function to return whether free collection is available

=cut

requires 'bulky_allowed_property';
requires 'bulky_cancellation_cutoff_time';
requires 'bulky_collection_time';
requires 'bulky_collection_window_days';
requires 'collection_date';
requires 'bulky_free_collection_available';

sub bulky_cancel_by_update { 0 }

sub bulky_is_cancelled {
    my ($self, $p, $state) = @_;
    $state ||= 'confirmed';
    if ($self->bulky_cancel_by_update) {
        return $p->comments->find({ state => $state, extra => { '@>' => '{"bulky_cancellation":1}' } });
    } else {
        return $self->bulky_cancellation_report($p);
    }
}

sub bulky_items_extra {
    my ($self, %args) = @_;

    my $per_item = '';
    my $price_key = '';
    unless ($args{exclude_pricing}) {
        $per_item = $self->bulky_per_item_costs;
        $price_key = $self->bulky_per_item_price_key;
    };

    my $json = JSON::MaybeXS->new;
    my %hash;
    for my $item ( @{ $self->bulky_items_master_list } ) {
        $hash{ $item->{name} }{message} = $item->{message} if $item->{message};
        $hash{ $item->{name} }{price} = $item->{$price_key} if $item->{$price_key} && $per_item;
        $hash{ $item->{name} }{points} = $item->{points} if $item->{points};
        $hash{ $item->{name} }{max} = $item->{max} if $item->{max};
        $hash{ $item->{name} }{json} = $json->encode($hash{$item->{name}}) if $hash{$item->{name}};
    }
    return \%hash;
}

# For displaying before user books collection. In the case of individually
# priced items, we cannot know what the total cost will be, so we return the
# lowest cost.
sub bulky_minimum_cost {
    my $self = shift;

    my $cfg = $self->wasteworks_config;

    if ($self->bulky_points_per_item_pricing) {
        return $cfg->{per_item_min_collection_price};
    } elsif ( $cfg->{per_item_costs} ) {

        my $price_key = $self->bulky_per_item_price_key;
        # Get the item with the lowest cost
        my @sorted = sort { $a <=> $b }
            map { $_->{$price_key} } @{ $self->bulky_items_master_list };
        my $min_item_price =  $sorted[0] // 0;
        my $min_collection_price = $cfg->{per_item_min_collection_price};
        if ($min_collection_price && $min_collection_price > $min_item_price) {
            return $min_collection_price;
        }
        return $min_item_price;

    } elsif ( $cfg->{band1_price} ) {
        return $cfg->{band1_price};
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
        if ($self->bulky_points_per_item_pricing) {
            my $points = $self->bulky_item_points_total($data);
            my $levels = $self->bulky_pricing_model($data);
            my $total = $self->bulky_points_to_price($points, $levels);
            if ($total eq 'max') {
                # Shouldn't ever reach here! Set stupid price
                $total = 999_999_999;
            }
            $c->stash->{payment} = $total;
        } elsif ($cfg->{per_item_costs}) {
            my $price_key = $self->bulky_per_item_price_key;
            my %prices = map { $_->{name} => $_->{$price_key} } @{ $self->bulky_items_master_list };
            my $total = 0;
            my $max = $self->bulky_items_maximum;
            for (1..$max) {
                my $item = $data->{"item_$_"} or next;
                $total += $prices{$item};
            }
            my $min_collection_price = $cfg->{per_item_min_collection_price};
            if ($min_collection_price && $min_collection_price > $total) {
                $c->stash->{payment} = $min_collection_price;
            } else {
                $c->stash->{payment} = $total;
            }
        } elsif ($cfg->{band1_price}) {
            my $count = 0;
            my $max = $self->bulky_items_maximum;
            for (1..$max) {
                my $item = $data->{"item_$_"} or next;
                $count++;
            }
            if ($count <= $cfg->{band1_max}) {
                $c->stash->{payment} = $cfg->{band1_price};
            } else {
                $c->stash->{payment} = $cfg->{base_price};
            }
        } else {
            $c->stash->{payment} = $cfg->{base_price};
        }
    }

    # Calculate the difference in cost for this booking compared to the whatever
    # the user may have already paid for any previous versions of this booking.
    my $previous = $c->stash->{amending_booking};
    my $already_paid;
    if ($previous && $c->stash->{payment}) {
        $already_paid = $self->get_total_paid($previous);
        my $new_cost = $c->stash->{payment} - $already_paid;
        # no refunds if they've already paid more than the new booking would cost
        $c->stash->{payment} = max(0, $new_cost);
    }
    return {
        amount => $c->stash->{payment},
        already_paid => $already_paid,
    }
}

=head2 get_total_paid

Recursively calculate the total amount paid for a booking and any previous
versions of it.

=cut

sub get_total_paid {
    my ($self, $previous) = @_;

    return 0 unless $previous;

    my $total = $previous->get_extra_field_value('payment') || 0;

    if ($previous->get_extra_metadata('previous_booking_id')) {
        my $previous_id = $previous->get_extra_metadata('previous_booking_id');
        my $previous_report = FixMyStreet::DB->schema->resultset('Problem')->find($previous_id);
        $total += $self->get_total_paid($previous_report);
    }

    return $total;
}

=head2 get_all_payments

Recursively locate the payments made.

=cut

sub get_all_payments {
    my ($self, $p, $refs) = @_;

    return $refs unless $p;

    my $payment = $p->get_extra_field_value('payment') || 0;
    $payment = sprintf( '%.2f', $payment / 100 );
    my $ref = $p->get_extra_metadata('chequeReference') || $p->get_extra_metadata('payment_reference') || '';
    push @$refs, { ref => $ref, amount => $payment };

    if (my $previous_id = $p->get_extra_metadata('previous_booking_id')) {
        my $previous = FixMyStreet::DB->schema->resultset('Problem')->find($previous_id);
        $self->get_all_payments($previous, $refs)
    }

    return $refs;
}

sub find_unconfirmed_bulky_collections {
    my ( $self, $uprn ) = @_;

    return $self->problems->search({
        category => 'Bulky collection',
        extra => { '@>' => encode_json({ "_fields" => [ { name => 'uprn', value => $uprn } ] }) },
        state => 'unconfirmed',
    })->order_by('-id');
}

sub find_pending_bulky_collections {
    my ( $self, $uprn ) = @_;

    my $rs = $self->problems->search({
        category => ['Bulky collection', 'Small items collection'],
        extra => { '@>' => encode_json({ "_fields" => [ { name => 'uprn', value => $uprn } ] }) },
        state => [ FixMyStreet::DB::Result::Problem->open_states ],
    })->order_by('-id');

    return wantarray ? $self->_recently($rs) : $rs;
}

sub find_recent_bulky_collections {
    my ( $self, $uprn ) = @_;

    my @closed = grep { $_ ne 'cancelled' } FixMyStreet::DB::Result::Problem->closed_states;
    my $rs = $self->problems->search({
        category => ['Bulky collection', 'Small items collection'],
        extra => { '@>' => encode_json({ "_fields" => [ { name => 'uprn', value => $uprn } ] }) },
        state => [ @closed, FixMyStreet::DB::Result::Problem->fixed_states ],
    })->order_by('-id');

    return wantarray ? $self->_recently($rs) : $rs;
}

sub _recently {
    my ($self, $rs) = @_;

    # If we've already sent it, and we want a full list for display, we don't
    # want to show ones without a reference
    if ($self->bulky_send_before_payment) {
        $rs = $rs->search({
            extra => { '\?' => [ 'payment_reference', 'chequeReference' ] },
        });
    }

    my $dt = DateTime->now( time_zone => FixMyStreet->local_time_zone )->truncate( to => 'day' )->subtract ( days => 10 );
    my @all = $rs->all;
    @all = grep { my $date = $self->collection_date($_); $date >= $dt } @all;
    return @all;
}

sub _bulky_collection_window {
    my ($self, $last_earlier_date_str) = @_;
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
        my $now = DateTime->now( time_zone => FixMyStreet->local_time_zone );
        $start_date = $self->bulky_collection_window_start_date($now);
    }

    my $date_to
        = $tomorrow->clone->add( days => $self->bulky_collection_window_days() );

    return {
        date_from => $start_date->strftime($fmt),
        date_to => $date_to->strftime($fmt),
    };
}

=head2 bulky_collection_window_start_date

This should return the start date when looking for a collection window.
It defaults to tomorrow, adjusted by the cancellation cut-off days (eg.
if cancellation is by 7am the day before collection, the start date
will be one day later than tomorrow after 7am).

=cut

sub bulky_collection_window_start_date {
    my ($self, $now) = @_;
    my $start_date = $now->clone->truncate( to => 'day' );

    # If now is past cutoff time, push start date one day later
    my $cutoff_time = $self->bulky_cancellation_cutoff_time();
    my $days_before = $cutoff_time->{days_before} // 1;
    my $cutoff_date = $self->_bulky_cancellation_cutoff_date($now);
    my $cutoff_date_now = $cutoff_date->clone->set( hour => $now->hour, minute => $now->minute );

    if (!$cutoff_time->{working_days}) {
        if ($cutoff_date_now >= $cutoff_date) {
            $start_date->add( days => 1 );
        }
        $start_date->add( days => $days_before );
    } else {
        my $wd = FixMyStreet::WorkingDays->new(
            public_holidays => FixMyStreet::Cobrand::UK::public_holidays(),
        );
        if ($cutoff_date_now >= $cutoff_date || $wd->is_non_working_day($start_date)) {
            $start_date = $wd->add_days($start_date, 1);
        }
        $start_date = $wd->add_days($start_date, $days_before);
    }

    return $start_date;
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

sub bulky_can_amend_collection {
    my ( $self, $p ) = @_;
    return unless $self->bulky_can_view_collection($p);

    my $cfg = $self->feature('waste_features') || {};
    return unless $cfg->{bulky_amend_enabled};

    my $can_be = $self->bulky_collection_can_be_amended($p);
    if ($cfg->{bulky_amend_enabled} eq 'staff') {
        my $c = $self->{c};
        my $staff = $c->user->is_superuser || $c->user->belongs_to_body($self->body->id);
        return $can_be && $staff;
    }
    return $can_be;
}

sub bulky_collection_can_be_amended {
    my ( $self, $collection, $ignore_external_id ) = @_;
    return
           $collection
        && $collection->is_open
        && ( $collection->external_id || $ignore_external_id )
        && $self->within_bulky_amend_window($collection);
}

sub within_bulky_amend_window {
    my ( $self, $collection ) = @_;
    return $self->_bulky_within_a_window($collection, 'amendment');
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

=head2 bulky_cancel_enabled

Returns the configuration entry of the same name, defaulting to 'public'
if undefined. Config should be one of 'none', 'staff', 'public'.

=cut

sub bulky_cancel_enabled {
    my $self = shift;
    my $cfg = $self->feature('waste_features') || {};
    return $cfg->{bulky_cancel_enabled} // 'public';
}

=head2 bulky_can_cancel_collection REPORT IGNORE_EXTERNAL_ID

Returns boolean of whether a particular collection can be cancelled or not.
It combines the conditions on the collection itself with the current user's
status if required.

=cut

# Cancel is on by default, but config can turn off or make staff-only
sub bulky_can_cancel_collection {
    my ( $self, $p, $ignore_external_id ) = @_;
    return unless $self->bulky_can_view_collection($p);

    my $enabled = $self->bulky_cancel_enabled;
    return unless $enabled eq 'staff' || $enabled eq 'public';

    my $can_be = $self->bulky_collection_can_be_cancelled($p, $ignore_external_id);
    if ($enabled eq 'staff') {
        my $c = $self->{c};
        my $staff = $c->user->is_superuser || $c->user->belongs_to_body($self->body->id);
        return $can_be && $staff;
    }
    return $can_be;
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

sub within_bulky_cancel_window {
    my ( $self, $collection ) = @_;
    return $self->_bulky_within_a_window($collection, 'cancellation');
}

sub bulky_can_refund {
    my ($self, $p) = @_;
    return 1 unless $p;
    return $self->bulky_can_refund_collection($p);
}

sub bulky_can_refund_collection {
    my ($self, $p) = @_;
    return $self->within_bulky_refund_window($p);
}

sub within_bulky_refund_window {
    my ($self, $collection) = @_;
    return $self->_bulky_within_a_window($collection, 'refund');
}

sub _bulky_refund_cutoff_date {
    my ($self, $collection_date) = @_;
    return _bulky_time_object_to_datetime($collection_date, $self->bulky_refund_cutoff_time());
}

sub bulky_nice_collection_date {
    my ($self, $report_or_date) = @_;

    my $dt = do {
        if (ref $report_or_date eq 'FixMyStreet::DB::Result::Problem') {
            $self->collection_date($report_or_date);
        } else {
            $self->_bulky_date_to_dt($report_or_date);
        }
    };

    return $dt->strftime('%A %d %B %Y');
}

sub bulky_nice_collection_time {
    my $self = shift;
    my $time = $self->bulky_collection_time();
    $time = DateTime->now->set(hour => $time->{hours}, minute => $time->{minutes})->strftime('%I:%M%P');
    $time =~ s/^0|:00//g;
    return $time;
}

sub bulky_nice_cancellation_cutoff_date {
    my ( $self, $collection_date ) = @_;
    my $dt = $self->_bulky_date_to_dt($collection_date);
    my $cutoff_dt = $self->_bulky_cancellation_cutoff_date($dt);
    return $cutoff_dt->strftime('%H:%M on %d %B %Y');
}

sub bulky_nice_cancellation_cutoff_time {
    my $self = shift;
    my $time = $self->bulky_cancellation_cutoff_time();
    $time = DateTime->now->set(hour => $time->{hours}, minute => $time->{minutes})->strftime('%I:%M%P');
    $time =~ s/^0|:00//g;
    return $time;
}

sub _bulky_cancellation_cutoff_date {
    my ($self, $collection_date) = @_;
    return _bulky_time_object_to_datetime($collection_date, $self->bulky_cancellation_cutoff_time());
}

sub bulky_reminders {
    my ($self, $params) = @_;

    FixMyStreet::Map::set_map_class($self->moniker);
    # Can't see an easy way to find these apart from loop through them all.
    # Is only daily.
    my $collections = $self->problems->search({
        category => ['Bulky collection', 'Small items collection'],
        state => [ FixMyStreet::DB::Result::Problem->open_states ], # XXX?
    });

    # If we haven't had payment, we don't want to send a reminder
    if ($self->bulky_send_before_payment) {
        $collections = $collections->search({
            extra => { '\?' => [ 'payment_reference', 'chequeReference' ] },
        });
    }

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);

    while (my $report = $collections->next) {
        my $r1 = $report->get_extra_metadata('reminder_1');
        my $r3 = $report->get_extra_metadata('reminder_3');
        next if $r1; # No reminders left to do

        my $dt = $self->collection_date($report);

        # Shouldn't happen, but better to be safe.
        next unless $dt;

        # If booking has been cancelled (or somehow the collection date has
        # already passed) then mark this report as done so we don't see it
        # again tomorrow.
        my $cancelled = $self->bulky_is_cancelled($report);
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

    return unless $report->user->email;

    return if $self->moniker eq 'bexley' && $h->{days} == 3; # No 3 day reminder

    $h->{url} = $self->base_url_for_report($report) . $report->tokenised_url($report->user);

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
    } else {
        print " ...failed\n" if $params->{verbose};
    }
}

sub bulky_send_before_payment { 0 }

sub bulky_per_item_pricing_property_types { [] }

sub bulky_per_item_price_key {
    my $self = shift;
    return 'price' if !@{$self->bulky_per_item_pricing_property_types};
    my $property = $self->{c}->stash->{property};
    return "price_" . $property->{pricing_property_type};
}

sub bulky_location_text_prompt {
  "Please provide the exact location where the items will be left ".
  "(e.g., On the driveway; To the left of the front door; By the front hedge, etc.)."
}

sub bulky_disabled_item_photos { 0 }
sub bulky_disabled_location_photo { 0 }

sub bulky_location_photo_prompt {
    my $self = shift;
    'Please check the <a href="' . $self->call_hook('bulky_tandc_link') . '" target="_blank">Terms & Conditions</a> for information about when and where to leave your items for collection.' . "\n\n\n"
        . 'Help us by attaching a photo of where the items will be left for collection.';
}

=item * Bulky collections can be amended up to a configurable time on the day before the day of collection

This defaults to 2PM.

=back

=cut

sub bulky_amendment_cutoff_time {
    my $time = $_[0]->wasteworks_config->{amendment_cutoff_time} || "14:00";
    my ($hours, $minutes) = split /:/, $time;
    return { hours => $hours, minutes => $minutes };
}

sub _bulky_amendment_cutoff_date {
    my ($self, $collection_date) = @_;
    return _bulky_time_object_to_datetime($collection_date, $self->bulky_amendment_cutoff_time());
}

sub _bulky_within_a_window {
    my ($self, $collection, $cutoff_fn) = @_;
    my $now_dt = DateTime->now( time_zone => FixMyStreet->local_time_zone );
    my $collection_date = $self->collection_date($collection);
    return $self->_bulky_check_within_a_window($now_dt, $collection_date, $cutoff_fn);
}

sub _bulky_check_within_a_window {
    my ( $self, $now_dt, $collection_date, $cutoff_fn ) = @_;
    $cutoff_fn = "_bulky_${cutoff_fn}_cutoff_date";
    my $cutoff_dt = $self->$cutoff_fn($collection_date);
    return $now_dt < $cutoff_dt;
}

sub _bulky_time_object_to_datetime {
    my ($collection_date, $time) = @_;
    my $days_before = $time->{days_before} // 1;
    my $dt = $collection_date->clone->set(
        hour   => $time->{hours},
        minute => $time->{minutes},
    );
    if ($time->{working_days}) {
        my $wd = FixMyStreet::WorkingDays->new(
            public_holidays => FixMyStreet::Cobrand::UK::public_holidays(),
        );
        $dt = $wd->sub_days($dt, $days_before);
    } else {
        $dt->subtract(days => $days_before);
    }

    return $dt;
}

sub bulky_cancel_no_payment_minutes {
    my $self = shift;
    $self->feature('waste_features')->{bulky_cancel_no_payment_minutes};
}

sub cancel_bulky_collections_without_payment {
    my ($self, $params) = @_;

    # Allow 30 minutes for payment before cancelling the booking.
    my $dtf = FixMyStreet::DB->schema->storage->datetime_parser;
    my $cutoff_date = $dtf->format_datetime( DateTime->now->subtract( minutes => $self->bulky_cancel_no_payment_minutes ) );

    my $rs = $self->problems->search(
        {   category => 'Bulky collection',
            created  => { '<'  => $cutoff_date },
            external_id => { '!=', undef },
            state => [ FixMyStreet::DB::Result::Problem->open_states ],
            -not => { extra => { '@>' => '{"contributed_as":"another_user"}' } },
            -or => [
                extra => undef,
                -not => { extra => { '\?' => 'payment_reference' } }
            ],
        },
    );

    while ( my $report = $rs->next ) {
        my $scp_reference = $report->get_extra_metadata('scpReference');
        if ($scp_reference) {

            # Double check whether the payment was made.
            my ($error, $reference) = $self->cc_check_payment_and_update($scp_reference, $report);
            if (!$error) {
                if ($params->{verbose}) {
                    printf(
                        'Booking %s for report %d was found to be paid (reference %s).' .
                        ' Updating with payment information and not cancelling.',
                        $report->external_id,
                        $report->id,
                        $reference,
                    );
                }
                if ($params->{commit}) {
                    $report->waste_confirm_payment($reference);
                }
                next;
            }
        }

        if ($params->{commit}) {
            $report->add_to_comments({
                text => 'Booking cancelled since payment was not made in time',
                user_id => $self->body->comment_user_id,
                extra => { bulky_cancellation => 1 },
            });
            $report->state('cancelled');
            $report->detail(
                $report->detail . " | Cancelled since payment was not made in time"
            );
            $report->update;
        }
        if ($params->{verbose}) {
            printf(
                'Cancelled booking %s for report %d.',
                $report->external_id,
                $report->id,
            );
        }
    }
}

1;
