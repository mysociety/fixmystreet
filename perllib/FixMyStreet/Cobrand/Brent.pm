=head1 NAME

FixMyStreet::Cobrand::Brent - code specific to the Brent cobrand

=head1 SYNOPSIS

Brent is a London borough using FMS and WasteWorks

=cut

package FixMyStreet::Cobrand::Brent;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use Moo;

# We use the functionality of bulky waste, though it's called small items
with 'FixMyStreet::Roles::CobrandBulkyWaste';

use strict;
use warnings;
use Moo;
use DateTime;
use DateTime::Format::Strptime;
use Try::Tiny;
use LWP::Simple;
use URI;
use JSON::MaybeXS;

=head1 INTEGRATIONS

Integrates with Echo and Symology for FixMyStreet

Integrates with Echo for WasteWorks.

Uses SCP for accepting payments.

Uses OpenUSRN for locating nearest addresses on the Highway

=cut

use FixMyStreet::App::Form::Waste::Request::Brent;
use FixMyStreet::App::Form::Waste::Garden::Sacks;
use FixMyStreet::App::Form::Waste::Garden::Sacks::Renew;
with 'FixMyStreet::Roles::Open311Multi';
with 'FixMyStreet::Roles::CobrandOpenUSRN';
with 'FixMyStreet::Roles::CobrandEcho';
with 'FixMyStreet::Roles::SCP';

# Brent covers some of the areas around it so that it can handle near-boundary reports
sub council_area_id { return [2488, 2505, 2489, 2487]; } # 2505 Camden, 2489 Barnet, 2487 Harrow
sub council_area { return 'Brent'; }
sub council_name { return 'Brent Council'; }
sub council_url { return 'brent'; }

=head1 DESCRIPTION

=cut

=head2 FMS Defaults

=over 4

=cut

=item * Use their own brand colours for pins

=cut

sub path_to_pin_icons {
    return '/cobrands/oxfordshire/images/';
}

=item * Users with a brent.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'brent.gov.uk' }

=item * Allows anonymous reporting

=cut

sub allow_anonymous_reports { 'button' }

=item * Has a default map zoom of 5

=cut

sub default_map_zoom { 5 }

=item * Doesn't show reports before go live date 2023-03-06

=cut

sub cut_off_date { '2023-03-06'}

=item * Uses their own privacy policy

=cut

sub privacy_policy_url {
    'https://www.brent.gov.uk/the-council-and-democracy/access-to-information/data-protection-and-privacy/brent-privacy-policy'
}

=item * Uses the OSM geocoder

=cut

sub get_geocoder { 'OSM' }

=item * Doesn't allow the reopening of reports

=cut

sub reopening_disallowed { 1 }

=item * Uses slightly different text on the geocode form.

=cut

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a ' . $self->council_area . ' postcode, or street name';
}

=item * Only returns search results from Brent

=cut

sub disambiguate_location { {
    centre => '51.5585509362304,-0.26781886445231',
    span   => '0.0727325098393763,0.144085171830317',
    bounds => [ 51.52763684136, -0.335577710963202, 51.6003693511994, -0.191492539132886 ],
    town => 'Brent',
} }

=item * Filters down search results to be the street name and the postcode only

=back

=cut

sub geocoder_munge_results {
    my ($self, $result) = @_;

    $result->{display_name} =~ s/, London Borough of Brent, London, Greater London, England//;
}

=head2 check_report_is_on_cobrand_asset

If the location is covered by an area of differing responsibility (e.g. Brent
in Camden, or Camden in Brent), return true (either 1 if an area name is
provided, or the name of the area if not).

=cut

sub check_report_is_on_cobrand_asset {
    my ($self, $council_area) = shift @_;

    my $lat = $self->{c}->stash->{latitude};
    my $lon = $self->{c}->stash->{longitude};
    my ($x, $y) = Utils::convert_latlon_to_en($lat, $lon, 'G');
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";

    my $cfg = {
        url => "https://$host/mapserver/brent",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "BrentDiffs",
        filter => "<Filter><Contains><PropertyName>Geometry</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point></Contains></Filter>",
        outputformat => 'GML3',
    };

    my $features = $self->_fetch_features($cfg, $x, $y, 1);

    if ($$features[0]) {
        if ($council_area) {
            if ($$features[0]->{'ms:BrentDiffs'}->{'ms:name'} eq $council_area) {
                return 1;
            }
        } else {
            return $$features[0]->{'ms:BrentDiffs'}->{'ms:name'};
        }
    }
}

=head2 munge_overlapping_asset_bodies

Alters the list of available bodies for the location,
depending on calculated responsibility. After this function,
the bodies list will be the relevant bodies for the point,
though categories may need to be altered later on.

=cut

sub munge_overlapping_asset_bodies {
    my ($self, $bodies) = @_;

    # in_area will be true if the point is within the administrative area of Brent
    my $in_area = grep ($self->council_area_id->[0] == $_, keys %{$self->{c}->stash->{all_areas}});
    # cobrand will be true if the point is within an area of different responsibility from the norm
    my $cobrand = $self->check_report_is_on_cobrand_asset;

    if ($in_area) {
        # In the area of Brent...
        if (!$cobrand || $cobrand eq 'Brent') {
            # ...Brent's responsibility - remove the other bodies covering the Brent area
            %$bodies = map { $_->id => $_ } grep {
                $_->name ne 'Camden Borough Council' &&
                $_->name ne 'Barnet Borough Council' &&
                $_->name ne 'Harrow Borough Council'
                } values %$bodies;
        } else {
            # ...someone else's responsibility, take out the ones definitely not responsible
            my %cobrands = (Harrow => 'Harrow Borough Council', Camden => 'Camden Borough Council', Barnet => 'Barnet Borough Council');
            my $selected = $cobrands{$cobrand};
            %$bodies = map { $_->id => $_ } grep {
                $_->name eq $selected || $_->name eq 'Brent Council' || $_->name eq 'TfL' || $_->name eq 'National Highways'
            } values %$bodies;
        }
    } else {
        # Not in the area of Brent...
        if (!$cobrand || $cobrand ne 'Brent') {
            # ...not Brent's responsibility - remove Brent
            %$bodies = map { $_->id => $_ } grep {
                $_->name ne 'Brent Council'
                } values %$bodies;
        } else {
            # ...Brent's responsibility - leave (both) bodies alone
        }
    }
}

