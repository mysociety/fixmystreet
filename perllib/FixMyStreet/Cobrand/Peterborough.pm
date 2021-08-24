package FixMyStreet::Cobrand::Peterborough;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use utf8;
use strict;
use warnings;
use Integrations::Bartec;
use Sort::Key::Natural qw(natkeysort_inplace);
use FixMyStreet::WorkingDays;
use Utils;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { 2566 }
sub council_area { 'Peterborough' }
sub council_name { 'Peterborough City Council' }
sub council_url { 'peterborough' }
sub default_map_zoom { 5 }

sub send_questionnaires { 0 }

sub max_title_length { 50 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.6085234396978,-0.253091266573947',
        bounds => [ 52.5060949603654, -0.497663559599628, 52.6752139533306, -0.0127696975457487 ],
    };
}

sub get_geocoder { 'OSM' }

sub contact_extra_fields { [ 'display_name' ] }

sub geocoder_munge_results {
    my ($self, $result) = @_;
    $result->{display_name} = '' unless $result->{display_name} =~ /City of Peterborough/;
    $result->{display_name} =~ s/, UK$//;
    $result->{display_name} =~ s/, City of Peterborough, East of England, England//;
}

sub admin_user_domain { "peterborough.gov.uk" }

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
        my $address = $row->geocode->{resourceSets}->[0]->{resources}->[0]->{address};
        my ($number, $street) = $address->{addressLine} =~ /\s*(\d*)\s*(.*)/;
        push @$open311_only, (
            { name => 'postcode', value => $address->{postalCode} },
            { name => 'house_no', value => $number },
            { name => 'street', value => $street }
        );
    }
    return $open311_only;
};
# remove categories which are informational only
sub open311_extra_data_exclude { [ '^PCC-', '^emergency$', '^private_land$' ] }

sub lookup_site_code_config { {
    buffer => 50, # metres
    url => "https://tilma.mysociety.org/mapserver/peterborough",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "highways",
    property => "Usrn",
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

    my $contact = $comment->problem->contact;
    $params->{service_code} = $contact->email;
}

around 'open311_config' => sub {
    my ($orig, $self, $row, $h, $params) = @_;

    $params->{upload_files} = 1;
    $self->$orig($row, $h, $params);
};

sub get_body_sender {
    my ($self, $body, $problem) = @_;
    my %flytipping_cats = map { $_ => 1 } @{ $self->_flytipping_categories };

    my ($x, $y) = Utils::convert_latlon_to_en(
        $problem->latitude,
        $problem->longitude,
        'G'
    );
    if ( $flytipping_cats{ $problem->category } ) {
        # look for land belonging to the council
        my $features = $self->_fetch_features(
            {
                type => 'arcgis',
                url => 'https://peterborough.assets/2/query?',
                buffer => 1,
            },
            $x,
            $y,
        );

        # if not then check if it's land leased out or on a road.
        unless ( $features && scalar @$features ) {
            my $leased_features = $self->_fetch_features(
                {
                    type => 'arcgis',
                    url => 'https://peterborough.assets/3/query?',
                    buffer => 1,
                },
                $x,
                $y,
            );

            # some PCC land is leased out and not dealt with in bartec
            $features = [] if $leased_features && scalar @$leased_features;

            # if it's not council, or leased out land check if it's on an
            # adopted road
            unless ( $leased_features && scalar @$leased_features ) {
                my $road_features = $self->_fetch_features(
                    {
                        buffer => 1, # metres
                        url => "https://tilma.mysociety.org/mapserver/peterborough",
                        srsname => "urn:ogc:def:crs:EPSG::27700",
                        typename => "highways",
                        property => "Usrn",
                        accept_feature => sub { 1 },
                        accept_types => { Polygon => 1 },
                    },
                    $x,
                    $y,
                );

                $features = $road_features if $road_features && scalar @$road_features;
            }
        }

        # is on land that is handled by bartec so send
        if ( $features && scalar @$features ) {
            return $self->SUPER::get_body_sender($body, $problem);
        }

        # neither of those so just send email for records
        my $emails = $self->feature('open311_email');
        if ( $emails->{flytipping} ) {
            my $contact = $self->SUPER::get_body_sender($body, $problem)->{contact};
            $problem->set_extra_metadata('flytipping_email' => $emails->{flytipping});
            return { method => 'Email', contact => $contact};
        }
    }

    return $self->SUPER::get_body_sender($body, $problem);
}

sub munge_sendreport_params {
    my ($self, $row, $h, $params) = @_;

    if ( $row->get_extra_metadata('flytipping_email') ) {
        $params->{To} = [ [
            $row->get_extra_metadata('flytipping_email'), $self->council_name
        ] ];
    }
}

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # Check Open311 was successful
    return unless $row->external_id;

    my $emails = $self->feature('open311_email');
    my %flytipping_cats = map { $_ => 1 } @{ $self->_flytipping_categories };
    if ( $emails->{flytipping} && $flytipping_cats{$row->category} ) {
        my $dest = [ $emails->{flytipping}, "Environmental Services" ];
        my $sender = FixMyStreet::SendReport::Email->new( to => [ $dest ] );
        $sender->send($row, $h);
    }
}

