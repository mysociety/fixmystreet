=head1 NAME

FixMyStreet::Cobrand::Peterborough - code specific to the Peterborough cobrand

=head1 SYNOPSIS

We integrate with Peterborough's Confirm back end.
We also integrate with Bartec for waste collection services, including bulky
waste collection.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Peterborough;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use utf8;
use strict;
use warnings;
use DateTime;
use Integrations::Bartec;
use List::Util qw(any);
use Sort::Key::Natural qw(natkeysort_inplace);
use FixMyStreet::DB;
use FixMyStreet::WorkingDays;
use FixMyStreet::App::Form::Waste::Request::Peterborough;
use Utils;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';
with 'FixMyStreet::Roles::Open311Multi';
with 'FixMyStreet::Roles::SCP';
with 'FixMyStreet::Cobrand::Peterborough::Bulky';

=head2 Defaults

=over 4

=cut

sub council_area_id { 2566 }
sub council_area { 'Peterborough' }
sub council_name { 'Peterborough City Council' }
sub council_url { 'peterborough' }

=item * Admin user domain is 'peterborough.gov.uk'

=cut

sub admin_user_domain { "peterborough.gov.uk" }

=item * Default map zoom is set to 5

=cut

sub default_map_zoom { 5 }

=item * We do not send questionnaires

=cut

sub send_questionnaires { 0 }

=item * Max title length is 50

=cut

sub max_title_length { 50 }

=item * Geocoder is OSM

=cut

sub get_geocoder { 'OSM' }

=item * We allow 'display_name' as an extra field on contacts

=back

=cut

sub contact_extra_fields { [ 'display_name' ] }

sub pin_colour {
    my ( $self, $p, $context ) = @_;

    my $c = $self->{c};
    my $is_staff
        = $c
        && $c->user_exists
        && (
            ( $c->user->from_body && $c->user->from_body->name eq council_name() )
            || $c->user->is_superuser
        );

    if ($is_staff) {
        my $land_type = $self->land_type_for_problem($p);
        return 'blue'   if $land_type eq 'public';
        return 'orange' if $land_type eq 'private';
    }

    return 'yellow';
}

sub service_name_override {
    my $self = shift;
    return {
        "Empty Bin 240L Black"      => "Black Bin",
        "Empty Bin 240L Brown"      => "Brown Bin",
        "Empty Bin 240L Green"      => "Green Bin",
        "Empty Black 240l Bin"      => "Black Bin",
        "Empty Brown 240l Bin"      => "Brown Bin",
        "Empty Green 240l Bin"      => "Green Bin",
        "Empty Bin Recycling 1100l" => "Recycling Bin",
        "Empty Bin Recycling 240l"  => "Recycling Bin",
        "Empty Bin Recycling 660l"  => "Recycling Bin",
        "Empty Bin Refuse 1100l"    => "Refuse",
        "Empty Bin Refuse 240l"     => "Refuse",
        "Empty Bin Refuse 660l"     => "Refuse",
    };
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.6085234396978,-0.253091266573947',
        bounds => [ 52.5060949603654, -0.497663559599628, 52.6752139533306, -0.0127696975457487 ],
    };
}

sub geocoder_munge_results {
    my ($self, $result) = @_;
    $result->{display_name} = '' unless $result->{display_name} =~ /City of Peterborough/;
    $result->{display_name} =~ s/, UK$//;
    $result->{display_name} =~ s/, City of Peterborough, East of England, England//;
}

around open311_extra_data_include => sub {
    my ($orig, $self, $row, $h) = @_;

    my $open311_only = $self->$orig($row, $h);
    foreach (@$open311_only) {
        if ($_->{name} eq 'description') {
            my ($ref) = grep { $_->{name} =~ /pcc-Skanska-csc-ref/i } @{$row->get_extra_fields};
            $_->{value} .= "\n\nSkanska CSC ref: $ref->{value}" if $ref;
        }
    }
    if ( $row->geocode && $row->contact->email =~ /Bartec/ ) {
        my $parts = $row->nearest_address_parts;
        if ($parts->{number} || $parts->{street} || $parts->{postcode}) {
            push @$open311_only, (
                { name => 'postcode', value => $parts->{postcode} },
                { name => 'house_no', value => $parts->{number} },
                { name => 'street', value => $parts->{street} }
            );
        }
    }
    if ( $row->contact->email =~ /Bartec/ && $row->get_extra_metadata('contributed_by') ) {
        push @$open311_only, (
            {
                name => 'contributed_by',
                value => $self->csv_staff_user_lookup($row->get_extra_metadata('contributed_by'), $self->csv_staff_users),
            },
        );
    }
    return $open311_only;
};
# remove categories which are informational only
sub open311_extra_data_exclude {
    my ($self, $row, $h) = @_;
    # We need to store this as Open311 pre_send needs to check it and it will
    # have been removed due to this function.
    $row->set_extra_metadata(pcc_witness => $row->get_extra_field_value('pcc-witness'));
    [ '^PCC-', '^emergency$', '^private_land$', '^extra_detail$' ]
}

sub lookup_site_code_config { {
    buffer => 50, # metres
    url => 'https://peterborough.assets/7/query?',
    type => 'arcgis',
    outFields => 'USRN',
    property => "USRN",
    accept_feature => sub { 1 },
    accept_types => { Polygon => 1 },
} }

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    # Peterborough want to make it clear in Confirm when an update has come
    # from FMS.
    $params->{description} = "[Customer FMS update] " . $params->{description};

    # Send the FMS problem ID with the update.
    $params->{service_request_id_ext} = $comment->problem->id;
}

