=head1 NAME

FixMyStreet::Roles::Cobrand::KingstonSutton - shared code for Kingston and Sutton WasteWorks

=head1 DESCRIPTION

=cut

package FixMyStreet::Roles::Cobrand::KingstonSutton;

use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::SLWP';
with 'FixMyStreet::Roles::Cobrand::BulkyWaste';

use FixMyStreet::App::Form::Waste::Garden::Sacks;
use FixMyStreet::App::Form::Waste::Garden::Sacks::Renew;
use FixMyStreet::App::Form::Waste::Report::SLWP;
use FixMyStreet::App::Form::Waste::Request::Kingston;
use FixMyStreet::App::Form::Waste::Request::Sutton;

=head2 Defaults

=over 4

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * The contact form is for abuse reports only

=cut

sub abuse_reports_only { 1 }

=item * Only waste reports are shown on the cobrand

=cut

around problems_restriction => sub {
    my ($orig, $self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    $rs = $orig->($self, $rs);
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    $rs = $rs->search({
        "$table.cobrand_data" => 'waste',
    });
    return $rs;
};

=item * We can send multiple photos through to Echo, directly

=cut

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;
    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

sub state_groups_admin {
    [
        [ New => [ 'confirmed' ] ],
        [ Pending => [ 'investigating', 'action scheduled' ] ],
        [ Closed => [ 'fixed - council', 'unable to fix', 'closed', 'duplicate', 'cancelled' ] ],
        [ Hidden => [ 'unconfirmed', 'hidden', 'partial' ] ],
    ]
}

# Cut down list as only Waste
sub available_permissions {
    my $self = shift;

    return {
        _("Problems") => {
            report_edit => _("Edit reports"),
            report_mark_private => _("View/Mark private reports"),
            contribute_as_another_user => _("Create reports/updates on a user's behalf"),
            contribute_as_anonymous_user => _("Create reports/updates as anonymous user"),
            contribute_as_body => _("Create reports/updates as the council"),
        },
        _("Users") => {
            user_edit => _("Edit users' details/search for their reports"),
            user_manage_permissions => _("Edit other users' permissions"),
            user_assign_body => _("Grant access to the admin"),
        },
        _("Bodies") => {
            template_edit => _("Add/edit response templates"),
            emergency_message_edit => _("Add/edit site message"),
        },
        Waste => {
            wasteworks_config => "Can edit WasteWorks configuration",
        },
    };
}

sub waste_auto_confirm_report { 1 }

use constant CONTAINER_REFUSE_140 => 1;
use constant CONTAINER_REFUSE_180 => 35;
use constant CONTAINER_REFUSE_240 => 2;
use constant CONTAINER_REFUSE_360 => 3;
use constant CONTAINER_PAPER_BIN => 19;
use constant CONTAINER_PAPER_BIN_140 => 36;
use constant CONTAINER_GARDEN_BIN => 26;
use constant CONTAINER_GARDEN_SACK => 28;

sub garden_due_days { 30 }

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        2238 => 'Non-recyclable Refuse',
        2239 => 'Food waste',
        2240 => 'Paper and card',
        2241 => 'Mixed recycling',
        2242 => 'Non-recyclable Refuse',
        2243 => 'Non-recyclable Refuse',
        2246 => 'Mixed recycling',
        2247 => 'Garden Waste',
        2248 => "Food waste",
        2249 => "Paper and card",
        2250 => "Mixed recycling",
        2632 => 'Paper and card',
        3571 => 'Mixed recycling',
        3576 => 'Non-recyclable Refuse',
        2256 => '', # Deliver refuse bags
        2257 => '', # Deliver recycling bags
    );

    return $service_name_override{$service->{ServiceId}} // '';
}

sub waste_password_hidden { 1 }

# For renewal/modify
sub waste_allow_current_bins_edit { 1 }

