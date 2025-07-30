=head1 NAME

FixMyStreet::Cobrand::Bexley::Bulky - code specific to Bexley WasteWorks Bulky Waste

=cut

package FixMyStreet::Cobrand::Bexley::Bulky;

use DateTime::Format::Strptime;
use FixMyStreet::App::Form::Waste::Bulky::Bexley;
use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::BulkyWaste';

sub bulky_allowed_property {
    my ($self, $property) = @_;
    my $class = $property->{class} || '';
    return $self->bulky_enabled && $class =~ /^RD/ ? 1 : 0;
}

sub bulky_cancellation_cutoff_time { { hours => 23, minutes => 59, days_before => 2, working_days => 1 } }
sub bulky_collection_time { { hours => 6, minutes => 0 } }
sub bulky_collection_window_days { 42 } # 6 weeks

sub collection_date {
    my ($self, $p) = @_;
    return $self->_bulky_date_to_dt($p->get_extra_field_value('collection_date'));
}

sub bulky_free_collection_available { 0 }

sub _bulky_date_to_dt {
    my ($self, $date) = @_;
    $date = (split(";", $date))[0];
    my $parser = DateTime::Format::Strptime->new( pattern => '%F', time_zone => FixMyStreet->local_time_zone);
    my $dt = $parser->parse_datetime($date);
    return $dt ? $dt->truncate( to => 'day' ) : undef;
}

# We will send and then cancel if payment not received

sub bulky_send_before_payment { 1 }
sub bulky_cancel_by_update { 1 }

# No earlier/later (make this Peterborough only?)

sub bulky_hide_later_dates { 1 }

sub bulky_disabled_item_photos { 1 }
sub bulky_disabled_location_photo { 1 }

# Look up slots

=head2 bulky_collection_window_start_date

Bexley have a 4pm cut-off for looking to book next day collections.

=cut

sub bulky_collection_window_start_date {
    my ($self, $now) = @_;
    my $start_date = $now->clone->truncate( to => 'day' )->add( days => 1 );
    # If past 4pm, push start date one day later
    if ($now->hour >= 16) {
        $start_date->add( days => 1 );
    }
    return $start_date;
}

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
        (my $date = $_->{AdHocRoundInstanceDate}) =~ s/T00:00:00//;
        $date = $self->_bulky_date_to_dt($date);
        next if FixMyStreet::Cobrand::UK::is_public_holiday(date => $date);
        next if $_->{SlotsFree} <= 0;
        push @available_slots, {
            date => $date->date,
            reference => $_->{AdHocRoundInstanceID},
            expiry => '',
        };
    }

    $self->{c}->waste_cache_set($key, \@available_slots) if !$no_cache;

    return \@available_slots;
}

# Check again at the end
sub check_bulky_slot_available {
    my ( $self, $chosen_date_string, %args ) = @_;

    # chosen_date_string is of the form
    # '2023-08-29;12345;'
    my ( $collection_date) = $chosen_date_string =~ /[^;]+/g;

    my $property = $self->{c}->stash->{property};
    my $available_slots = $self->find_available_bulky_slots(
        $property, undef, 'no_cache' );

    my ($slot) = grep { $_->{date} eq $collection_date } @$available_slots;
    return $slot ? 1 : 0;
}

sub bulky_date_label {
    my ( $self, $dt ) = @_;

    my $format = '%A %e %B';
    my $label = $dt->strftime($format);

    # Saturdays have higher pricing
    if ( $dt->day_of_week == 6 ) {
        $label .= ' (extra charge)';
    }

    return $label;
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

    my $parser = DateTime::Format::Strptime->new( pattern => '%F' );
    my $dt = $parser->parse_datetime($data->{chosen_date});
    my $saturday = $dt->day_of_week == 6 ? 'yes' : 'no';

    my $pension = lc $data->{pension};

    my $points = $cfg->{points}{$saturday}{$pension};
    return $points;
}

# Submission

sub save_item_names_to_report {
    my ($self, $data) = @_;

    my $report = $self->{c}->stash->{report};
    foreach (grep { /^item_\d/ } keys %$data) {
        $report->set_extra_metadata($_ => $data->{$_}) if $data->{$_};
    }
}

