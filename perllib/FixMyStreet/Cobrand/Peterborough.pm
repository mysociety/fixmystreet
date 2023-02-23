package FixMyStreet::Cobrand::Peterborough;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use utf8;
use strict;
use warnings;
use DateTime;
use DateTime::Format::Strptime;
use Integrations::Bartec;
use List::Util qw(any);
use Sort::Key::Natural qw(natkeysort_inplace);
use FixMyStreet::Email;
use FixMyStreet::WorkingDays;
use Utils;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';
with 'FixMyStreet::Roles::Open311Multi';
with 'FixMyStreet::Roles::SCP';

sub council_area_id { 2566 }
sub council_area { 'Peterborough' }
sub council_name { 'Peterborough City Council' }
sub council_url { 'peterborough' }
sub default_map_zoom { 5 }

sub send_questionnaires { 0 }

sub max_title_length { 50 }

sub service_name_override {
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

# XXX Use config to set max daily slots etc.
sub bulky_collection_window_days     {90}
sub max_bulky_collection_dates       {4}
sub bulky_workpack_name {
    qr/Waste-(BULKY WASTE|WHITES)-(?<date_suffix>\d{6})/;
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
                url => 'https://peterborough.assets/4/query?',
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
                        type => 'arcgis',
                        url => 'https://peterborough.assets/7/query?',
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

sub _witnessed_general_flytipping {
    my $row = shift;
    my $witness = $row->get_extra_metadata('pcc_witness') || '';
    return ($row->category eq 'General fly tipping' && $witness eq 'yes');
}

sub open311_pre_send {
    my ($self, $row, $open311) = @_;
    return 'SKIP' if _witnessed_general_flytipping($row);
}

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # Check Open311 was successful
    my $send_email = $row->external_id || _witnessed_general_flytipping($row);
    # Unset here because check above used it
    $row->unset_extra_metadata('pcc_witness');
    return unless $send_email;

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

        $problem->unset_extra_metadata('flytipping_email');
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

    $premises{$uprn}{pending_bulky_collection}
        = $self->find_pending_bulky_collection( $premises{$uprn} );

    return $premises{$uprn};
}

# Should only be a single open collection for a given property, but in case
# there isn't, return the most recent
sub find_pending_bulky_collection {
    my ( $self, $property ) = @_;

    return FixMyStreet::DB->resultset('Problem')->to_body( $self->body )
        ->find(
        {   category => 'Bulky collection',
            extra    => {
                      like => '%T4:uprn,T5:value,I'
                    . length( $property->{uprn} ) . ':'
                    . $property->{uprn} . '%',
            },
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
            $action_name = service_name_override()->{$action_name}
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
        # Can only book the next day up to 3pm
        if ($now->hour >= 15) {
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

has wasteworks_config => (
    is => 'lazy',
    default => sub { $_[0]->body->get_extra_metadata( 'wasteworks_config', {} ) },
);

sub bulky_items_master_list { $_[0]->wasteworks_config->{item_list} || [] }
sub bulky_items_maximum { $_[0]->wasteworks_config->{items_per_collection_max} || 5 }
sub bulky_daily_slots { $_[0]->wasteworks_config->{daily_slots} || 40 }

sub bulky_per_item_costs {
    my $self = shift;
    my $cfg  = $self->body->get_extra_metadata( 'wasteworks_config', {} );
    return $cfg->{per_item_costs};
}

sub bulky_can_cancel_collection {
    # There is an $ignore_external_id option because we display some
    # cancellation messaging without needing a report in Bartec
    my ( $self, $collection, $ignore_external_id ) = @_;

    return
           $collection
        && $collection->is_open
        && ( $collection->external_id || $ignore_external_id )
        && $self->bulky_can_view_collection($collection)
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
                      like => '%T18:ORIGINAL_SR_NUMBER,T5:value,T'
                    . length($original_sr_number) . ':'
                    . $original_sr_number . '%',
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

# Collections are scheduled to begin at 06:45 each day.
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

    my $cutoff_dt = $collection_dt->clone->set( hour => 6, minute => 45 )
        ->subtract( hours => 24 );

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

    return $self->_check_within_bulky_cancel_window( $now_dt,
        $collection_dt );
}

sub _check_within_bulky_cancel_window {
    my ( undef, $now_dt, $collection_dt ) = @_;

    # 23:55 day before collection
    my $cutoff_dt = $collection_dt->clone->subtract( minutes => 5 );
    return $now_dt < $cutoff_dt;
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
    my $results = $bartec->call_api($self->{c}, 'peterborough', 'bin_services_for_address:' . $uprn, @calls);

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
        $schedules{$name}->{Feature}->{Status}->{Name} eq 'IN SERVICE'
        && $schedules{$name}->{Feature}->{FeatureType}->{ID} != 6815;
    } @$jobs;
    return \@jobs;
}

sub _waste_report_allowed {
    my ($self, $dt) = @_;

    # missed bin reports are allowed if we're within 1.5 working days of the last collection day
    # e.g.:
    #  A bin not collected on Tuesday can be rung through up to noon Thursday
    #  A bin not collected on Thursday can be rung through up to noon Monday

    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());
    $dt = $wd->add_days($dt, 1);
    $dt->set( hour => 12, minute => 0, second => 0 );
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
        cracked => "Cracked bin\n\nPlease remove cracked bin.",
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
    if ($category_verbose =~ /cracked/) {
        my $address = $c->stash->{property}->{address};
        $data->{title} = "Request new $bin";
        $data->{detail} = "Quantity: 1\n\n$address";
        $data->{detail} .= "\n\nReason: Cracked bin\n\nPlease remove cracked bin.";
    } else {
        $data->{title} = $category =~ /Lid|Wheels/ ? "Damaged $bin bin" :
                         $category =~ /Not returned/ ? "Bin not returned" : $bin;
        $data->{detail} = "$category_verbose\n\n" . $c->stash->{property}->{address};
    }

    if ( $data->{extra_detail} ) {
        $data->{detail} .= "\n\nExtra detail: " . $data->{extra_detail};
    }
}

sub waste_munge_problem_form_fields {
    my ($self, $field_list) = @_;

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
        419 => {
            container => 6533,
            container_name => "Black bin",
            label => "The bin is cracked",
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
        420 => {
            container => 6534,
            container_name => "Green bin",
            label => "The bin is cracked",
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
            label => "The bin wasn’t returned to the collection point",
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
        disabled => $open_requests->{497},
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

sub available_permissions {
    my $self = shift;

    my $perms = $self->next::method();

    my $features = $self->feature('waste_features') || {};
    if ( $features->{admin_config_enabled} ) {
        $perms->{Waste}->{wasteworks_config} = "Can edit WasteWorks configuration";
    }

    return $perms;
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

sub bulky_nice_cancellation_cutoff_date {
    my ( $self, $collection_date ) = @_;
    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T' );
    my $dt
        = $parser->parse_datetime($collection_date)->truncate( to => 'day' );
    $dt->subtract( minutes => 5 );
    return $dt->strftime('%H:%M on %d %B %Y');
}

sub bulky_nice_item_list {
    my ($self, $report) = @_;

    my @fields = grep { $_->{name} =~ /ITEM_/ } @{$report->get_extra_fields};
    return [ map { $_->{value} || () } @fields ];
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

        # XXX Need to check if the subscription has been cancelled and if so,
        # do not send out the email.

        my $date = $report->get_extra_field_value('DATE');
        my $dt = $parser->parse_datetime($date)->truncate( to => 'day' );
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

1;
