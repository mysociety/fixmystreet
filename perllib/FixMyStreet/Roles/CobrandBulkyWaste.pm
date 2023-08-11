package FixMyStreet::Roles::CobrandBulkyWaste;

use Moo::Role;
use JSON::MaybeXS;

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
requires '_bulky_cancellation_cutoff_date';
requires '_bulky_refund_cutoff_date';
requires 'bulky_free_collection_available';

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
            my $max = $self->bulky_items_maximum;
            for (1..$max) {
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

    my $c = $self->{c};
    $collection //= $c->stash->{property}{pending_bulky_collection};
    return 0 unless $collection;

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
    my $self = shift;
    my $c    = $self->{c};

    return $self->within_bulky_refund_window;
}

sub within_bulky_refund_window {
    my $self = shift;
    my $c    = $self->{c};

    my $open_collection = $c->stash->{property}{pending_bulky_collection};
    return 0 unless $open_collection;

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

1;
