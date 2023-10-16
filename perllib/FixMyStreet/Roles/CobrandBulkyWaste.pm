package FixMyStreet::Roles::CobrandBulkyWaste;

use Moo::Role;
use JSON::MaybeXS;
use FixMyStreet::Map;

=head1 NAME

FixMyStreet::Roles::CobrandBulkyWaste - shared code between cobrands that use WasteWorks Bulky waste feature

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

sub bulky_show_individual_notes { $_[0]->wasteworks_config->{show_individual_notes} };

sub bulky_pricing_strategy {
    my $self = shift;
    my $base_price = $self->wasteworks_config->{base_price};
    my $band1_max = $self->wasteworks_config->{band1_max};
    my $max = $self->bulky_items_maximum;
    if ($self->bulky_per_item_costs) {
        my $min_collection_price = $self->wasteworks_config->{per_item_min_collection_price} || 0;
        return encode_json({ strategy => 'per_item', min => $min_collection_price });
    } elsif (my $band1_price = $self->wasteworks_config->{band1_price}) {
        return encode_json({ strategy => 'banded', bands => [ { max => $band1_max, price => $band1_price }, { max => $max, price => $base_price } ] });
    } else {
        return encode_json({ strategy => 'single' });
    }
}

=head2 Requirements

Users of this role must supply the following:
* time up to which cancellation can be made;
* time collections start;
* number of days to look into the future for collection dates
* function to return a report's collection date extra field as a DateTime
* function to return the cancellation cutoff DateTime
* function to return the refund cutoff DateTime
* function to return whether free collection is available

=cut

requires 'bulky_cancellation_cutoff_time';
requires 'bulky_collection_time';
requires 'bulky_collection_window_days';
requires 'collection_date';
requires '_bulky_refund_cutoff_date';
requires 'bulky_free_collection_available';

sub bulky_cancel_by_update { 0 }

sub bulky_is_cancelled {
    my ($self, $p) = @_;
    if ($self->bulky_cancel_by_update) {
        return $p->comments->find({ extra => { '@>' => '{"bulky_cancellation":1}' } });
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

    if ( $cfg->{per_item_costs} ) {

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
        if ($cfg->{per_item_costs}) {
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
        $data->{"extra_payment_method"} = "credit_card";
    }
    return $c->stash->{payment};
}

sub find_unconfirmed_bulky_collections {
    my ( $self, $uprn ) = @_;

    return $self->problems->search({
        category => 'Bulky collection',
        extra => { '@>' => encode_json({ "_fields" => [ { name => 'uprn', value => $uprn } ] }) },
        state => 'unconfirmed',
    }, {
        order_by => { -desc => 'id' }
    });
}

sub find_pending_bulky_collections {
    my ( $self, $uprn ) = @_;

    return $self->problems->search({
        category => ['Bulky collection', 'Small items collection'],
        extra => { '@>' => encode_json({ "_fields" => [ { name => 'uprn', value => $uprn } ] }) },
        state => [ FixMyStreet::DB::Result::Problem->open_states ],
    }, {
        order_by => { -desc => 'id' }
    });
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
        $start_date = $tomorrow->clone;

        # If now is past cutoff time, push start date one day later
        my $cutoff_time = $self->bulky_cancellation_cutoff_time();
        if ((      $now->hour == $cutoff_time->{hours}
                && $now->minute >= $cutoff_time->{minutes}
            )
            || $now->hour > $cutoff_time->{hours}
        ){
            $start_date->add( days => 1 );
        }
    }

    my $date_to
        = $tomorrow->clone->add( days => $self->bulky_collection_window_days() );

    return {
        date_from => $start_date->strftime($fmt),
        date_to => $date_to->strftime($fmt),
    };
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
    my $c = $self->{c};
    return unless $c->user_exists;

    my $cfg = $self->feature('waste_features') || {};
    return unless $cfg->{bulky_amend_enabled};

    my $can_be = $self->bulky_collection_can_be_amended($p);
    if ($cfg->{bulky_amend_enabled} eq 'staff') {
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
    my $now_dt = DateTime->now( time_zone => FixMyStreet->local_time_zone );
    my $collection_date = $self->collection_date($collection);
    return $self->_check_within_bulky_amend_window($now_dt, $collection_date);
}

sub _check_within_bulky_amend_window {
    my ( $self, $now_dt, $collection_date ) = @_;
    my $cutoff_dt = $self->_bulky_amendment_cutoff_date($collection_date);
    return $now_dt < $cutoff_dt;
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

    my $now_dt = DateTime->now( time_zone => FixMyStreet->local_time_zone );
    my $collection_date = $self->collection_date($collection);
    return $self->_check_within_bulky_cancel_window($now_dt, $collection_date);
}

sub _check_within_bulky_cancel_window {
    my ( $self, $now_dt, $collection_date ) = @_;
    my $cutoff_dt = $self->_bulky_cancellation_cutoff_date($collection_date);
    return $now_dt < $cutoff_dt;
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
    my ($self, $open_collection) = @_;

    my $now_dt = DateTime->now( time_zone => FixMyStreet->local_time_zone );
    my $collection_dt = $self->collection_date($open_collection);
    return $self->_check_within_bulky_refund_window($now_dt, $collection_dt);
}

sub _check_within_bulky_refund_window {
    my ( $self, $now_dt, $collection_dt ) = @_;
    my $cutoff_dt = $self->_bulky_refund_cutoff_date($collection_dt);
    return $now_dt <= $cutoff_dt;
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
    return $dt->strftime('%d %B');
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
    my $cutoff_time = $self->bulky_cancellation_cutoff_time();
    my $days_before = $cutoff_time->{days_before} || 1;
    my $dt = $collection_date->clone->subtract( days => $days_before )->set(
        hour   => $cutoff_time->{hours},
        minute => $cutoff_time->{minutes},
    );
    return $dt;
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

sub bulky_send_before_payment { 0 }

sub bulky_per_item_pricing_property_types { [] }

sub bulky_per_item_price_key {
    my $self = shift;
    return 'price' if !@{$self->bulky_per_item_pricing_property_types};
    my $property = $self->{c}->stash->{property};
    return "price_" . $property->{pricing_property_type};
}

1;