sub updates_sent_to_body {
    my ($self, $problem) = @_;

    my $code = $problem->contact->email;
    return 0 if $code =~ /^Bartec/;
    return 1;
}

sub should_skip_sending_update {
    my ($self, $update) = @_;

    my $code = $update->problem->contact->email;
    return 1 if $code =~ /^Bartec/;
    return 0;
}

around 'open311_config' => sub {
    my ($orig, $self, $row, $h, $params, $contact) = @_;

    $params->{upload_files} = 1;
    $self->$orig($row, $h, $params, $contact);
};

# Looks up & sets land_type in extra_metadata if not previously set, or
# lat or lon have been changed. For flytipping & graffiti only.
sub land_type_for_problem {
    my ( $self, $problem ) = @_;

    my %flytipping_cats = map { $_ => 1 } @{ $self->_flytipping_categories };
    return '' unless $flytipping_cats{ $problem->category };

    my %dirty_columns = $problem->get_dirty_columns;
    my $land_type;
    $land_type = $problem->get_extra_metadata('land_type')
        if !exists $dirty_columns{longitude}
        && !exists $dirty_columns{latitude};

    return $land_type if defined $land_type;

    my ( $x, $y )
        = Utils::convert_latlon_to_en( $problem->latitude,
        $problem->longitude, 'G' );

    # Council land
    my $features = $self->_fetch_features(
        {   type   => 'arcgis',
            url    => 'https://peterborough.assets/4/query?',
            buffer => 1,
        },
        $x, $y,
    );

    $land_type = 'public' if $features && @$features;

    unless ($land_type) {
        # Leased land - count as 'private' (i.e. not dealt with in Bartec)
        $features = $self->_fetch_features(
            {   type   => 'arcgis',
                url    => 'https://peterborough.assets/3/query?',
                buffer => 1,
            },
            $x, $y,
        );

        $land_type = 'private' if $features && @$features;
    }

    unless ($land_type) {
        # Adopted road - count as 'public'
        $features = $self->_fetch_features(
            {   type   => 'arcgis',
                url    => 'https://peterborough.assets/7/query?',
                buffer => 1,
            },
            $x, $y,
        );

        $land_type = 'public' if $features && @$features;
    }

    $land_type = 'private' unless $land_type;

    # We want to save the land type on extra_metadata, but need to make sure
    # we don't save other fields that may have been changed on the original
    # problem outside this method. So we fetch a fresh version of the problem
    # from the DB and update the extra_metadata on that.
    my $problem_clean = FixMyStreet::DB->resultset('Problem')
        ->find( { id => $problem->id } );

    if ( $problem_clean ) {
        $problem_clean->set_extra_metadata( land_type => $land_type );
        $problem_clean->update;
    }
    else {
        # Ideally, the caller should provide a problem that already
        # exists in the DB. But in case it doesn't, just set
        # extra_metadata on the problem object. In this case, we leave it to
        # the caller to save to the DB.
        $problem->set_extra_metadata( land_type => $land_type );
    }

    return $land_type;
}

sub get_body_sender {
    my ( $self, $body, $problem ) = @_;

    my $land_type = $self->land_type_for_problem($problem);

    my $emails = $self->feature('open311_email');
    if ( $land_type eq 'private' && $emails->{flytipping} ) {
        # Just send email for records
        $problem->set_extra_metadata(
            'flytipping_email' => $emails->{flytipping} );

        # P'bro do not want to be notified of smaller incident sizes. They
        # also do not want email for reports raised by staff.
        return { method => 'Blackhole' }
            if _is_small_flytipping_incident($problem)
            || _is_raised_by_staff($problem);

        my $contact
            = $self->SUPER::get_body_sender( $body, $problem )->{contact};
        return { method => 'Email', contact => $contact };
    }

    return $self->SUPER::get_body_sender( $body, $problem );
}

sub munge_sendreport_params {
    my ($self, $row, $h, $params) = @_;

    if ( $row->get_extra_metadata('flytipping_email') ) {
        $params->{To} = [ [
            $row->get_extra_metadata('flytipping_email'), $self->council_name
        ] ];
    }
}

sub _witnessed_general_flytipping {
    my $row = shift;
    my $witness = $row->get_extra_metadata('pcc_witness') || '';
    return ($row->category eq 'General fly tipping' && $witness eq 'yes');
}

sub open311_pre_send {
    my ($self, $row, $open311) = @_;
    return 'SKIP' if _witnessed_general_flytipping($row);

    # This is a temporary addition to workaround an issue with the bulky goods
    # backend Peterborough are using.
    # In addition to sending the booking details as extra fields in the usual
    # manner, we concatenate all relevant details into the report's title field,
    # which is displayed as a service request note in Bartec.
    if ($row->category eq 'Bulky collection') {
        # We don't want to persist our changes to the DB, so keep a copy
        # of the original title so it can be restored by open311_post_send.
        $self->{pboro_original_title} = $row->get_extra_field_value("title");

        my $title = "Crew notes: " . ( $row->get_extra_field_value("CREW NOTES") || "" );
        $title .= "\n\nItems:\n";

        my $max = $self->bulky_items_maximum;
        for (1..$max) {
            my $two = sprintf("%02d", $_);
            if (my $item = $row->get_extra_field_value("ITEM_$two")) {
                $title .= "$two. $item\n";
            }
        }
        $row->update_extra_field({ name => "title", value => $title});
    }
}