sub waste_containers {
    my $self = shift;
    my %shared = (
            4 => 'Refuse Blue Sack',
            5 => 'Refuse Black Sack',
            6 => 'Refuse Red Stripe Bag',
            18 => 'Mixed Recycling Blue Striped Bag',
            29 => 'Recycling Single Use Bag',
            21 => 'Paper & Card Reusable Bag',
            22 => 'Paper Sacks',
            30 => 'Paper & Card Recycling Clear Bag',
            7 => 'Communal Refuse bin (240L)',
            8 => 'Communal Refuse bin (360L)',
            9 => 'Communal Refuse bin (660L)',
            10 => 'Communal Refuse bin (1100L)',
            11 => 'Communal Refuse Chamberlain',
            33 => 'Communal Refuse bin (140L)',
            34 => 'Communal Refuse bin (1280L)',
            14 => 'Communal Recycling bin (660L)',
            15 => 'Communal Recycling bin (1100L)',
            25 => 'Communal Food bin (240L)',
            12 => 'Recycling bin (240L)',
            13 => 'Recycling bin (360L)',
            20 => 'Paper recycling bin (360L)',
            31 => 'Paper 55L Box',
    );
    if ($self->moniker eq 'sutton') {
        return {
            %shared,
            1 => 'Standard Brown General Waste Wheelie Bin (140L)',
            2 => 'Larger Brown General Waste Wheelie Bin (240L)',
            3 => 'Extra Large Brown General Waste Wheelie Bin (360L)',
            35 => 'Rubbish bin (180L)',
            16 => 'Mixed Recycling Green Box (55L)',
            19 => 'Paper and Cardboard Green Wheelie Bin (240L)',
            36 => 'Paper and Cardboard Green Wheelie Bin (140L)',
            23 => 'Small Kitchen Food Waste Caddy (7L)',
            24 => 'Large Outdoor Food Waste Caddy (23L)',
            26 => 'Garden Waste Wheelie Bin (240L)',
            27 => 'Garden Waste Wheelie Bin (140L)',
            28 => 'Garden waste sacks',
        };
    } elsif ($self->moniker eq 'kingston') {
        my $black_bins = $self->{c}->get_param('exchange') ? {
            1 => 'Black rubbish bin (140L)',
            2 => 'Black rubbish bin (240L)',
            3 => 'Black rubbish bin (360L)',
            35 => 'Black rubbish bin (180L)',
        } : {
            1 => 'Black rubbish bin',
            2 => 'Black rubbish bin',
            3 => 'Black rubbish bin',
            35 => 'Black rubbish bin',
        };
        return {
            %shared,
            %$black_bins,
            12 => 'Green recycling bin (240L)',
            13 => 'Green recycling bin (360L)',
            16 => 'Green recycling box (55L)',
            19 => 'Blue lid paper and cardboard bin (240L)',
            20 => 'Blue lid paper and cardboard bin (360L)',
            23 => 'Food waste bin (kitchen)',
            24 => 'Food waste bin (outdoor)',
            36 => 'Blue lid paper and cardboard bin (180L)',
            26 => 'Garden waste bin (240L)',
            27 => 'Garden waste bin (140L)',
            28 => 'Garden waste sacks',
        };
    }
}

sub _waste_containers_no_request { {
    6 => 1, # Red stripe bag
    17 => 1, # Recycling purple sack
    29 => 1, # Recycling Single Use Bag
    21 => 1, # Paper & Card Reusable bag
} }

sub waste_quantity_max {
    return (
        2247 => 5, # Garden waste maximum
    );
}

sub waste_bulky_missed_blocked_codes {
    return {
        # Partially completed
        12399 => {
            507 => 'Not all items presented',
            380 => 'Some items too heavy',
        },
        # Completed
        12400 => {
            606 => 'More items presented than booked',
        },
        # Not Completed
        12401 => {
            460 => 'Nothing out',
            379 => 'Item not as described',
            100 => 'No access',
            212 => 'Too heavy',
            473 => 'Damage on site',
            234 => 'Hazardous waste',
        },
    };
}