sub post_report_sent {
    my ($self, $problem) = @_;

    if ( $problem->get_extra_metadata('flytipping_email') ) {
        my @include_path = @{ $self->path_to_web_templates };
        push @include_path, FixMyStreet->path_to( 'templates', 'web', 'default' );
        my $tt = FixMyStreet::Template->new({
            INCLUDE_PATH => \@include_path,
            disable_autoescape => 1,
        });
        my $text;
        $tt->process('report/new/flytipping_text.html', {}, \$text);

        $problem->update({
            state => 'closed'
        });
        FixMyStreet::DB->resultset('Comment')->create({
            user_id => $self->body->comment_user_id,
            problem => $problem,
            state => 'confirmed',
            cobrand => $problem->cobrand,
            cobrand_data => '',
            problem_state => 'closed',
            text => $text,
        });
        $problem->unset_extra_metadata('flytipping_email');
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

        my $address = '';
        $address = $report->geocode->{resourceSets}->[0]->{resources}->[0]->{name}
            if $report->geocode;

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

=head2 Waste product code

Functions specific to the waste product & Bartec integration.

=cut 

=head2 munge_around_category_where, munge_reports_category_list, munge_report_new_contacts

These filter out waste-related categories from the main FMS report flow.
TODO: Are these small enough to be here or should they be in a Role?

=cut 

sub munge_around_category_where {
    my ($self, $where) = @_;
    $where->{extra} = [ undef, { -not_like => '%T10:waste_only,I1:1%' } ];
}

sub munge_reports_category_list {
    my ($self, $categories) = @_;
    @$categories = grep { !$_->get_extra_metadata('waste_only') } @$categories;
}

sub munge_report_new_contacts {
    my ($self, $categories) = @_;

    if ($self->{c}->action =~ /^waste/) {
        @$categories = grep { $_->get_extra_metadata('waste_only') } @$categories;
        return;
    }

    @$categories = grep { !$_->get_extra_metadata('waste_only') } @$categories;
    $self->SUPER::munge_report_new_contacts($categories);
}

sub _premises_for_postcode {
    my $self = shift;
    my $pc = shift;

    my $key = "peterborough:bartec:premises_for_postcode:$pc";

    unless ( $self->{c}->session->{$key} ) {
        my $bartec = $self->feature('bartec');
        $bartec = Integrations::Bartec->new(%$bartec);
        my $response = $bartec->Premises_Get($pc);

        $self->{c}->session->{$key} = [ map { {
            id => $pc . ":" . $_->{UPRN},
            uprn => $_->{UPRN},
            usrn => $_->{USRN},
            address => $self->_format_address($_),
            latitude => $_->{Location}->{Metric}->{Latitude},
            longitude => $_->{Location}->{Metric}->{Longitude},
        } } @$response ];
    }

    return $self->{c}->session->{$key};
}

sub clear_cached_lookups {
    my ($self, $id) = @_;
    my ($pc, $uprn) = split ":", $id;
    my $key = "peterborough:bartec:premises_for_postcode:$pc";
    delete $self->{c}->session->{$key};
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

    my ($pc, $uprn) = split ":", $id;

    my $premises = $self->_premises_for_postcode($pc);

    my %premises = map { $_->{uprn} => $_ } @$premises;

    return $premises{$uprn};
}

sub image_for_service {
    my ($self, $service_id) = @_;
    my $base = '/cobrands/peterborough/images';
    my $images = {
        6533 => "$base/black-bin",
        6534 => "$base/green-bin",
        6579 => "$base/brown-bin",
    };
    return $images->{$service_id};
}


sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

    my %service_name_override = (
        "Empty Bin 240L Black" => "Black Bin",
        "Empty Bin 240L Brown" => "Brown Bin",
        "Empty Bin 240L Green" => "Green Bin",
        "Empty Black 240l Bin" => "Black Bin",
        "Empty Brown 240l Bin" => "Brown Bin",
        "Empty Green 240l Bin" => "Green Bin",
        "Empty Bin Recycling 1100l" => "Recycling",
        "Empty Bin Recycling 240l" => "Recycling",
        "Empty Bin Recycling 660l" => "Recycling",
        "Empty Bin Refuse 1100l" => "Refuse",
        "Empty Bin Refuse 240l" => "Refuse",
        "Empty Bin Refuse 660l" => "Refuse",
    );

    $self->{c}->stash->{enquiry_cat_ids} = [ 497, 236, 237 ];
    $self->{c}->stash->{enquiry_cats} = {
        497 => 'Not returned to collection point',
        236 => 'Lid',
        237 => 'Wheels',
    };
    $self->{c}->stash->{enquiry_verbose} = {
        'Not returned to collection point' => 'The bin wasn’t returned to the collection point',
        'Lid' => 'The bin’s lid is damaged',
        'Wheels' => 'The bin’s wheels are damaged',
    };

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

    my %container_removal_ids = (
        6533 => [ 487 ], # 240L Black
        6534 => [ 488 ], # 240L Green
        6579 => [ 489 ], # 240L Brown
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
        6534 => 2, # 240L Green (max 2 per household, need to check how many property already has dynamically)
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

    # TODO parallelize these calls if performance is an issue
    my $jobs = $bartec->Jobs_FeatureScheduleDates_Get($property->{uprn});
    my $schedules = $bartec->Features_Schedules_Get($property->{uprn});
    my $events_uprn = $bartec->Premises_Events_Get($property->{uprn});
    my $events_usrn = $bartec->Streets_Events_Get($property->{usrn});
    my $open_requests = $self->open_service_requests_for_uprn($property->{uprn}, $bartec);

    my %lock_out_types = map { $_ => 1 } ('BIN NOT OUT', 'CONTAMINATION', 'EXCESS WASTE', 'OVERWEIGHT', 'WRONG COLOUR BIN', 'NO ACCESS - street', 'NO ACCESS');
    my %premise_dates_to_lock_out;
    my %street_dates_to_lock_out;
    foreach (@$events_uprn) {
        my $container_id = $_->{Features}{FeatureType}{ID};
        my $date = construct_bin_date($_->{EventDate})->ymd;
        my $type = $_->{EventType}{Description};
        next unless $lock_out_types{$type};
        $premise_dates_to_lock_out{$date}{$container_id} = $type;
    }
    foreach (@$events_usrn) {
        my $date = construct_bin_date($_->{EventDate})->ymd;
        my $type = $_->{EventType}{Description};
        # e.g. NO ACCESS 1ST TRY, NO ACCESS 2ND TRY, NO ACCESS BAD WEATHE, NO ACCESS GATELOCKED, NO ACCESS PARKED CAR, NO ACCESS POLICE, NO ACCESS ROADWORKS
        $type = 'NO ACCESS - street' if $type =~ /NO ACCESS/;
        next unless $lock_out_types{$type};
        $street_dates_to_lock_out{$date} = $type;
    }

    my %schedules = map { $_->{JobName} => $_ } @$schedules;
    $self->{c}->stash->{open_service_requests} = $open_requests;

    $self->{c}->stash->{waste_features} = $self->feature('waste_features');

    my @out;
    my %seen_containers;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    foreach (@$jobs) {
        my $last = construct_bin_date($_->{PreviousDate});
        my $next = construct_bin_date($_->{NextDate});
        my $container_id = $schedules{$_->{JobName}}->{Feature}->{FeatureType}->{ID};

        # Some properties may have multiple of the same containers - only display each once.
        next if $seen_containers{$container_id};
        $seen_containers{$container_id} = 1;

        my $report_service_ids = $container_removal_ids{$container_id};
        my @report_service_ids_open = grep { $open_requests->{$_} } @$report_service_ids;
        my $request_service_ids = $container_request_ids{$container_id};
        my @request_service_ids_open = grep { $open_requests->{$_} } @$request_service_ids;

        my $row = {
            id => $_->{JobID},
            last => { date => $last, ordinal => ordinal($last->day) },
            next => { date => $next, ordinal => ordinal($next->day) },
            service_name => $service_name_override{$_->{JobDescription}} || $_->{JobDescription},
            schedule => $schedules{$_->{JobName}}->{Frequency},
            service_id => $container_id,
            request_containers => $container_request_ids{$container_id},

            # can this container type be requested?
            request_allowed => $container_request_ids{$container_id} ? 1 : 0,
            # what's the maximum number of this container that can be request?
            request_max => $container_request_max{$container_id} || 0,
            # is there already an open bin request for this container?
            request_open => @request_service_ids_open ? 1 : 0,
            # can this collection be reported as having been missed?
            report_allowed => $property->{uprn} eq '100090222444' ? 1 : $self->_waste_report_allowed($last),
            # is there already a missed collection report open for this container
            # (or a missed assisted collection for any container)?
            report_open => $property->{uprn} eq '100090222444' ? 0 : ( @report_service_ids_open || $open_requests->{492} ) ? 1 : 0,
        };
        if ($row->{report_allowed}) {
            # If on the day, but before 5pm, show a special message to call
            if ($row->{last}{date}->ymd eq $now->ymd && $now->hour < 17) {
                $row->{report_allowed} = 0;
                $row->{report_locked_out} = "ON DAY PRE 5PM";
            }
            # But if it has been marked as locked out, show that
            if (my $type = ($premise_dates_to_lock_out{$last->ymd}{$container_id} || $street_dates_to_lock_out{$last->ymd})) {
                $row->{report_allowed} = 0;
                $row->{report_locked_out} = $type;
            }
        }
        push @out, $row;
    }

    # Some need to be added manually as they don't appear in Bartec responses
    # as they're not "real" collection types (e.g. requesting all bins)
    push @out, {
        id => "FOOD_BINS",
        service_name => "Food bins",
        service_id => "FOOD_BINS",
        request_containers => [ 424, 423, 428 ],
        request_allowed => 1,
        request_max => 1,
        request_only => 1,
        report_only => 1,
    };
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

    return \@out;
}

sub _waste_report_allowed {
    my ($self, $dt) = @_;

    # missed bin reports are allowed if we're within 1.5 working days of the last collection day
    # e.g.:
    #  A bin not collected on Tuesday can be rung through up to noon Thursday
    #  A bin not collected on Thursday can be rung through up to noon Monday

    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());
    $dt = $wd->add_days($dt, 2);
    $dt->set( hour => 12, minute => 0, second => 0 );
    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    return $now <= $dt;
}

sub bin_future_collections {
    my $self = shift;

    my $bartec = $self->feature('bartec');
    $bartec = Integrations::Bartec->new(%$bartec);

    my $jobs = $bartec->Jobs_FeatureScheduleDates_Get($self->{c}->stash->{property}{uprn});

    my $events = [];
    foreach (@$jobs) {
        my $dt = construct_bin_date($_->{NextDate});
        push @$events, { date => $dt, desc => '', summary => $_->{JobName} };
    }
    return $events;
}

sub open_service_requests_for_uprn {
    my ($self, $uprn, $bartec) = @_;

    my $requests = $bartec->ServiceRequests_Get($uprn);

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

sub property_attributes {
    my ($self, $uprn, $bartec) = @_;

    unless ($bartec) {
        $bartec = $self->feature('bartec');
        $bartec = Integrations::Bartec->new(%$bartec);
    }

    my $attributes = $bartec->Premises_Attributes_Get($uprn);
    my %attribs = map { $_->{AttributeDefinition}->{Name} => 1 } @$attributes;

    return \%attribs;
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

    my $uprn = $self->{c}->stash->{property}->{uprn};
    my $attributes = $self->property_attributes($uprn);

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

sub waste_munge_request_data {
    my ($self, $id, $data) = @_;

    my $c = $self->{c};

    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $quantity = $data->{"quantity-$id"};
    $data->{title} = "Request new $container";
    $data->{detail} = "Quantity: $quantity\n\n$address";
    if (my $reason = $data->{"reason-$id"}) {
        $data->{detail} .= "\n\nReason: $reason";
    }
    $data->{category} = $self->body->contacts->find({ email => "Bartec-$id" })->category;
}

sub waste_munge_report_data {
    my ($self, $id, $data) = @_;

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
        # black 360L?
    );


    my $c = $self->{c};

    my $service_id = $container_service_ids{$id};
    my $container = $c->stash->{containers}{$id};
    if ( $data->{assisted_detail} ) {
        $data->{title} = "Report missed assisted collection";
        $data->{detail} = $data->{assisted_detail};
        $data->{detail} .= "\n\n" . $c->stash->{property}->{address};
    } else {
        $data->{title} = "Report missed $container";
        $data->{detail} = $c->stash->{property}->{address};
    }

    $data->{category} = $self->body->contacts->find({ email => "Bartec-$service_id" })->category;
}

sub waste_munge_enquiry_data {
    my ($self, $data) = @_;

    my %container_ids = (
        6533 => "240L Black",
        6534 => "240L Green",
        6579 => "240L Brown",
    );

    my $verbose = $self->{c}->stash->{enquiry_verbose};
    my $bin = $container_ids{$self->{c}->get_param('service_id')};
    my $category = $self->{c}->get_param('category');
    my $category_verbose = $verbose->{$category} || $category;
    $data->{category} = $category;
    $data->{title} = $bin;
    $data->{detail} = $category_verbose . "\n\n" . $self->{c}->stash->{property}->{address};
}



sub bin_request_form_extra_fields {
    my ($self, $service, $container_id, $field_list) = @_;

    if ($container_id =~ /419|425/) { # Request New Black 240L
        # Add a new "reason" field
        push @$field_list, "reason-$container_id" => {
            type => 'Text',
            label => 'Why do you need new bins?',
            tags => {
                initial_hidden => 1,
            },
            required_when => { "container-$container_id" => 1 },
        };
        # And make sure it's revealed when the box is ticked
        my %fields = @$field_list;
        $fields{"container-$container_id"}{tags}{toggle} .= ", #form-reason-$container_id-row";
    }
}


sub _format_address {
    my ($self, $property) = @_;

    my $a = $property->{Address};
    my $prefix = join(" ", $a->{Address1}, $a->{Address2}, $a->{Street});
    return Utils::trim_text(FixMyStreet::Template::title(join(", ", $prefix, $a->{Town}, $a->{PostCode})));
}

sub bin_day_format { '%A, %-d~~~ %B %Y' }

1;