sub open311_post_send {
    my ($self, $row, $h) = @_;

    if ($row->category eq 'Bulky collection') {
        # Restore problem's original title before it's stored to DB.
        $row->update_extra_field({ name => "title", value => $self->{pboro_original_title} });
    }

    # Check Open311 was successful
    my $witnessed_flytipping = _witnessed_general_flytipping($row);
    my $send_email = $row->external_id || $witnessed_flytipping;
    # Unset here because check above used it
    $row->unset_extra_metadata('pcc_witness');
    return unless $send_email;

    # P'bro do not want to be emailed about graffiti on public land
    return if $row->category =~ /graffiti/i;

    # P'bro do not want to be emailed about smaller incident sizes or staff
    # reports - with the exception of witnessed flytipping, as this won't
    # have been sent by Open311
    return
        if !$witnessed_flytipping
        && ( _is_small_flytipping_incident($row)
        || _is_raised_by_staff($row) );

    my $emails = $self->feature('open311_email');
    my %flytipping_cats = map { $_ => 1 } @{ $self->_flytipping_categories };
    if ( $emails->{flytipping} && $flytipping_cats{$row->category} ) {
        my $dest = [ $emails->{flytipping}, "Environmental Services" ];
        my $sender = FixMyStreet::SendReport::Email->new( to => [ $dest ] );
        $sender->send($row, $h);
    }
}

sub suppress_report_sent_email {
    my ($self, $report) = @_;
    return 1 if $report->category eq 'Bulky cancel' && $report->get_extra_metadata('bulky_amendment_cancel');
    return 0;
}

sub post_report_sent {
    my ($self, $problem) = @_;

    if ( $problem->get_extra_metadata('flytipping_email') ) {
        $problem->unset_extra_metadata('flytipping_email');
        $self->_post_report_sent_close($problem, 'report/new/flytipping_text.html');
    }
}

sub _fetch_features_url {
    my ($self, $cfg) = @_;
    my $uri = URI->new( $cfg->{url} );
    if ( $cfg->{type} && $cfg->{type} eq 'arcgis' ) {
        $uri->query_form(
            inSR => 27700,
            outSR => 3857,
            f => "geojson",
            geometry => $cfg->{bbox},
            outFields => $cfg->{outFields},
        );
        return URI->new(
            'https://tilma.mysociety.org/resource-proxy/proxy.php?' .
            $uri
        );
    } else {
        return $self->SUPER::_fetch_features_url($cfg);
    }
}

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    my @contacts = $csv->body->contacts->search(undef, { order_by => [ 'category' ] } )->all;
    my %extra_columns;
    foreach my $contact (@contacts) {
        foreach (@{$contact->get_metadata_for_storage}) {
            next unless $_->{code} =~ /^PCC-/i;
            $extra_columns{"extra.$_->{code}"} = $_->{description};
        }
    }
    my @extra_columns = map { $_ => $extra_columns{$_} } sort keys %extra_columns;

    $csv->add_csv_columns(
        staff_user => 'Staff User',
        usrn => 'USRN',
        nearest_address => 'Nearest address',
        external_id => 'External ID',
        external_status_code => 'External status code',
        @extra_columns,
    );

    my $user_lookup = $self->csv_staff_users;

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $address = $report->nearest_address(1);
        my $staff_user = $self->csv_staff_user_lookup($report->get_extra_metadata('contributed_by'), $user_lookup);
        my $ext_code = $report->get_extra_metadata('external_status_code');
        my $state = FixMyStreet::DB->resultset("State")->display($report->state);
        my $extra = {
            nearest_address => $address,
            staff_user => $staff_user,
            external_status_code => $ext_code,
            external_id => $report->external_id,
            state => $state,
        };

        foreach (@{$report->get_extra_fields}) {
            $extra->{usrn} = $_->{value} if $_->{name} eq 'site_code';
            $extra->{"extra.$_->{name}"} = $_->{value} if $_->{name} =~ /^PCC-/i;
        }

        return $extra;
    });
}

sub open311_filter_contacts_for_deletion {
    my ($self, $contacts) = @_;

    # Don't delete inactive contacts
    return $contacts->search({ state => { '!=' => 'inactive' } });
}

sub _flytipping_categories { [
    "General fly tipping",
    "Hazardous fly tipping",
    "Non offensive graffiti",
    "Offensive graffiti",
    "Offensive graffiti - STAFF ONLY",
] }