sub waste_munge_bin_services_open_requests {
    my ($self, $open_requests) = @_;
    if ($open_requests->{+CONTAINER_REFUSE_140}) { # Sutton
        $open_requests->{+CONTAINER_REFUSE_240} = $open_requests->{+CONTAINER_REFUSE_140};
    } elsif ($open_requests->{+CONTAINER_REFUSE_180}) { # Kingston
        $open_requests->{+CONTAINER_REFUSE_240} = $open_requests->{+CONTAINER_REFUSE_180};
    } elsif ($open_requests->{+CONTAINER_REFUSE_240}) { # Both
        $open_requests->{+CONTAINER_REFUSE_140} = $open_requests->{+CONTAINER_REFUSE_240};
        $open_requests->{+CONTAINER_REFUSE_180} = $open_requests->{+CONTAINER_REFUSE_240};
        $open_requests->{+CONTAINER_REFUSE_360} = $open_requests->{+CONTAINER_REFUSE_240};
    } elsif ($open_requests->{+CONTAINER_REFUSE_360}) { # Kingston
        $open_requests->{+CONTAINER_REFUSE_180} = $open_requests->{+CONTAINER_REFUSE_360};
        $open_requests->{+CONTAINER_REFUSE_240} = $open_requests->{+CONTAINER_REFUSE_360};
    }
    if ($open_requests->{+CONTAINER_PAPER_BIN_140}) {
        $open_requests->{+CONTAINER_PAPER_BIN} = $open_requests->{+CONTAINER_PAPER_BIN_140};
    }
}

# Not in the function below because it needs to set things needed before then
# (perhaps could be refactored better at some point). Used for new/renew
sub waste_garden_sub_payment_params {
    my ($self, $data) = @_;
    my $c = $self->{c};

    # Special sack form handling
    my $container = $data->{container_choice} || '';
    if ($container eq 'sack') {
        $data->{bin_count} = 1;
        $data->{new_bins} = 1;
        my $cost_pa = $c->cobrand->garden_waste_sacks_cost_pa();
        ($cost_pa) = $c->cobrand->apply_garden_waste_discount($cost_pa) if $data->{apply_discount};
        $c->set_param('payment', $cost_pa);
    }
}

=head2 waste_munge_report_form_fields

We use a custom report form to add some text to the "About you" page.

=cut

sub waste_munge_report_form_fields {
    my ($self, $field_list) = @_;
    $self->{c}->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Report::SLWP';
}

=head2 waste_report_form_first_next

After picking a service, we jump straight to the about you page unless it's
bulky, where we ask for more information.

=cut

sub waste_report_form_first_next {
    my $self = shift;
    my $cfg = $self->feature('echo');
    my $bulky_service_id = $cfg->{bulky_service_id};
    return sub {
        my $data = shift;
        return 'notes' if $data->{"service-$bulky_service_id"};
        return 'about_you';
    };
}

sub garden_waste_new_bin_admin_fee {
    my ($self, $new_bins) = @_;
    $new_bins ||= 0;

    my $per_new_bin_first_cost = $self->_get_cost('ggw_new_bin_first_cost');
    my $per_new_bin_cost = $self->_get_cost('ggw_new_bin_cost');

    my $cost = 0;
    if ($new_bins > 0) {
        $cost += $per_new_bin_first_cost;
        if ($new_bins > 1) {
            $cost += $per_new_bin_cost * ($new_bins - 1);
        }
    }
    return $cost;
}

=head2 waste_cc_payment_line_item_ref

This is used by the SCP role (all Kingston, Sutton requests) to provide the
reference for the credit card payment. It differs for bulky waste.

=cut

sub waste_cc_payment_line_item_ref {
    my ($self, $p) = @_;
    if ($p->category eq 'Bulky collection') {
        return $self->_waste_cc_line_item_ref($p, "BULKY", "");
    } elsif ($p->category eq 'Request new container') {
        return $self->_waste_cc_line_item_ref($p, "CCH", "");
    } else {
        return $self->_waste_cc_line_item_ref($p, "GGW", "GW Sub");
    }
}