sub waste_munge_bulky_data {
    my ($self, $data) = @_;

    my $c = $self->{c};
    my $property = $c->stash->{property};
    my $address = $property->{address};
    my $uprn = $property->{uprn};

    my ($date, $ref) = split(";", $data->{chosen_date});

    $data->{title} = "Bulky waste collection";
    $data->{detail} = "Address: " . $c->stash->{property}->{address};
    $data->{category} = "Bulky collection";
    $data->{extra_collection_date} = $date;
    $data->{extra_round_instance_id} = $ref;
    $data->{extra_pension} = $data->{pension};
    $data->{extra_disability} = $data->{disability};
    $data->{extra_bulky_location} = $data->{location};
    $data->{extra_bulky_parking} = $data->{parking};

    $data->{extra_bulky_parking} .= "\n\n$data->{parking_extra_details}"
        if $data->{parking_extra_details};

    my @items_list = @{ $self->bulky_items_master_list };
    my %items = map { $_->{name} => $_->{bartec_id} } @items_list;

    my @ids;
    my $max = $self->bulky_items_maximum;
    for (1..$max) {
        if (my $item = $data->{"item_$_"}) {
            push @ids, $items{$item};
        };
    }
    $data->{extra_bulky_items} = join("::", @ids);
    $self->bulky_total_cost($data);

    $c->set_param('uprn', $uprn);
}

=head2 suppress_report_sent_email

For Bulky Waste reports, we want to send the email after payment has been confirmed, so we
suppress the email here.

=cut

sub suppress_report_sent_email {
    my ($self, $report) = @_;
    if ($report->cobrand_data eq 'waste' && $report->category eq 'Bulky collection') {
        return 1;
    }
    return 0;
}

sub bulky_nice_item_list {
    my ($self, $report) = @_;

    my @item_nums = map { /^item_(\d+)/ } grep { /^item_\d/ } keys %{$report->get_extra_metadata};
    my @items = sort { $a <=> $b } @item_nums;

    my @fields;
    for my $item (@items) {
        if (my $value = $report->get_extra_metadata("item_$item")) {
            push @fields, { item => $value, display => $value };
        }
    }
    my $items_extra = $self->bulky_items_extra(exclude_pricing => 1);

    return [
        map {
            value => $_->{display},
            message => $items_extra->{$_->{item}}{message},
        },
        @fields,
    ];
}

sub waste_reconstruct_bulky_data {
    my ($self, $p) = @_;

    my $saved_data = {
        "chosen_date" => $p->get_extra_field_value('collection_date'),
        "location" => $p->get_extra_field_value('bulky_location'),
        "parking" => $p->get_extra_field_value('bulky_parking'),
        "pension" => $p->get_extra_field_value('pension'),
        "disability" => $p->get_extra_field_value('disability'),
    };

    my @fields = split /::/, $p->get_extra_field_value('bulky_items');
    for my $id (1..@fields) {
        $saved_data->{"item_$id"} = $p->get_extra_metadata("item_$id");
    }

    $saved_data->{name} = $p->name;
    $saved_data->{email} = $p->user->email;
    $saved_data->{phone} = $p->phone_waste;

    return $saved_data;
}

sub bulky_booking_paid {
    my ($self, $collection) = @_;
    return $collection->get_extra_metadata('payment_reference');
}

# Refund window same as cancellation
sub bulky_can_refund_collection {
    my ($self, $collection) = @_;
    return 0 if !$self->bulky_booking_paid($collection);
    return 0 if !$self->within_bulky_cancel_window($collection);
    return 1;
}

sub bulky_contact_email {
    my $self = shift;
    my $cfg = $self->feature('waste_features') || {};
    return $cfg->{bulky_contact_email};
}

sub bulky_refund_collection {
    my ($self, $collection_report) = @_;
    my $c = $self->{c};

    my $charged = $collection_report->get_extra_field_value('payment');
    $c->send_email(
        'waste/bulky-refund-request.txt',
        {   to => [
                [ $self->bulky_contact_email, $self->council_name ]
            ],

            wasteworks_id => $collection_report->id,
            payment_amount => $collection_report->get_extra_field_value('payment'),
            refund_amount => $charged,
            payment_method =>
                $collection_report->get_extra_field_value('payment_method'),
            payment_code =>
                $collection_report->get_extra_field_value('PaymentCode'),
            auth_code =>
                $collection_report->get_extra_metadata('authCode'),
            continuous_audit_number =>
                $collection_report->get_extra_metadata('continuousAuditNumber'),
            payment_date       => $collection_report->created,
            scp_response       =>
                $collection_report->get_extra_metadata('scpReference'),
            detail  => $collection_report->detail,
            resident_name => $collection_report->name,
            resident_email => $collection_report->user->email,
        },
    );
}

1;