sub _is_small_flytipping_incident {
    my $problem = shift;

    my $single_black_bag = qr/S00/;
    my $single_item      = qr/S01/;

    return ( $problem->get_extra_field_value('Incident_Size') // '' )
        =~ /$single_black_bag|$single_item/;
}

sub _is_raised_by_staff {
    my $problem = shift;

    return $problem->user && $problem->user->body eq council_name();
}

# We can resend reports upon category change
sub category_change_force_resend {
    my ($self, $old, $new) = @_;

    # Get the Open311 identifiers
    my $contacts = $self->{c}->stash->{contacts};
    ($old) = map { $_->email } grep { $_->category eq $old } @$contacts;
    ($new) = map { $_->email } grep { $_->category eq $new } @$contacts;

    return 0 if $old =~ /^Bartec/ && $new =~ /^Bartec/;
    return 0 if $old =~ /^Ezytreev/ && $new =~ /^Ezytreev/;
    return 0 if $old !~ /^(Bartec|Ezytreev)/ && $new !~ /^(Bartec|Ezytreev)/;
    return 1;
}

=head2 Waste product code

Functions specific to the waste product & Bartec integration.

=cut

sub _premises_for_postcode {
    my $self = shift;
    my $pc = shift;
    my $c = $self->{c};

    my $key = "peterborough:bartec:premises_for_postcode:$pc";

    unless ( $c->session->{$key} ) {
        my $cfg = $self->feature('bartec');
        my $bartec = Integrations::Bartec->new(%$cfg);
        my $response = $bartec->Premises_Get($pc);

        if (!$c->user_exists || !($c->user->from_body || $c->user->is_superuser)) {
            my $blocked = $cfg->{blocked_uprns} || [];
            my %blocked = map { $_ => 1 } @$blocked;
            @$response = grep { !$blocked{$_->{UPRN}} } @$response;
        }

        $c->session->{$key} = [ map { {
            id => $pc . ":" . $_->{UPRN},
            uprn => $_->{UPRN},
            usrn => $_->{USRN},
            address => $self->_format_address($_),
            latitude => $_->{Location}->{Metric}->{Latitude},
            longitude => $_->{Location}->{Metric}->{Longitude},
        } } @$response ];
    }

    return $c->session->{$key};
}

sub clear_cached_lookups_postcode {
    my ($self, $pc) = @_;
    my $key = "peterborough:bartec:premises_for_postcode:$pc";
    delete $self->{c}->session->{$key};
}

sub clear_cached_lookups_property {
    my ($self, $uprn) = @_;

    # might be prefixed with postcode if it's come straight from the URL
    $uprn =~ s/^.+\://g;

    foreach ( qw/look_up_property bin_services_for_address/ ) {
        delete $self->{c}->session->{"peterborough:bartec:$_:$uprn"};
    }

    $self->clear_cached_lookups_bulky_slots($uprn);
}

sub clear_cached_lookups_bulky_slots {
    my ($self, $uprn) = @_;

    # might be prefixed with postcode
    $uprn =~ s/^.+\://g;

    for (qw/earlier later/) {
        delete $self->{c}
            ->session->{"peterborough:bartec:available_bulky_slots:$_:$uprn"};
    }
}

sub bin_addresses_for_postcode {
    my $self = shift;
    my $pc = shift;

    my $premises = $self->_premises_for_postcode($pc);
    my $data = [ map { {
        value => $pc . ":" . $_->{uprn},
        label => $_->{address},
    } } @$premises ];
    natkeysort_inplace { $_->{label} } @$data;
    return $data;
}

my %irregulars = ( 1 => 'st', 2 => 'nd', 3 => 'rd', 11 => 'th', 12 => 'th', 13 => 'th');
sub ordinal {
    my $n = shift;
    $irregulars{$n % 100} || $irregulars{$n % 10} || 'th';
}

sub construct_bin_date {
    my $str = shift;
    return unless $str;
    my $date = DateTime::Format::W3CDTF->parse_datetime($str);
    return $date;
}

sub look_up_property {
    my $self = shift;
    my $id = shift;

    return unless $id;

    my ($pc, $uprn) = split ":", $id;

    my $premises = $self->_premises_for_postcode($pc);

    my %premises = map { $_->{uprn} => $_ } @$premises;

    my $c = $self->{c};
    my @pending = $self->find_pending_bulky_collections($uprn)->all;
    $c->stash->{pending_bulky_collections}
        = @pending ? \@pending : undef;

    my $cfg = $self->feature('waste_features');
    if ($cfg->{bulky_retry_bookings} && $c->stash->{is_staff}) {
        my @unconfirmed = $self->find_unconfirmed_bulky_collections($uprn)->all;
        $c->stash->{unconfirmed_bulky_collections} = @unconfirmed ? \@unconfirmed : undef;
    }

    return $premises{$uprn};
}

sub image_for_unit {
    my ($self, $unit) = @_;
    my $service_id = $unit->{service_id};
    my $base = '/i/waste-containers';
    my $images = {
        6533 => "$base/bin-black",
        6534 => "$base/bin-green",
        6579 => "$base/bin-brown",
    };
    return $images->{$service_id};
}

sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

    $self->{c}->stash->{containers} = {
        # For new containers
        419 => "240L Black",
        420 => "240L Green",
        425 => "All bins",
        493 => "Both food bins",
        424 => "Large food caddy",
        423 => "Small food caddy",
        428 => "Food bags",

        "FOOD_BINS" => "Food bins",
        "ASSISTED_COLLECTION" => "Assisted collection",

        # For missed collections or repairs
        6533 => "240L Black",
        6534 => "240L Green",
        6579 => "240L Brown",
        "LARGE BIN" => "360L Black", # Actually would be service 422
    };

    my %container_request_ids = (
        6533 => [ 419 ], # 240L Black
        6534 => [ 420 ], # 240L Green
        6579 => undef, # 240L Brown
        6836 => undef, # Refuse 1100l
        6837 => undef, # Refuse 660l
        6839 => undef, # Refuse 240l
        6840 => undef, # Recycling 1100l
        6841 => undef, # Recycling 660l
        6843 => undef, # Recycling 240l
        # all bins?
        # large food caddy?
        # small food caddy?
    );

    my %container_service_ids = (
        6533 => 255, # 240L Black
        6534 => 254, # 240L Green
        6579 => 253, # 240L Brown
        6836 => undef, # Refuse 1100l
        6837 => undef, # Refuse 660l
        6839 => undef, # Refuse 240l
        6840 => undef, # Recycling 1100l
        6841 => undef, # Recycling 660l
        6843 => undef, # Recycling 240l
        # black 360L?
    );

    my %container_request_max = (
        6533 => 1, # 240L Black
        6534 => 1, # 240L Green
        6579 => 1, # 240L Brown
        6836 => undef, # Refuse 1100l
        6837 => undef, # Refuse 660l
        6839 => undef, # Refuse 240l
        6840 => undef, # Recycling 1100l
        6841 => undef, # Recycling 660l
        6843 => undef, # Recycling 240l
        # all bins?
        # large food caddy?
        # small food caddy?
    );

    my $bartec = $self->feature('bartec');
    $bartec = Integrations::Bartec->new(%$bartec);

    my $uprn = $property->{uprn};

    my @calls = (
        Jobs_Get => [ $uprn ],
        Features_Schedules_Get => [ $uprn ],
        Jobs_FeatureScheduleDates_Get => [ $uprn ],
        Premises_Detail_Get => [ $uprn ],
        Premises_Events_Get => [ $uprn ],
        Streets_Events_Get => [ $property->{usrn} ],
        ServiceRequests_Get => [ $uprn ],
        Premises_Attributes_Get => [ $uprn ],
    );

    # we can only do an async lookup and thus page refresh when navigating
    # directly to the bin days page, not when e.g. calling this sub as a result
    # of going to the /bulky page.
    my $async = $self->{c}->action eq 'waste/bin_days' && $self->{c}->req->method eq 'GET';

    my $results = $bartec->call_api($self->{c}, 'peterborough', 'bin_services_for_address:' . $uprn, $async, @calls);

    my $jobs = $results->{"Jobs_Get $uprn"};
    my $schedules = $results->{"Features_Schedules_Get $uprn"};
    my $jobs_featureschedules = $results->{"Jobs_FeatureScheduleDates_Get $uprn"};
    my $detail_uprn = $results->{"Premises_Detail_Get $uprn"};
    my $events_uprn = $results->{"Premises_Events_Get $uprn"};
    my $events_usrn = $results->{"Streets_Events_Get " . $property->{usrn}};
    my $requests = $results->{"ServiceRequests_Get $uprn"};
    my $attributes = $results->{"Premises_Attributes_Get $uprn"};

    my $code = $detail_uprn->{BLPUClassification}{ClassificationCode} || '';
    $property->{commercial_property} = $code =~ /^C/;

    my %attribs = map { $_->{AttributeDefinition}->{Name} => 1 } @$attributes;
    $property->{attributes} = \%attribs;

    my $job_dates = relevant_jobs($jobs_featureschedules, $uprn, $schedules);
    my $open_requests = $self->open_service_requests_for_uprn($uprn, $requests);

    my %feature_to_workpack;
    foreach (@$jobs) {
        my $workpack = $_->{WorkPack}{Name};
        my $name = $_->{Name};
        #my $start = construct_bin_date($_->{ScheduledStart})->ymd;
        #my $status = $_->{Status}{Status};
        $feature_to_workpack{$name} = $workpack;
    }

    my %lock_out_types = map { $_ => 1 } ('BIN NOT OUT', 'CONTAMINATION', 'EXCESS WASTE', 'OVERWEIGHT', 'WRONG COLOUR BIN', 'NO ACCESS - street', 'NO ACCESS');
    my %premise_dates_to_lock_out;
    my %street_workpacks_to_lock_out;
    foreach (@$events_uprn) {
        my $container_id = $_->{Features}{FeatureType}{ID};
        my $date = construct_bin_date($_->{EventDate})->ymd;
        my $type = $_->{EventType}{Description};
        next unless $lock_out_types{$type};
        my $types = $premise_dates_to_lock_out{$date}{$container_id} ||= [];
        push @$types, $type;
    }
    foreach (@$events_usrn) {
        my $workpack = $_->{Workpack}{Name};
        my $type = $_->{EventType}{Description};
        my $date = construct_bin_date($_->{EventDate});
        # e.g. NO ACCESS 1ST TRY, NO ACCESS 2ND TRY, NO ACCESS BAD WEATHE, NO ACCESS GATELOCKED, NO ACCESS PARKED CAR, NO ACCESS POLICE, NO ACCESS ROADWORKS
        $type = 'NO ACCESS - street' if $type =~ /NO ACCESS/;
        next unless $lock_out_types{$type};
        $street_workpacks_to_lock_out{$workpack} = { type => $type, date => $date };
    }

    my %schedules = map { $_->{JobName} => $_ } @$schedules;
    $self->{c}->stash->{open_service_requests} = $open_requests;

    $self->{c}->stash->{waste_features} = $self->feature('waste_features');

    my @out;
    my %seen_containers;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);

    foreach (@$job_dates) {
        my $last = construct_bin_date($_->{PreviousDate});
        my $next = construct_bin_date($_->{NextDate});
        my $name = $_->{JobName};
        my $container_id = $schedules{$name}->{Feature}->{FeatureType}->{ID};

        # Some properties may have multiple of the same containers - only display each once.
        next if $seen_containers{$container_id};
        $seen_containers{$container_id} = 1;

        my $report_service_id = $container_service_ids{$container_id};
        my @report_service_ids_open = grep { $open_requests->{$_} } $report_service_id;
        my $request_service_ids = $container_request_ids{$container_id};
        # Open request for same thing, or for all bins, or for large black bin
        my @request_service_ids_open = grep { $open_requests->{$_} || $open_requests->{425} || ($_ == 419 && $open_requests->{422}) } @$request_service_ids;

        my %requests_open = map { $_ => 1 } @request_service_ids_open;

        if ( $container_id == 6533 ) {    # Black bin
            $property->{has_black_bin} = 1;
        }

        my $last_obj = { date => $last, ordinal => ordinal($last->day) } if $last;
        my $next_obj = { date => $next, ordinal => ordinal($next->day) } if $next;
        my $row = {
            id => $_->{JobID},
            last => $last_obj,
            next => $next_obj,
            service_name => service_name_override()->{$name} || $name,
            schedule => $schedules{$name}->{Frequency},
            service_id => $container_id,
            request_containers => $request_service_ids,

            # can this container type be requested?
            request_allowed => $container_request_ids{$container_id} ? 1 : 0,
            # what's the maximum number of this container that can be request?
            request_max => $container_request_max{$container_id} || 0,
            # is there already an open bin request for this container?
            requests_open => \%requests_open,
            # can this collection be reported as having been missed?
            report_allowed => $last ? $self->_waste_report_allowed($last) : 0,
            # is there already a missed collection report open for this container
            # (or a missed assisted collection for any container)?
            report_open => ( @report_service_ids_open || $open_requests->{492} ) ? 1 : 0,
        };
        if ($row->{report_allowed}) {
            # We only get here if we're within the 1.5 day window after the collection.
            # Set this so missed food collections can always be reported, as they don't
            # have their own collection event.
            $self->{c}->stash->{any_report_allowed} = 1;

            # If on the day, but before 5pm, show a special message to call
            # (which is slightly different for staff, who are actually allowed to report)
            if ($last->ymd eq $now->ymd && $now->hour < 17) {
                my $is_staff = $self->{c}->user_exists && $self->{c}->user->from_body && $self->{c}->user->from_body->name eq "Peterborough City Council";
                $row->{report_allowed} = $is_staff ? 1 : 0;
                $row->{report_locked_out} = [ "ON DAY PRE 5PM" ];
                # Set a global flag to show things in the sidebar
                $self->{c}->stash->{on_day_pre_5pm} = 1;
            }
            # But if it has been marked as locked out, show that
            if (my $types = $premise_dates_to_lock_out{$last->ymd}{$container_id}) {
                $row->{report_allowed} = 0;
                $row->{report_locked_out} = $types;
            }
        }
        # Last date is last successful collection. If whole street locked out, it hasn't started
        my $workpack = $feature_to_workpack{$name} || '';
        if (my $lockout = $street_workpacks_to_lock_out{$workpack}) {
            $row->{report_allowed} = 0;
            $row->{report_locked_out} = [ $lockout->{type} ];
            my $last = $lockout->{date};
            $row->{last} = { date => $last, ordinal => ordinal($last->day) };
        }
        push @out, $row;
    }

    $property->{show_bulky_waste} = $self->bulky_allowed_property($property);

    # Some need to be added manually as they don't appear in Bartec responses
    # as they're not "real" collection types (e.g. requesting all bins)

    my $bags_only = $self->{c}->get_param('bags_only');
    my $skip_bags = $self->{c}->get_param('skip_bags');

    @out = () if $bags_only;

    my @food_containers;
    if ($bags_only) {
        push(@food_containers, 428) unless $open_requests->{428};
    } else {
        unless ( $open_requests->{493} || $open_requests->{425} ) { # Both food bins, or all bins
            push(@food_containers, 424) unless $open_requests->{424}; # Large food caddy
            push(@food_containers, 423) unless $open_requests->{423}; # Small food caddy
        }
        push(@food_containers, 428) unless $skip_bags || $open_requests->{428};
    }

    push(@out, {
        id => "FOOD_BINS",
        service_name => "Food bins",
        service_id => "FOOD_BINS",
        request_containers => \@food_containers,
        request_allowed => 1,
        request_max => 1,
        request_only => 1,
        report_only => !$open_requests->{252}, # Can report if no open report
    }) if @food_containers;

    # All bins, black bin, green bin, large black bin, small food caddy, large food caddy, both food bins
    my $any_open_bin_request = any { $open_requests->{$_} } (425, 419, 420, 422, 423, 424, 493);
    unless ( $bags_only || $any_open_bin_request ) {
        # We want this one to always appear first
        unshift @out, {
            id => "_ALL_BINS",
            service_name => "All bins",
            service_id => "_ALL_BINS",
            request_containers => [ 425 ],
            request_allowed => 1,
            request_max => 1,
            request_only => 1,
        };
    }
    return \@out;
}

