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
use Integrations::Bartec::Booking;

sub booking_class { 'Integrations::Bartec::Booking' }

=head3 Defaults & constants for bulky waste

=over 4

=item * We search for available bulky collection dates 56 days into the future

=cut

sub bulky_collection_window_days     {56}

=item * Max length of location details text is 250 characters

=cut

sub bulky_location_max_length {250}

=item * User can amend/refund/cancel up to 14:00 the working day before the bulky collection

=cut

sub bulky_cancellation_cutoff_time { { hours => 14, minutes => 0, working_days => 1 } }
sub bulky_amendment_cutoff_time { { hours => 14, minutes => 0, working_days => 1 } }
sub bulky_refund_cutoff_time { { hours => 14, minutes => 0, working_days => 1 } }

=item * Bulky collections start at 6:45 each (working) day

=cut

sub bulky_collection_time { { hours => 6, minutes => 45 } }

sub bulky_daily_slots { $_[0]->wasteworks_config->{daily_slots} || 40 }

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

sub bulky_refund_collection {
    my ($self, $collection_report) = @_;
    my $c = $self->{c};
    $c->send_email(
        'waste/bulky-refund-request.txt',
        {   to => [
                [ $c->cobrand->contact_email, $c->cobrand->council_name ]
            ],

            payment_method =>
                $collection_report->get_extra_field_value('payment_method'),
            payment_code =>
                $collection_report->get_extra_field_value('PaymentCode'),
            auth_code =>
                $collection_report->get_extra_metadata('authCode'),
            continuous_audit_number =>
                $collection_report->get_extra_metadata(
                'continuousAuditNumber'),
            original_sr_number => $c->get_param('ORIGINAL_SR_NUMBER'),
            payment_date       => $collection_report->created,
            scp_response       =>
                $collection_report->get_extra_metadata('scpReference'),
        },
    );
}

sub waste_munge_bulky_data {
    my ($self, $data) = @_;

    my $c = $self->{c};

    $data->{title} = "Bulky goods collection";
    $data->{detail} = "Address: " . $c->stash->{property}->{address};
    $data->{category} = "Bulky collection";
    $data->{extra_DATE} = $data->{chosen_date};

    my $max = $c->stash->{booking_maximum};
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

    my $max = $self->{c}->stash->{booking_maximum};
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