=head2 munge_cobrand_asset_categories

If we're in an overlapping area, we want to take the street categories
of one body, and the non-street categories of the other.

=cut

sub munge_cobrand_asset_categories {
    my ($self, $contacts) = @_;

    my %bodies = map { $_->body->name => $_->body } @$contacts;
    my %non_street = (
        'Barnet' => { map { $_ => 1 } @{ $self->_barnet_non_street } },
        'Camden' => { map { $_ => 1 } @{ $self->_camden_non_street } },
        'Harrow' => { map { $_ => 1 } @{ $self->_harrow_non_street } },
    );

    # in_area will be true if the point is within the administrative area of Brent
    my $in_area = $self->{c}->stash->{all_areas} && scalar(%{$self->{c}->stash->{all_areas}}) == 1 && (values %{$self->{c}->stash->{all_areas}})[0]->{id} eq $self->council_area_id->[0];
    # cobrand will be true if the point is within an area of different responsibility from the norm
    my $cobrand = $self->check_report_is_on_cobrand_asset || '';
    return unless $cobrand;

    my $brent_body = $self->body->id;
    if (!$in_area && $cobrand eq 'Brent') {
        # Outside the area of Brent, but Brent's responsibility
        my $area;
        if (grep {$_->{name} eq 'Camden Borough Council'} values %{$self->{c}->stash->{all_areas}}){
            $area = 'Camden';
        } elsif (grep {$_->{name} eq 'Harrow Borough Council'} values %{$self->{c}->stash->{all_areas}}) {
            $area = 'Harrow';
        }  elsif (grep {$_->{name} eq 'Barnet Borough Council'} values %{$self->{c}->stash->{all_areas}}) {
            $area = 'Barnet';
        };
        my $other_body = $bodies{$area . " Borough Council"};

        # Remove the non-street contacts of Brent
        @$contacts = grep { !($_->email !~ /^Symology/ && $_->body_id == $brent_body) } @$contacts;
        # Remove the street contacts of the other
        @$contacts = grep { !(!$non_street{$area}{$_->category} && $_->body_id == $other_body->id) } @$contacts
            if $other_body;
    } elsif ($in_area && $cobrand ne 'Brent') {
        # Inside the area of Brent, but not Brent's responsibility
        my $other_body = $bodies{$cobrand . " Borough Council"};
        # Remove the street contacts of Brent
        @$contacts = grep { !($_->email =~ /^Symology/ && $_->body_id == $brent_body) } @$contacts;
        # Remove the non-street contacts of the other
        @$contacts = grep { !($non_street{$cobrand}{$_->category} && $_->body_id == $other_body->id) } @$contacts
            if $other_body;
    }
}

=head2 pin_colour

=over 4

=item * grey: closed

=item * green: fixed

=item * yellow: confirmed

=item * orange: all other open states, like "in progress"

=back

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->is_closed;
    return 'green' if $p->is_fixed;
    return 'yellow' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

=head2 categories_restriction

Doesn't show TfL's River Piers category as no piers in Brent

=cut

sub categories_restriction {
    my ($self, $rs) = @_;

    return $rs->search( { 'me.category' => { '-not_like' => 'River Piers%' } } );
}

=head2 social_auth_enabled and user_from_oidc

=over 4

=cut

=item * Single sign on is enabled from the cobrand feature 'oidc_login'

=cut

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

=item * Checks Brent specific fields for the single sign on name and email

=cut

sub user_from_oidc {
    my ($self, $payload) = @_;

    my $name = join(" ", $payload->{givenName}, $payload->{surname});
    my $email = $payload->{email};

    return ($name, $email);
}

=back

=cut

=head2 dashboard_export_problems_add_columns

Brent have various additional columns for extra report data.

=cut

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        street_name => 'Street Name',
        location_name => 'Location Name',
        created_by => 'Created By',
        email => 'Email',
        usrn => 'USRN',
        uprn => 'UPRN',
        external_id => 'External ID',
        image_included => 'Does the report have an image?',

        flytipping_did_you_see => 'Did you see the fly-tipping take place',
        flytipping_statement => "If 'Yes', are you willing to provide a statement?",
        flytipping_quantity => 'How much waste is there',
        flytipping_type => 'Type of waste',

        container_req_action => 'Container Request Action',
        container_req_type => 'Container Request Container Type',
        container_req_reason => 'Container Request Reason',

        missed_collection_id => 'Service ID',
    );

    my $values;
    if (my $flytipping = $self->body->contacts->search({ category => 'Fly-tipping' })->first) {
        foreach my $field (@{$flytipping->get_extra_fields}) {
            next unless @{$field->{values} || []};
            foreach (@{$field->{values}}) {
                $values->{$field->{code}}{$_->{key}} = $_->{name};
            }
        }
    }

    my $flytipping_lookup = sub {
        my ($report, $field) = @_;

        my $v = $report->get_extra_field_value($field) // return '';
        return $values->{$field}{$v} || '';
    };

    $csv->csv_extra_data(sub {
        my $report = shift;

        return {
            street_name => $report->nearest_address_parts->{street},
            location_name => $report->get_extra_field_value('location_name') || '',
            created_by => $report->name || '',
            email => $report->user->email || '',
            usrn => $report->get_extra_field_value('usrn') || '',
            uprn => $report->get_extra_field_value('uprn') || '',
            external_id => $report->external_id || '',
            image_included => $report->photo ? 'Y' : 'N',
            flytipping_did_you_see => $flytipping_lookup->($report, 'Did_you_see_the_Flytip_take_place?_'),
            flytipping_statement => $flytipping_lookup->($report, 'Are_you_willing_to_be_a_WItness?_'),
            flytipping_quantity => $flytipping_lookup->($report, 'Flytip_Size'),
            flytipping_type => $flytipping_lookup->($report, 'Flytip_Type'),
            container_req_action => $report->get_extra_field_value('Container_Request_Action') || '',
            container_req_type => $report->get_extra_field_value('Container_Request_Container_Type') || '',
            container_req_reason => $report->get_extra_field_value('Container_Request_Reason') || '',
            missed_collection_id => $report->get_extra_field_value('service_id') || '',
        }
    });
}