sub relevant_jobs {
    my ($jobs, $uprn, $schedules) = @_;
    my %schedules = map { $_->{JobName} => $_ } @$schedules;
    my @jobs = grep {
        my $name = $_->{JobName};
        my $schedule_name = $schedules{$name}->{Feature}->{Status}->{Name} || '';
        $schedule_name eq 'IN SERVICE'
        && $schedules{$name}->{Feature}->{FeatureType}->{ID} != 6815;
    } @$jobs;
    return \@jobs;
}

=pod

Missed bins can be reported up until 4pm the working day following the last
collection day. So a bin not collected on Tuesday can be rung through up to
4pm on Wednesday, and one not collected on Friday can be rung through up to
4pm Monday.

=cut

sub _waste_report_allowed {
    my ($self, $dt) = @_;

    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());
    $dt = $wd->add_days($dt, 1);
    $dt->set( hour => 16, minute => 0, second => 0 );
    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    return $now <= $dt;
}

sub bin_future_collections {
    my $self = shift;

    my $bartec = $self->feature('bartec');
    $bartec = Integrations::Bartec->new(%$bartec);

    my $uprn = $self->{c}->stash->{property}{uprn};
    my $schedules = $bartec->Features_Schedules_Get($uprn);
    my $jobs_featureschedules = $bartec->Jobs_FeatureScheduleDates_Get($uprn);
    my $jobs = relevant_jobs($jobs_featureschedules, $uprn, $schedules);

    my $events = [];
    foreach (@$jobs) {
        my $dt = construct_bin_date($_->{NextDate});
        push @$events, { date => $dt, desc => '', summary => $_->{JobName} };
    }
    return $events;
}