sub waste_cc_payment_admin_fee_line_item_ref {
    my ($self, $p) = @_;
    return $self->_waste_cc_line_item_ref($p, "GGW", "GW admin charge");
}

sub _waste_cc_line_item_ref {
    my ($self, $p, $type, $str) = @_;
    my $id = $self->waste_payment_ref_council_code . "-$type-" . $p->id;
    my $len = 50 - length($id) - 1;
    if ($str) {
        $str = "-$str";
        $len -= length($str);
    }
    my $name = substr($p->name, 0, $len);
    return "$id-$name$str";
}

sub waste_cc_payment_sale_ref {
    my ($self, $p) = @_;
    return "GGW" . $p->get_extra_field_value('uprn');
}

=head2 Dashboard export

The CSV export includes all reports, including unconfirmed and hidden, and is
adapted in a few ways for Waste reports - including extra columns such as UPRN,
email/phone, payment amount and method.

=cut

# Include unconfirmed and hidden reports in CSV export
sub dashboard_export_include_all_states { 1 }

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->modify_csv_header( Detail => 'Address' );

    $csv->add_csv_columns(
        uprn => 'UPRN',
        user_email => 'User Email',
        user_phone => 'User Phone',
        payment_method => 'Payment method',
        payment_reference => 'Payment reference',
        payment => 'Payment',
        pro_rata => 'Pro rata payment',
        admin_fee => 'Admin fee',
        container => 'Subscription container',
        current_bins => 'Bin count declared',
        quantity => 'Subscription quantity',
    );

    $csv->objects_attrs({
        '+columns' => ['user.email', 'user.phone'],
        join => 'user',
    });

    $csv->csv_extra_data(sub {
        my $report = shift;

        my %fields;
        if ($csv->dbi) {
            %fields = %{$report->{extra}{_field_value} || {}};
        } else {
            my @fields = @{ $report->get_extra_fields() };
            %fields = map { $_->{name} => $_->{value} } @fields;
        }

        my $detail = $csv->dbi ? $report->{detail} : $report->detail;
        $detail =~ s/^.*?\n\n//; # Remove waste category

        return {
            detail => $detail,
            uprn => $fields{uprn},
            $csv->dbi ? (
                user_name_display => $report->{name},
                payment_reference => $fields{PaymentCode} || $report->{extra}{chequeReference} || '',
            ) : (
                user_name_display => $report->name,
                user_email => $report->user->email || '',
                user_phone => $report->user->phone || '',
                payment_reference => $fields{PaymentCode} || $report->get_extra_metadata('chequeReference') || '',
            ),
            payment_method => $fields{payment_method} || '',
            payment => $fields{payment},
            pro_rata => $fields{pro_rata},
            admin_fee => $fields{admin_fee},
            container => $fields{Subscription_Details_Containers},
            current_bins => $fields{current_containers},
            quantity => $fields{Subscription_Details_Quantity},
        };
    });
}

=head2 Bulky waste collection

SLWP looks 8 weeks ahead for collection dates, and cancels by sending an
update, not a new report. It sends the event to the backend before collecting
payment, and does not refund on cancellations. It has a hard-coded list of
property types allowed to book collections.

=cut

sub bulky_collection_window_days { 56 }

sub bulky_cancel_by_update { 1 }
sub bulky_send_before_payment { 1 }
sub bulky_show_location_field_mandatory { 1 }

sub bulky_can_refund { 0 }
sub _bulky_refund_cutoff_date { }

=head2 bulky_collection_window_start_date

K&S have an 11pm cut-off for looking to book next day collections.

=cut

sub bulky_collection_window_start_date {
    my $self = shift;
    my $now = DateTime->now( time_zone => FixMyStreet->local_time_zone );
    my $start_date = $now->clone->truncate( to => 'day' )->add( days => 1 );
    # If past 11pm, push start date one day later
    if ($now->hour >= 23) {
        $start_date->add( days => 1 );
    }
    return $start_date;
}