=head2 open311_config

Sends all photo urls in the Open311 data

=cut

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;
    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

=head2 open311_munge_update_params

Updates which are sent over Open311 have 'service_request_id_ext' set
to the id of the update's report

=cut

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;
    $params->{service_request_id_ext} = $comment->problem->id;
}

=head2 should_skip_sending_update

Do not try and send updates to the ATAK backend.

=cut

sub should_skip_sending_update {
    my ($self, $update) = @_;

    my $code = $update->problem->contact->email;
    return 1 if $code =~ /^ATAK/;
    return 0;
}


=head2 open311_extra_data_include

=over 4

=cut

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

=item * Adds NSGRef from WFS service as app doesn't include road layer for Symology

Reports made via the app probably won't have a NSGRef because we don't
display the road layer. Instead we'll look up the closest asset from the
WFS service at the point we're sending the report over Open311.

=cut

    my $open311_only;
    if ($contact->email =~ /^Symology/) {

        if (!$row->get_extra_field_value('NSGRef')) {
            if (my $ref = $self->lookup_site_code($row, 'usrn')) {
                $row->update_extra_field({ name => 'NSGRef', description => 'NSG Ref', value => $ref });
            }
        }

=item * Copies UnitID into the details field for the Drains and gullies category

=cut

        if ($contact->groups->[0] eq 'Drains and gullies') {
            if (my $id = $row->get_extra_field_value('UnitID')) {
                $self->{brent_original_detail} = $row->detail;
                my $detail = $row->detail . "\n\nukey: $id";
                $row->detail($detail);
            }
        }

=item * Adds NSGRef from WFS service as app doesn't include road layer for Echo

Same as Symology above, but different attribute name.

=cut

    } elsif ($contact->email =~ /^Echo/) {
        my $type = $contact->get_extra_metadata('type') || '';
        if ($type ne 'waste' && !$row->get_extra_field_value('usrn')) {
            if (my $ref = $self->lookup_site_code($row, 'usrn')) {
                $row->update_extra_field({ name => 'usrn', description => 'USRN', value => $ref });
            }
        }

=item * Adds information for constructing the description on the open311 side.

=cut

    } elsif ($contact->email =~ /^ATAK/) {

        push @$open311_only, { name => 'title', value => $row->title };
        push @$open311_only, { name => 'report_url', value => $h->{url} };
        push @$open311_only, { name => 'detail', value => $row->detail };
        push @$open311_only, { name => 'group', value => $row->get_extra_metadata('group') || '' };


    }

=item * Adds location name from WFS service for reports in ATAK groups, if missing.

=cut

    my @atak_groups = keys %{$self->group_to_layer};
    my $group = $row->get_extra_metadata('group');
    my $group_is_atak = $group && grep { $_ eq $group } @atak_groups;
    my $contact_location_name_field = $contact->get_extra_field(code => 'location_name');
    my $row_location_name = $row->get_extra_field_value('location_name');

    if ($group_is_atak && $contact_location_name_field && !$row_location_name) {
        if (my $name = $self->lookup_location_name($row)) {
            $row->update_extra_field({ name => 'location_name', description => 'Location name', value => $name });
        }
    }

=item * The title field gets pushed to location fields in Echo/Symology, so include closest address

We use {closest_address}->summary as this is geocoder-agnostic.

=cut

    if ($contact->email =~ /^Echo/ || $contact->email =~ /^Symology/) {
        my $title = $row->title;
        if ( $h->{closest_address} ) {
            my $addr = $h->{closest_address}->summary;

            $addr =~ s/, England//;
            $addr =~ s/, United Kingdom$//;

            $title .= '; Nearest calculated address = ' . $addr;
        }

        push @$open311_only, { name => 'title', value => $title };
        push @$open311_only, { name => 'description', value => $row->detail };
    }

    return $open311_only;
}

=back

=cut

=head2 open311_extra_data_exclude

Doesn't send UnitID for Drains and gullies category as an extra
field in open311 data. It has been transferred to the details
field by open311_extra_data_include

=cut

sub open311_extra_data_exclude {
    my ($self, $row, $h, $contact) = @_;

    return ['UnitID'] if $contact->groups->[0] eq 'Drains and gullies';
    return [];
}

=head2 open311_post_send

Restore the original detail field if it was changed by open311_extra_data_include
to put the UnitID in the detail field for sending

=cut

sub open311_post_send {
    my ($self, $row) = @_;
    if ($row->contact->email =~ /ATAK/ && $row->external_id) {
        $row->state('investigating');
    }

    $row->detail($self->{brent_original_detail}) if $self->{brent_original_detail};
}

=head2 lookup_location_name

Looks up the location name from the WFS service

=cut

sub lookup_location_name {
    my ($self, $report) = @_;

    my $locations = $self->_atak_wfs_query($report);

    # Match the first element like <ms:site_name>King Edward VII Park, Wembley</ms:site_name> and return the value
    if ($locations && $locations =~ /<ms:site_name>(.+?)<\/ms:site_name>/) {
        return $1;
    }
}

=head2 report_validation

Ensure ATAK reports are in ATAK-owned areas

=cut

sub report_validation {
    my ($self, $report, $errors) = @_;

    my $contact = FixMyStreet::DB->resultset('Contact')->find({
        body_id => $self->body->id,
        category => $report->category,
    });

    if ($contact && $contact->email =~ /^ATAK/) {
        my $locations = $self->_atak_wfs_query($report);

        if (index($locations, '<gml:featureMember>') == -1) {
            # Location not found
            $errors->{category} = 'Please select a location in a Brent maintained area';
        }
    }

    return $errors;
}