sub open_service_requests_for_uprn {
    my ($self, $uprn, $requests) = @_;

    my %open_requests;
    foreach (@$requests) {
        my $service_id = $_->{ServiceType}->{ID};
        my $status = $_->{ServiceStatus}->{Status};
        # XXX need to confirm that this list is complete and won't change in the future...
        next unless $status =~ /PENDING|INTERVENTION|OPEN|ASSIGNED|IN PROGRESS/;
        $open_requests{$service_id} = 1;
    }
    return \%open_requests;
}

sub waste_munge_request_form_data {
    my ($self, $data) = @_;

    # In the UI we show individual checkboxes for large and small food caddies.
    # If the user requests both containers then we want to raise a single
    # request for both, rather than one request for each.
    if ($data->{"container-424"} && $data->{"container-423"}) {
        $data->{"container-424"} = 0;
        $data->{"container-423"} = 0;
        $data->{"container-493"} = 1;
        $data->{"quantity-493"} = 1;
    }
}

sub waste_munge_report_form_data {
    my ($self, $data) = @_;

    my $attributes = $self->{c}->stash->{property}->{attributes};

    if ( $attributes->{"ASSISTED COLLECTION"} ) {
        # For assisted collections we just raise a single "missed assisted collection"
        # report, instead of the usual thing of one per container.
        # The details of the bins that were missed are stored in the problem body.

        $data->{assisted_detail} = "";
        $data->{assisted_detail} .= "Food bins\n\n" if $data->{"service-FOOD_BINS"};
        $data->{assisted_detail} .= "Black bin\n\n" if $data->{"service-6533"};
        $data->{assisted_detail} .= "Green bin\n\n" if $data->{"service-6534"};
        $data->{assisted_detail} .= "Brown bin\n\n" if $data->{"service-6579"};

        $data->{"service-FOOD_BINS"} = 0;
        $data->{"service-6533"} = 0;
        $data->{"service-6534"} = 0;
        $data->{"service-6579"} = 0;
        $data->{"service-ASSISTED_COLLECTION"} = 1;
    }
}