sub bulky_allowed_property {
    my ( $self, $property ) = @_;

    return if $property->{has_no_services};
    my $cfg = $self->feature('echo');

    my $type = $property->{type_id} || 0;
    my $valid_type = grep { $_ == $type } @{ $cfg->{bulky_address_types} || [] };
    my $domestic_farm = $type != 7 || $property->{domestic_refuse_bin};
    return $self->bulky_enabled && $valid_type && $domestic_farm;
}

sub collection_date {
    my ($self, $p) = @_;
    return $self->_bulky_date_to_dt($p->get_extra_field_value('Collection_Date'));
}

sub bulky_free_collection_available { 0 }

sub bulky_hide_later_dates { 1 }

sub _bulky_date_to_dt {
    my ($self, $date) = @_;
    $date = (split(";", $date))[0];
    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T', time_zone => FixMyStreet->local_time_zone);
    my $dt = $parser->parse_datetime($date);
    return $dt ? $dt->truncate( to => 'day' ) : undef;
}

=head2 Sending to Echo

We use the reserved slot GUID and reference,
and the provided date/location information.
Items are sent through with their notes as individual entries

=cut

sub waste_munge_bulky_data {
    my ($self, $data) = @_;

    my $c = $self->{c};
    my ($date, $ref, $expiry) = split(";", $data->{chosen_date});

    my $guid_key = $self->council_url . ":echo:bulky_event_guid:" . $c->stash->{property}->{id};
    $data->{extra_GUID} = $self->{c}->waste_cache_get($guid_key);
    $data->{extra_reservation} = $ref;

    $data->{title} = "Bulky goods collection";
    $data->{detail} = "Address: " . $c->stash->{property}->{address};
    $data->{category} = "Bulky collection";
    $data->{extra_Collection_Date} = $date;
    $data->{extra_Exact_Location} = $data->{location};

    my $first_date = $self->{c}->session->{first_date_returned};
    $first_date = DateTime::Format::W3CDTF->parse_datetime($first_date);
    my $dt = DateTime::Format::W3CDTF->parse_datetime($date);
    $data->{'extra_First_Date_Returned_to_Customer'} = $first_date->strftime("%d/%m/%Y");
    $data->{'extra_Customer_Selected_Date_Beyond_SLA?'} = $dt > $first_date ? 1 : 0;

    my @items_list = @{ $self->bulky_items_master_list };
    my %items = map { $_->{name} => $_->{bartec_id} } @items_list;

    my @notes;
    my @ids;
    my @photos;

    my $max = $self->bulky_items_maximum;
    for (1..$max) {
        if (my $item = $data->{"item_$_"}) {
            push @notes, $data->{"item_notes_$_"} || '';
            push @ids, $items{$item};
            push @photos, $data->{"item_photos_$_"} || '';
        };
    }
    $data->{extra_Bulky_Collection_Notes} = join("::", @notes);
    $data->{extra_Bulky_Collection_Bulky_Items} = join("::", @ids);
    $data->{extra_Image} = join("::", @photos);
    $self->bulky_total_cost($data);
}

sub waste_reconstruct_bulky_data {
    my ($self, $p) = @_;

    my $saved_data = {
        "chosen_date" => $p->get_extra_field_value('Collection_Date'),
        "location" => $p->get_extra_field_value('Exact_Location'),
        "location_photo" => $p->get_extra_metadata("location_photo"),
    };

    my @fields = split /::/, $p->get_extra_field_value('Bulky_Collection_Bulky_Items');
    my @notes = split /::/, $p->get_extra_field_value('Bulky_Collection_Notes');
    for my $id (1..@fields) {
        $saved_data->{"item_$id"} = $p->get_extra_metadata("item_$id");
        $saved_data->{"item_notes_$id"} = $notes[$id-1];
        $saved_data->{"item_photo_$id"} = $p->get_extra_metadata("item_photo_$id");
    }

    $saved_data->{name} = $p->name;
    $saved_data->{email} = $p->user->email;
    $saved_data->{phone} = $p->phone_waste;

    return $saved_data;
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

sub bulky_location_photo_prompt {
    'Help us by attaching a photo of where the items will be left for collection.';
}

1;