sub _atak_wfs_query {
    my ($self, $report) = @_;

    my $group = $report->get_extra_metadata('group');
    return unless $group;

    my $asset_layer = $self->_group_to_asset_layer($group);
    return unless $asset_layer;

    my $uri = URI->new('https://tilma.mysociety.org/mapserver/brent');
    $uri->query_form(
        REQUEST => "GetFeature",
        SERVICE => "WFS",
        SRSNAME => "urn:ogc:def:crs:EPSG::27700",
        TYPENAME => $asset_layer,
        VERSION => "1.1.0",
        properties => 'site_name',
    );

    try {
        return $self->_get($self->_wfs_uri($report, $uri));
    } catch {
        # Ignore WFS errors.
        return '';
    };
}

has group_to_layer => (
    is => 'ro',
    default => sub {
        return {
            'Parks and open spaces' => 'Parks_and_Open_Spaces',
            'Allotments' => 'Allotments',
            'Council estates grounds maintenance' => 'Housing',
            'Roadside verges and flower beds' => 'Highway_Verges',
        };
    },
);

sub _group_to_asset_layer {
    my ($self, $group) = @_;

    return $self->group_to_layer->{$group};
}

sub _wfs_uri {
    my ($self, $report, $base_uri) = @_;

    # This fn may be called before cobrand has been set in the
    # reporting flow and local_coords needs it to be set
    $report->cobrand('brent') if !$report->cobrand;

    my ($x, $y) = $report->local_coords;
    my $buffer = 50; # metres
    my ($w, $s, $e, $n) = ($x-$buffer, $y-$buffer, $x+$buffer, $y+$buffer);

    my $filter = "
    <ogc:Filter xmlns:ogc=\"http://www.opengis.net/ogc\">
        <ogc:BBOX>
            <ogc:PropertyName>Shape</ogc:PropertyName>
            <gml:Envelope xmlns:gml='http://www.opengis.net/gml' srsName='EPSG:27700'>
                <gml:lowerCorner>$w $s</gml:lowerCorner>
                <gml:upperCorner>$e $n</gml:upperCorner>
            </gml:Envelope>
        </ogc:BBOX>
    </ogc:Filter>";
    $filter =~ s/\n\s+//g;

    $filter = URI::Escape::uri_escape_utf8($filter);

    return "$base_uri&filter=$filter";
}

# Wrapper around LWP::Simple::get to make mocking in tests easier.
sub _get {
    my ($self, $uri) = @_;

    return get($uri);
}

=head2 prevent_questionnaire_updating_status

Doesn't allow questionnaire responses to change the
status of reports

=cut

sub prevent_questionnaire_updating_status { 1 };

=head2 admin_templates_external_status_code_hook

Munges empty fields out of external status code used
for triggering template responses so non-waste
Echo status codes will trigger auto-templates

=cut

sub admin_templates_external_status_code_hook {
    my ($self) = @_;
    my $c = $self->{c};

    my $res_code = $c->get_param('resolution_code') || '';
    my $task_type = $c->get_param('task_type') || '';
    my $task_state = $c->get_param('task_state') || '';

    my $code = "$res_code,$task_type,$task_state";
    $code = '' if $code eq ',,';
    $code =~ s/,,$// if $code;

    return $code;
}

=head2 waste_check_staff_payment_permissions

Staff can make payments via entering a PAYE code.

=cut

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'paye';
}

=head2 waste_event_state_map

State map for Echo states - not actually waste only as Echo
used for FMS integration for Brent

=cut

sub waste_event_state_map {
    return {
        New => { New => 'confirmed' },
        Pending => {
            Unallocated => 'action scheduled',
            Accepted => 'action scheduled',
            'Allocated to Crew' => 'in progress',
            'Allocated to EM' => 'investigating',
            'Replacement Bin Required' => 'action scheduled',
        },
        Closed => {
            Closed => 'fixed - council',
            Completed => 'fixed - council',
            'Not Completed' => 'unable to fix',
            'Partially Completed' => 'closed',
            'No Repair Required' => 'unable to fix',
        },
        Cancelled => {
            Rejected => 'closed',
        },
    };
}

=head2 waste_on_the_day_criteria

If it's before 10pm on the day of collection, treat an Outstanding/Allocated
task as if it's the next collection and in progress, and do not allow missed
collection reporting unless it's already been completed.

=cut

sub waste_on_the_day_criteria {
    my ($self, $completed, $state, $now, $row) = @_;

    return unless $now->hour < 22;
    if ($state eq 'Outstanding' || $state eq 'Allocated') {
        $row->{next} = $row->{last};
        $row->{next}{state} = 'In progress';
        delete $row->{last};
    }
    if (!$completed) {
        $row->{report_allowed} = 0;
    }
}

sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

    $self->{c}->stash->{containers} = {
        1 => 'Blue rubbish sack',
        16 => 'General rubbish bin (grey bin)',
        8 => 'Clear recycling sack',
        6 => 'Recycling bin (blue bin)',
        11 => 'Food waste caddy',
        13 => 'Garden waste (green bin)',
        46 => 'Paper and cardboard blue sack',
    };

    $self->{c}->stash->{container_actions} = $self->waste_container_actions;

    my %service_to_containers = (
        262 => [ 16 ],
        265 => [ 6 ],
        269 => [ 8 ],
        316 => [ 11 ],
        317 => [ 13 ],
        807 => [ 46 ],
    );
    my %request_allowed = map { $_ => 1 } keys %service_to_containers;
    my %quantity_max = (
        262 => 1,
        265 => 1,
        269 => 1,
        316 => 1,
        317 => 5,
        807 => 1,
    );

    $self->{c}->stash->{quantity_max} = \%quantity_max;

    $self->{c}->stash->{garden_subs} = $self->waste_subscription_types;

    my $result = $self->{api_serviceunits};
    return [] unless @$result;

    my $events = $self->_parse_events($self->{api_events});
    $self->{c}->stash->{open_service_requests} = $events->{enquiry};

    # If there is an open Garden subscription (1159) event, assume
    # that means a bin is being delivered and so a pending subscription
    if ($events->{enquiry}{1159}) {
        $self->{c}->stash->{pending_subscription} = { title => 'Garden Subscription - New' };
        $self->{c}->stash->{open_garden_event} = 1;
    }

    # Small items collection event
    if ($self->{c}->stash->{waste_features}->{bulky_missed}) {
        $self->bulky_check_missed_collection($events, {
            # Not Completed
            18491 => {
                all => 'the collection could not be completed',
            },
        });
    }

    my @to_fetch;
    my %schedules;
    my @task_refs;
    my %expired;
    my $calendar_save = {};
    foreach (@$result) {
        my $servicetask = $self->_get_current_service_task($_) or next;
        my $schedules = _parse_schedules($servicetask);
        # Brent has two overlapping schedules for food
        $schedules->{description} =~ s/other\s*// if $_->{ServiceId} == 316 || $_->{ServiceId} == 263;
        $expired{$_->{Id}} = $schedules if $self->waste_sub_overdue( $schedules->{end_date}, weeks => 4 );

        next unless $schedules->{next} or $schedules->{last};
        $schedules{$_->{Id}} = $schedules;
        push @to_fetch, GetEventsForObject => [ ServiceUnit => $_->{Id} ];
        push @task_refs, $schedules->{last}{ref} if $schedules->{last};

        # Check calendar allocation
        if (($_->{ServiceId} == 262 || $_->{ServiceId} == 317 || $_->{ServiceId} == 807) && $schedules->{description} =~ /every other/ && $schedules->{next}{schedule}) {
            my $allocation = $schedules->{next}{schedule}{Allocation};
            my $day = lc $allocation->{RoundName};
            $day =~ s/\s+//g;
            my ($week) = $allocation->{RoundGroupName} =~ /Week (\d+)/;
            my $links;
            if ($_->{ServiceId} == 262 || $_->{ServiceId} == 807) {
                if ($week) {
                    $calendar_save->{number} = $week;
                } elsif (($week) = $allocation->{RoundGroupName} =~ /WK(\w)/) {
                    $calendar_save->{letter} = $week;
                };
                if ($calendar_save->{letter} && $calendar_save->{number}) {
                    my $id = sprintf("%s-%s%s", $day, $calendar_save->{letter}, $calendar_save->{number});
                    $links = $self->{c}->cobrand->feature('waste_calendar_links');
                    $self->{c}->stash->{calendar_link} = $links->{$id};
                }
            } elsif ($_->{ServiceId} == 317) {
                my $id = sprintf("%s-%s", $day, $week);
                my $links = $self->{c}->cobrand->feature('ggw_calendar_links');
                $self->{c}->stash->{ggw_calendar_link} = $links->{$id};
            }
        }

    }
    push @to_fetch, GetTasks => \@task_refs if @task_refs;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $calls = $echo->call_api($self->{c}, 'brent', 'bin_services_for_address:' . $property->{id}, 1, @to_fetch);

    $property->{show_bulky_waste} = $self->bulky_allowed_property($property);

    my @out;
    my %task_ref_to_row;
    foreach (@$result) {
        my $service_id = $_->{ServiceId};
        my $service_name = $self->service_name_override($_);
        next unless $schedules{$_->{Id}} || ( $service_name eq 'Garden waste' && $expired{$_->{Id}} );

        my $schedules = $schedules{$_->{Id}} || $expired{$_->{Id}};
        my $servicetask = $self->_get_current_service_task($_);

        my $containers = $service_to_containers{$service_id};
        my $open_requests = { map { $_ => $events->{request}->{$_} } grep { $events->{request}->{$_} } @$containers };

        my $request_max = $quantity_max{$service_id};

        my $timeband = _timeband_for_schedule($schedules->{next});

        my $garden = 0;
        my $garden_bins;
        my $garden_sacks;
        my $garden_cost = 0;
        my $garden_due;
        my $garden_overdue;
        if ($service_name eq 'Garden waste') {
            $garden = 1;
            $garden_due = $self->waste_sub_due($schedules->{end_date});
            $garden_overdue = $expired{$_->{Id}};
            my $data = Integrations::Echo::force_arrayref($servicetask->{Data}, 'ExtensibleDatum');
            foreach (@$data) {
                if ( $_->{DatatypeName} eq 'BRT - Paid Collection Container Quantity' ) {
                    $garden_bins = $_->{Value};
                    # $_->{Value} is a code for the number of bins and corresponds 1:1 (bin), 2:2 (bins) etc,
                    # until it gets to 9 when it corresponds to sacks
                    if ($garden_bins == '9') {
                        $garden_sacks = 1;
                        $garden_cost = $self->garden_waste_sacks_cost_pa($garden_bins) / 100;
                    } else {
                        $garden_cost = $self->garden_waste_cost_pa($garden_bins) / 100;
                    }
                }
            }
            $request_max = $garden_bins;

            if ($self->{c}->stash->{waste_features}->{garden_disabled}) {
                $garden = 0;
            }
        }

        my $row = {
            id => $_->{Id},
            service_id => $service_id,
            service_name => $service_name,
            garden_waste => $garden,
            garden_bins => $garden_bins,
            garden_sacks => $garden_sacks,
            garden_cost => $garden_cost,
            garden_due => $garden_due,
            garden_overdue => $garden_overdue,
            request_allowed => $request_allowed{$service_id} && $request_max && $schedules->{next},
            requests_open => $open_requests,
            request_containers => $containers,
            request_max => $request_max,
            service_task_id => $servicetask->{Id},
            service_task_name => $servicetask->{TaskTypeName},
            service_task_type_id => $servicetask->{TaskTypeId},
            schedule => $schedules->{description},
            last => $schedules->{last},
            next => $schedules->{next},
            end_date => $schedules->{end_date},
            timeband => $timeband,
        };
        if ($row->{last}) {
            my $ref = join(',', @{$row->{last}{ref}});
            $task_ref_to_row{$ref} = $row;

            $row->{report_allowed} = $self->within_working_days($row->{last}{date}, 2);

            my $events_unit = $self->_parse_events($calls->{"GetEventsForObject ServiceUnit $_->{Id}"});
            my $missed_events = [
                @{$events->{missed}->{$service_id} || []},
                @{$events_unit->{missed}->{$service_id} || []},
            ];
            my $recent_events = $self->_events_since_date($row->{last}{date}, $missed_events);
            $row->{report_open} = $recent_events->{open} || $recent_events->{closed};
        }
        push @out, $row;
    }

    $self->waste_task_resolutions($calls->{GetTasks}, \%task_ref_to_row);

    return \@out;
}