sub waste_munge_report_form_fields {
    my ($self, $field_list) = @_;

    push @$field_list, "extra_detail" => {
        type => 'Text',
        widget => 'Textarea',
        label => 'Please supply any additional information such as the location of the bin.',
        maxlength => 1_000,
        messages => {
            text_maxlength => 'Please use 1000 characters or less for additional information.',
        },
    };
}

sub waste_munge_request_data {
    my ($self, $id, $data) = @_;

    my $c = $self->{c};

    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $quantity = $data->{"quantity-$id"};
    my $reason = $data->{request_reason} || '';

    $reason = {
        lost_stolen => 'Lost/stolen bin',
        new_build => 'New build',
        other_staff => '(Other - PD STAFF)',
    }->{$reason} || $reason;

    $data->{title} = "Request new $container";
    $data->{detail} = "Quantity: $quantity\n\n$address";
    $data->{detail} .= "\n\nReason: $reason" if $reason;

    if ( $data->{extra_detail} ) {
        $data->{detail} .= "\n\nExtra detail: " . $data->{extra_detail};
    }

    $data->{category} = $self->body->contacts->find({ email => "Bartec-$id" })->category;
}

sub waste_cc_payment_line_item_ref {
    my ($self, $p) = @_;
    return "BULKY-" . $p->get_extra_field_value('uprn') . "-" .$p->get_extra_field_value('DATE');
}

sub waste_cc_payment_admin_fee_line_item_ref {
    my ($self, $p) = @_;
    return "BULKY-" . $p->get_extra_field_value('uprn') . "-" .$p->get_extra_field_value('DATE');
}

sub waste_cc_payment_sale_ref {
    my ($self, $p) = @_;
    return "BULKY-" . $p->get_extra_field_value('uprn') . "-" .$p->get_extra_field_value('DATE');
}

sub bin_payment_types {
    return {
        'csc' => 1,
        'credit_card' => 2,
        'direct_debit' => 3,
    };
}

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'paye';
}

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    if ( $service->{service_name} eq 'Bulky collection' ) {
        push @$meta, {
            code => 'payment',
            datatype => 'string',
            description => 'Payment',
            order => 101,
            required => 'false',
            variable => 'true',
            automated => 'hidden_field',
        }, {
            code => 'payment_method',
            datatype => 'string',
            description => 'Payment method',
            order => 101,
            required => 'false',
            variable => 'true',
            automated => 'hidden_field',
        }, {
            code => 'property_id',
            datatype => 'string',
            description => 'Property ID',
            order => 101,
            required => 'false',
            variable => 'true',
            automated => 'hidden_field',
        };
    }
}

sub waste_munge_report_data {
    my ($self, $id, $data) = @_;
    my $c = $self->{c};

    my %container_service_ids = (
        "FOOD_BINS" => 252, # Food bins (pseudocontainer hardcoded in bin_services_for_address)
        "ASSISTED_COLLECTION" => 492, # Will only be set by waste_munge_report_form_data (if property has assisted attribute)
        6533 => 255, # 240L Black
        6534 => 254, # 240L Green
        6579 => 253, # 240L Brown
        6836 => undef, # Refuse 1100l
        6837 => undef, # Refuse 660l
        6839 => undef, # Refuse 240l
        6840 => undef, # Recycling 1100l
        6841 => undef, # Recycling 660l
        6843 => undef, # Recycling 240l
    );

    my $service_id = $container_service_ids{$id};

    if ($service_id == 255) {
        my $attributes = $c->stash->{property}->{attributes};
        if ($attributes->{"LARGE BIN"}) {
            # For large bins, we need different text to show
            $id = "LARGE BIN";
        }
    }

    if ( $data->{assisted_detail} ) {
        $data->{title} = "Report missed assisted collection";
        $data->{detail} = $data->{assisted_detail};
        $data->{detail} .= "\n\n" . $c->stash->{property}->{address};
    } else {
        my $container = $c->stash->{containers}{$id};
        $data->{title} = "Report missed $container";
        $data->{title} .= " bin" if $container !~ /^Food/;
        $data->{detail} = $c->stash->{property}->{address};
    }

    if ( $data->{extra_detail} ) {
        $data->{detail} .= "\n\nExtra detail: " . $data->{extra_detail};
    }

    $data->{category} = $self->body->contacts->find({ email => "Bartec-$service_id" })->category;
}