sub _timeband_for_schedule {
    my $schedule = shift;

    return unless $schedule->{schedule};

    my $parser = DateTime::Format::Strptime->new( pattern => '%H:%M:%S.%3N' );
    if (my $timeband = $schedule->{schedule}->{TimeBand}) {
        return {
            start => $parser->parse_datetime($timeband->{Start}),
            end => $parser->parse_datetime($timeband->{End})
        };
    }
}

sub waste_container_actions {
    return {
        deliver => 1,
        remove => 2
    };
}

sub waste_subscription_types {
    return {
        New => 1,
        Renew => 2,
        Amend => 3,
    };
}

sub missed_event_types { {
    2936 => 'request',
    2891 => 'missed',
    2964 => 'bulky',
} }

around bulky_check_missed_collection => sub {
    my ($orig, $self) = (shift, shift);
    $orig->($self, @_);
    if ($self->{c}->stash->{bulky_missed}) {
        $self->{c}->stash->{bulky_missed}{service_name} = 'Small items';
    }
};

sub image_for_unit {
    my ($self, $unit) = @_;
    my $service_id = $unit->{service_id};

    my $base = '/i/waste-containers';
    my $images = {
        262 => "$base/bin-grey",
        265 => "$base/bin-grey-blue-lid-recycling",
        316 => "$base/caddy-green-recycling",
        317 => "$base/bin-green",
        263 => "$base/large-communal-black",
        266 => "$base/large-communal-blue-recycling",
        271 => "$base/bin-brown",
        267 => "$base/sack-black",
        269 => "$base/sack-clear",
        807 => "$base/bag-blue",
    };
    return $images->{$service_id};
}

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        262 => 'Rubbish',
        265 => 'Recycling',
        316 => 'Food waste',
        317 => 'Garden waste',
        263 => 'Communal rubbish',
        266 => 'Communal recycling',
        271 => 'Communal food waste',
        267 => 'Rubbish (black sacks)',
        269 => 'Recycling (clear sacks)',
        807 => 'Paper and cardboard (blue sacks)',
    );

    return $service_name_override{$service->{ServiceId}} || $service->{ServiceName};
}

around look_up_property => sub {
    my ($orig, $self, $id) = @_;
    my $data = $orig->($self, $id);

    my @pending = $self->find_pending_bulky_collections($data->{uprn})->all;
    $self->{c}->stash->{pending_bulky_collections}
        = @pending ? \@pending : undef;

    return $data;
};

sub within_working_days {
    my ($self, $dt, $days, $future) = @_;
    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());
    $dt = $wd->add_days($dt, $days)->ymd;
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->ymd;
    if ( $future ) {
        return $today ge $dt;
    } else {
        return $today le $dt;
    }
}

sub waste_munge_report_data {
    my ($self, $id, $data) = @_;

    my $c = $self->{c};

    my $address = $c->stash->{property}->{address};
    my $service = $c->stash->{services}{$id}{service_name};
    $data->{title} = "Report missed $service";
    $data->{detail} = "$data->{title}\n\n$address";
    $c->set_param('service_id', $id);
}

# Replace the usual checkboxes grouped by service with one radio list
sub waste_munge_request_form_fields {
    my ($self, $field_list) = @_;

    my @radio_options;
    my %seen;
    for (my $i=0; $i<@$field_list; $i+=2) {
        my ($key, $value) = ($field_list->[$i], $field_list->[$i+1]);
        next unless $key =~ /^container-(\d+)/;
        my $id = $1;
        push @radio_options, {
            value => $id,
            label => $self->{c}->stash->{containers}->{$id},
            disabled => $value->{disabled},
        };
        $seen{$id} = 1;
    }

    @$field_list = (
        "container-choice" => {
            type => 'Select',
            widget => 'RadioGroup',
            label => 'Which container do you need?',
            options => \@radio_options,
            required => 1,
        }
    );
}


=head2 alternative_backend_field_names

Some field names to send for integrations are defined by earlier
integrations, so this can be used to fetch the different
field name for what is essentially the same field

=cut

sub alternative_backend_field_names {
    my ($self, $field) = @_;

    my %alternative_name = (
        'Subscription_End_Date' => 'End_Date',
    );

    return $alternative_name{$field};
}

sub waste_munge_request_data {
    my ($self, $id, $data, $form) = @_;

    my $c = $self->{c};

    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $reason = $data->{request_reason} || '';
    my $nice_reason = $c->stash->{label_for_field}->($form, 'request_reason', $reason);

    my ($action_id, $reason_id);
    my $type = $id;
    my $quantity = 1;
    if ($reason eq 'damaged') {
        $action_id = '2::1'; # Collect/Deliver
        $reason_id = '4::4'; # Damaged
        $type = $id . '::' . $id;
        $quantity = '1::1';
    } elsif ($reason eq 'missing') {
        $action_id = 1; # Deliver
        $reason_id = 1; # Missing
    } elsif ($reason eq 'new_build') {
        $action_id = 1; # Deliver
        $reason_id = 6; # New Property
    } elsif ($reason eq 'extra') {
        $action_id = 1; # Deliver
        $reason_id = 9; # Increase capacity
    }

    $c->set_param('Container_Request_Action', $action_id);
    $c->set_param('Container_Request_Reason', $reason_id);
    $c->set_param('Container_Request_Container_Type', $type);
    $c->set_param('Container_Request_Quantity', $quantity);

    $data->{title} = "Request new $container";
    $data->{detail} = "Quantity: 1\n\n$address";
    $data->{detail} .= "\n\nReason: $nice_reason" if $nice_reason;

    my $notes;
    if ($data->{notes_damaged}) {
        $notes = $c->stash->{label_for_field}->($form, 'notes_damaged', $data->{notes_damaged});
        $data->{detail} .= " - $notes";
    }
    if ($data->{details_damaged}) {
        $data->{detail} .= "\n\nDamage reported during collection: " . $data->{details_damaged};
        $notes .= " - " . $data->{details_damaged};
    }
    $c->set_param('Container_Request_Notes', $notes) if $notes;

    # XXX Share somewhere with reverse?
    my %service_id = (
        16 => 262,
        6 => 265,
        8 => 269,
        11 => 316,
        13 => 317,
        46 => 807,
    );
    $c->set_param('service_id', $service_id{$id});
}

sub waste_request_form_first_next {
    my $self = shift;

    $self->{c}->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Request::Brent';
    $self->{c}->stash->{form_title} = 'Which container do you need?';

    return sub {
        my $data = shift;
        my $choice = $data->{"container-choice"};
        return 'request_refuse_call_us' if $choice == 16;
        return 'replacement';
    };
}

# Take the chosen container and munge it into the normal data format
sub waste_munge_request_form_data {
    my ($self, $data) = @_;
    my $container_id = delete $data->{'container-choice'};
    $data->{"container-$container_id"} = 1;
}

=head2 Waste configuration

=over 4

=item * Waste reports do not have email confirmation.

=item * Staff cannot choose the payment method (if there were multiple)

=item * Cheque payments are not an option

=item * Renewals can happen within 28 days

=cut

sub waste_never_confirm_reports { 1 }
sub waste_staff_choose_payment_method { 0 }
sub waste_cheque_payments { 0 }

use constant GARDEN_WASTE_SERVICE_ID => 317;
use constant GARDEN_WASTE_PAID_COLLECTION_BIN => 1;
use constant GARDEN_WASTE_PAID_COLLECTION_SACK => 2;
sub garden_service_name { 'Garden waste collection service' }
sub garden_service_id { GARDEN_WASTE_SERVICE_ID }
sub garden_current_subscription { shift->{c}->stash->{services}{+GARDEN_WASTE_SERVICE_ID} }
sub get_current_garden_bins { shift->garden_current_subscription->{garden_bins} }
sub garden_due_days { 28 }

sub garden_current_service_from_service_units {
    my ($self, $services) = @_;

    my $garden;
    for my $service ( @$services ) {
        if ( $service->{ServiceId} == GARDEN_WASTE_SERVICE_ID ) {
            $garden = $self->_get_current_service_task($service);
            last;
        }
    }

    return $garden;
}

sub bin_payment_types {
    return {
        'csc' => 1,
        'credit_card' => 2,
        'direct_debit' => 3,
        'cheque' => 4,
    };
}

sub waste_cc_payment_line_item_ref {
    my ($self, $p) = @_;
    return "Brent-" . $p->id;
}

sub waste_cc_payment_sale_ref {
    my ($self, $p) = @_;
    return "Brent-" . $p->id;
}

=item * Staff can pick between sacks/bins for garden waste subscription/renewal

=cut

sub waste_garden_subscribe_form_setup {
    my ($self) = @_;
    my $c = $self->{c};
    if ($c->stash->{is_staff}) {
        $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden::Sacks';
    }
}

sub waste_garden_renew_form_setup {
    my ($self) = @_;
    my $c = $self->{c};
    if ($c->stash->{is_staff}) {
        $c->stash->{first_page} = 'sacks_choice';
        $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden::Sacks::Renew';
    }
}

sub waste_munge_enquiry_data {
    my ($self, $data) = @_;

    my $address = $self->{c}->stash->{property}->{address};
    $data->{title} = $data->{category};

    my $detail;
    foreach (sort grep { /^extra_/ } keys %$data) {
        $detail .= "$data->{$_}\n\n";
    }
    $detail .= $address;
    $data->{detail} = $detail;
}

sub waste_cc_payment_admin_fee_line_item_ref {
    my ($self, $p) = @_;
    return "Brent-" . $p->id;
}


sub waste_garden_sub_payment_params {
    my ($self, $data) = @_;
    my $c = $self->{c};

    my $container = $data->{container_choice} || '';
    if ($container eq 'sack') {
        my $bin_count = 1; # $data->{bins_wanted};
        $data->{bin_count} = $bin_count;
        $data->{new_bins} = $bin_count;
        my $cost_pa = $c->cobrand->garden_waste_sacks_cost_pa() * $bin_count;
        ($cost_pa) = $c->cobrand->apply_garden_waste_discount($cost_pa) if $data->{apply_discount};
        $c->set_param('payment', $cost_pa);
    }
}

sub waste_garden_sub_params {
    my ($self, $data, $type) = @_;
    my $c = $self->{c};

    my $container = $data->{container_choice} || '';
    $container = $container eq 'sack' ? GARDEN_WASTE_PAID_COLLECTION_SACK : GARDEN_WASTE_PAID_COLLECTION_BIN;
    $c->set_param('Paid_Collection_Container_Type', $container);
    $c->set_param('Paid_Collection_Container_Quantity', $data->{bin_count});
    $c->set_param('Payment_Value', $data->{cost_pa});
    if ( $data->{new_bins} > 0 && $container != GARDEN_WASTE_PAID_COLLECTION_SACK ) {
        $c->set_param('Container_Type', $container);
        $c->set_param('Container_Quantity', $data->{new_bins});
    }
}

sub waste_garden_mod_params {
    my ($self, $data) = @_;
    my $c = $self->{c};

    $data->{category} = 'Amend Garden Subscription';

    $c->set_param('Additional_Collection_Container_Type', 1);
    $c->set_param('Additional_Collection_Container_Quantity', $data->{new_bins} > 0 ? $data->{new_bins} : '');

    if ($data->{new_bins} > 0) {
        $c->set_param('Container_Type', 1);
        $c->set_param('Container_Quantity', $data->{new_bins});
    }
}