sub waste_munge_problem_data {
    my ($self, $id, $data) = @_;
    my $c = $self->{c};

    my $service_details = $self->{c}->stash->{services_problems}->{$id};
    my $container_id = $service_details->{container} || 0; # 497 doesn't have a container

    my $category = $self->body->contacts->find({ email => "Bartec-$id" })->category;
    my $category_verbose = $service_details->{label};

    if ($container_id == 6533 && $category =~ /Lid|Wheels/) { # 240L Black repair
        my $attributes = $c->stash->{property}->{attributes};
        if ($attributes->{"LARGE BIN"}) {
            # For large bins, we need to raise a new bin request instead
            $container_id = "LARGE BIN";
            $category = 'Black 360L bin';
            $category_verbose .= ", exchange bin";
        }
    }

    my $bin = $c->stash->{containers}{$container_id};
    $data->{category} = $category;
    $data->{title} = $category =~ /Lid|Wheels/ ? "Damaged $bin bin" :
                    $category =~ /Not returned/ ? "Bin not returned" : $bin;
    $data->{detail} = "$category_verbose\n\n" . $c->stash->{property}->{address};
    if ( $data->{extra_detail} ) {
        $data->{detail} .= "\n\nExtra detail: " . $data->{extra_detail};
    }
}

sub waste_munge_problem_form_fields {
    my ($self, $field_list) = @_;

    my $not_staff = !($self->{c}->user_exists && $self->{c}->user->from_body && $self->{c}->user->from_body->name eq "Peterborough City Council");
    my $label_497 = $not_staff
    ? 'The bin wasn’t returned to the collection point (Please phone 01733 747474 to report this issue)'
    : 'The bin wasn’t returned to the collection point';

    my %services_problems = (
        538 => {
            container => 6533,
            container_name => "Black bin",
            label => "The bin’s lid is damaged",
        },
        541 => {
            container => 6533,
            container_name => "Black bin",
            label => "The bin’s wheels are damaged",
        },
        537 => {
            container => 6534,
            container_name => "Green bin",
            label => "The bin’s lid is damaged",
        },
        540 => {
            container => 6534,
            container_name => "Green bin",
            label => "The bin’s wheels are damaged",
        },
        539 => {
            container => 6579,
            container_name => "Brown bin",
            label => "The bin’s lid is damaged",
        },
        542 => {
            container => 6579,
            container_name => "Brown bin",
            label => "The bin’s wheels are damaged",
        },
        497 => {
            container_name => "General",
            label => $label_497,
            disabled => $not_staff,
        },
    );
    $self->{c}->stash->{services_problems} = \%services_problems;

    my %services;
    foreach (keys %services_problems) {
        my $v = $services_problems{$_};
        next unless $v->{container};
        $services{$v->{container}} ||= {};
        $services{$v->{container}}{$_} = $v->{label};
    }

    my $open_requests = $self->{c}->stash->{open_service_requests};
    @$field_list = ();

    foreach (@{$self->{c}->stash->{service_data}}) {
        my $id = $_->{service_id};
        my $name = $_->{service_name};

        next unless $services{$id};

        # Don't allow any problem reports on a bin if a new one is currently
        # requested. Check for large bin requests for black bins as well
        # 419/420 are new black/green bin requests, 422 is large black bin request
        # 6533/6534 are black/green containers
        my $black_bin_request = (($open_requests->{419} || $open_requests->{422}) && $id == 6533);
        my $green_bin_request = ($open_requests->{420} && $id == 6534);

        my $categories = $services{$id};
        foreach (sort keys %$categories) {
            my $cat_name = $categories->{$_};
            my $disabled = $open_requests->{$_} || $black_bin_request || $green_bin_request;
            push @$field_list, "service-$_" => {
                type => 'Checkbox',
                label => $name,
                option_label => $cat_name,
                disabled => $disabled,
            };

            # Set this to empty so the heading isn't shown multiple times
            $name = '';
        }
    }
    push @$field_list, "service-497" => {
        type => 'Checkbox',
        label => $self->{c}->stash->{services_problems}->{497}->{container_name},
        option_label => $self->{c}->stash->{services_problems}->{497}->{label},
        disabled => $open_requests->{497} || $self->{c}->stash->{services_problems}->{497}->{disabled},
    };

    push @$field_list, "extra_detail" => {
        type => 'Text',
        widget => 'Textarea',
        label => 'Please supply any additional information such as the location of the bin.',
        maxlength => 1_000,
        messages => {
            text_maxlength => 'Please use 1000 characters or less for additional information.',
        },
    };

}

sub waste_request_form_first_next {
    my $self = shift;
    $self->{c}->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Request::Peterborough';
    $self->{c}->stash->{form_title} = 'Which bins do you need?';
    return 'replacement' unless $self->{c}->get_param('bags_only');
    return 'about_you';
}

sub _format_address {
    my ($self, $property) = @_;

    my $a = $property->{Address};
    my $prefix = join(" ", $a->{Address1}, $a->{Address2}, $a->{Street});
    return Utils::trim_text(FixMyStreet::Template::title(join(", ", $prefix, $a->{Town}, $a->{PostCode})));
}

sub bin_day_format { '%A, %-d~~~ %B %Y' }

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

1;