=item * Sacks cost the same as bins

=cut

sub garden_waste_sacks_cost_pa {
    return $_[0]->garden_waste_cost_pa();
}

=item * Garden subscription is half price in October-December.

=cut

sub garden_waste_cost_pa {
    my ($self, $bin_count) = @_;

    $bin_count ||= 1;

    my $cost = $self->feature('payment_gateway')->{ggw_cost} * $bin_count;
    my $now = DateTime->now( time_zone => FixMyStreet->local_time_zone );

    if ($now->month =~ /^(10|11|12)$/ ) {
        $cost = $cost/2;
    }

    return $cost;
}

=item * Uses custom text for the title field for new reports.

=cut

sub new_report_title_field_label {
    "Location of the problem"
}

sub new_report_title_field_hint {
    "Exact location, including any landmarks"
}

=item * Staff can apply a fixed discount to the garden subscription cost via a checkbox.

=back

=cut

sub apply_garden_waste_discount {
    my ($self, @charges ) = @_;

    my $discount = $self->{c}->stash->{waste_features}->{ggw_discount_as_percent};
    my $proportion_to_pay = 1 - $discount / 100;
    my @discounted = map { $_ ? $_ * $proportion_to_pay : $_ } @charges;
    return @discounted;
}

sub garden_waste_new_bin_admin_fee { 0 }

sub waste_get_pro_rata_cost {
    my $self = shift;

    return $self->feature('payment_gateway')->{ggw_cost};
}

sub bulky_collection_time { { hours => 7, minutes => 0 } }
sub bulky_cancellation_cutoff_time { { hours => 23, minutes => 59 } }
sub bulky_cancel_by_update { 1 }
sub bulky_collection_window_days { 28 }
sub bulky_can_refund { 0 }
sub bulky_free_collection_available { 0 }
sub bulky_hide_later_dates { 1 }

sub bulky_allowed_property {
    my ( $self, $property ) = @_;
    return $self->bulky_enabled;
}

sub collection_date {
    my ($self, $p) = @_;
    return $self->_bulky_date_to_dt($p->get_extra_field_value('Collection_Date'));
}

sub _bulky_refund_cutoff_date { }

sub _bulky_date_to_dt {
    my ($self, $date) = @_;
    $date = (split(";", $date))[0];
    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T', time_zone => FixMyStreet->local_time_zone);
    my $dt = $parser->parse_datetime($date);
    return $dt ? $dt->truncate( to => 'day' ) : undef;
}

sub waste_munge_bulky_data {
    my ($self, $data) = @_;

    my $c = $self->{c};
    my ($date, $ref, $expiry) = split(";", $data->{chosen_date});

    my $guid_key = $self->council_url . ":echo:bulky_event_guid:" . $c->stash->{property}->{id};
    $data->{extra_GUID} = $self->{c}->session->{$guid_key};
    $data->{extra_reservation} = $ref;

    $data->{title} = "Small items collection";
    $data->{detail} = "Address: " . $c->stash->{property}->{address};
    $data->{category} = "Small items collection";
    $data->{extra_Collection_Date} = $date;
    $data->{extra_Exact_Location} = $data->{location};

    my (%types);
    my $max = $self->bulky_items_maximum;
    my $other_item = 'Small electricals: Other item under 30x30x30 cm';
    for (1..$max) {
        if (my $item = $data->{"item_$_"}) {
            if ($item eq $other_item) {
                $item .= ' (' . ($data->{"item_notes_$_"} || '') . ')';
            }
            $types{$item}++;
            if ($item eq 'Tied bag of domestic batteries (min 10 - max 100)') {
                $data->{extra_Batteries} = 1;
            } elsif ($item eq 'Podback Bag') {
                $data->{extra_Coffee_Pods} = 1;
            } elsif ($item eq 'Paint, up to 5 litres capacity (1 x 5 litre tin, 5 x 1 litre tins etc.)') {
                $data->{extra_Paint} = 1;
            } elsif ($item eq 'Textiles, up to 60 litres (one black sack / 3 carrier bags)') {
                $data->{extra_Textiles} = 1;
            } else {
                $data->{extra_Small_WEEE} = 1;
            }
        };
    }
    $data->{extra_Notes} = "Collection date: " . $self->bulky_nice_collection_date($date) . "\n";
    $data->{extra_Notes} .= join("\n", map { "$types{$_} x $_" } sort keys %types);
}

sub waste_reconstruct_bulky_data {
    my ($self, $p) = @_;

    my $saved_data = {
        "chosen_date" => $p->get_extra_field_value('Collection_Date'),
        "location" => $p->get_extra_field_value('Exact_Location'),
        "location_photo" => $p->get_extra_metadata("location_photo"),
    };

    my @fields = grep { /^item_\d/ } keys %{$p->get_extra_metadata};
    for my $id (1..@fields) {
        $saved_data->{"item_$id"} = $p->get_extra_metadata("item_$id");
        $saved_data->{"item_notes_$id"} = $p->get_extra_metadata("item_notes_$id");
    }

    $saved_data->{name} = $p->name;
    $saved_data->{email} = $p->user->email;
    $saved_data->{phone} = $p->user->phone;

    return $saved_data;
}

sub _barnet_non_street {
    return [
        'Abandoned vehicles',
        'Graffiti',
        'Dog fouling',
        'Overhanging foliage',
    ]
};

sub _camden_non_street {
    return [
        'Abandoned vehicles',
        'Dead animal',
        'Flyposting',
        'Public toilets',
        'Recycling & rubbish (Missed bin)',
        'Dott e-bike / e-scooter',
        'Human Forest e-bike',
        'Lime e-bike / e-scooter',
        'Tier e-bike / e-scooter',
    ]
}

sub _harrow_non_street {
    return [
        'Abandoned vehicles',
        'Car parking',
        'Graffiti',
    ]
}

1;
