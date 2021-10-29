package FixMyStreet::Cobrand::Oxfordshire;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;
use Moo;
with 'FixMyStreet::Roles::Open311Multi';

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;

sub council_area_id { return 2237; }
sub council_area { return 'Oxfordshire'; }
sub council_name { return 'Oxfordshire County Council'; }
sub council_url { return 'oxfordshire'; }
sub is_two_tier { return 1; }

sub report_validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->detail ) > 1700 ) {
        $errors->{detail} = sprintf( _('Reports are limited to %s characters in length. Please shorten your report'), 1700 );
    }

    if ( length( $report->name ) > 50 ) {
        $errors->{name} = sprintf( 'Names are limited to %d characters in length.', 50 );
    }

    if ( length( $report->user->phone ) > 20 ) {
        $errors->{phone} = sprintf( 'Phone numbers are limited to %s characters in length.', 20 );
    }

    if ( length( $report->user->email ) > 50 ) {
        $errors->{username} = sprintf( 'Emails are limited to %s characters in length.', 50 );
    }

    return $errors;
}

sub is_council_with_case_management {
    # XXX Change this to return 1 when OCC FMSfC goes live.
    return FixMyStreet->config('STAGING_SITE');
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter an Oxfordshire postcode, or street name and area';
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Oxfordshire',
        centre => '51.765765,-1.322324',
        span   => '0.709058,0.849434',
        bounds => [ 51.459413, -1.719500, 52.168471, -0.870066 ],
    };
}

# don't send questionnaires to people who used the OCC cobrand to report their problem
sub send_questionnaires { return 0; }

# increase map zoom level so street names are visible
sub default_map_zoom { 5 }

# let staff hide OCC reports
sub users_can_hide { return 1; }

sub lookup_by_ref_regex {
    return qr/^\s*((?:ENQ)?\d+)\s*$/;
}

sub lookup_by_ref {
    my ($self, $ref) = @_;

    if ( $ref =~ /^ENQ/ ) {
        my $len = length($ref);
        my $filter = "%T18:customer_reference,T$len:$ref,%";
        return { 'extra' => { -like => $filter } };
    }

    return 0;
}

sub reports_ordering {
    return 'created-desc';
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' unless $self->owns_problem( $p );
    return 'grey' if $p->is_closed;
    return 'green' if $p->is_fixed;
    return 'yellow' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

sub pin_new_report_colour {
    return 'yellow';
}

sub path_to_pin_icons {
    return '/cobrands/oxfordshire/images/';
}

sub pin_hover_title {
    my ($self, $problem, $title) = @_;
    my $state = FixMyStreet::DB->resultset("State")->display($problem->state, 1);
    return "$state: $title";
}

sub state_groups_inspect {
    [
        [ 'New', [ 'confirmed', 'investigating' ] ],
        [ 'Scheduled', [ 'action scheduled' ] ],
        [ 'Fixed', [ 'fixed - council' ] ],
        [ 'Closed', [ 'not responsible', 'duplicate', 'unable to fix' ] ],
    ]
}

sub updates_disallowed {
    my $self = shift;
    my ($problem) = @_;

    # Not on reports made by the body user
    return 1 if $self->body->comment_user_id && $problem->user_id == $self->body->comment_user_id;

    return $self->next::method(@_);
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
    $params->{extended_description} = 'oxfordshire';
}

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

    if ($contact->email =~ /^Alloy/) {
        return [
            { name => 'report_url',
            value => $h->{url} },
            { name => 'title',
            value => $row->title },
            { name => 'description',
            value => $row->detail },
            { name => 'category',
            value => $row->category },
        ];
    } else { # WDM
        return [
            { name => 'external_id', value => $row->id },
            { name => 'northing', value => $h->{northing} },
            { name => 'easting', value => $h->{easting} },
            $h->{closest_address} ? { name => 'closest_address', value => "$h->{closest_address}" } : (),
        ];
    }
}

sub open311_config_updates {
    my ($self, $params) = @_;
    $params->{use_customer_reference} = 1;
}

sub open311_pre_send {
    my ($self, $row, $open311) = @_;

    $self->{ox_original_detail} = $row->detail;

    if (my $fid = $row->get_extra_field_value('feature_id')) {
        my $text = "Asset Id: $fid\n\n" . $row->detail;
        $row->detail($text);
    }
}

sub open311_post_send {
    my ($self, $row, $h) = @_;

    $row->detail($self->{ox_original_detail});
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    if ($comment->get_extra_metadata('defect_raised')) {
        my $p = $comment->problem;
        my ($e, $n) = $p->local_coords;
        my $usrn = $p->get_extra_field_value('usrn');
        if (!$usrn) {
            my $cfg = {
                url => 'https://tilma.mysociety.org/mapserver/oxfordshire',
                typename => "OCCRoads",
                srsname => 'urn:ogc:def:crs:EPSG::27700',
                accept_feature => sub { 1 },
                filter => "<Filter xmlns:gml=\"http://www.opengis.net/gml\"><DWithin><PropertyName>SHAPE_GEOMETRY</PropertyName><gml:Point><gml:coordinates>$e,$n</gml:coordinates></gml:Point><Distance units='m'>20</Distance></DWithin></Filter>",
            };
            my $features = $self->_fetch_features($cfg);
            my $feature = $self->_nearest_feature($cfg, $e, $n, $features);
            if ($feature) {
                my $props = $feature->{properties};
                $usrn = Utils::trim_text($props->{TYPE1_2_USRN});
            }
        }
        $params->{'attribute[usrn]'} = $usrn;
        $params->{'attribute[raise_defect]'} = 1;
        $params->{'attribute[easting]'} = $e;
        $params->{'attribute[northing]'} = $n;
        my $details = $comment->user->email . ' ';
        if (my $traffic = $p->get_extra_metadata('traffic_information')) {
            $details .= 'TM1 ' if $traffic eq 'Signs and Cones';
            $details .= 'TM2 ' if $traffic eq 'Stop and Go Boards';
        }
        (my $type = $p->get_extra_metadata('defect_item_type')) =~ s/ .*//;
        $details .= $type eq 'Sweep' ? 'S&F' : $type;
        $details .= ' ' . ($p->get_extra_metadata('detailed_information') || '');
        $params->{'attribute[extra_details]'} = $details;

        foreach (qw(defect_item_category defect_item_type defect_item_detail defect_location_description)) {
            $params->{"attribute[$_]"} = $p->get_extra_metadata($_);
        }
    }
}

sub open311_filter_contacts_for_deletion {
    my ($self, $contacts) = @_;

    # Don't delete open311 protected contacts when importing.
    # WDM contacts are managed manually in the admin instead of via
    # open311-populate-service-list, and this flag is used to stop them
    # being deleted when that script runs.
    return $contacts->search({
        extra => { -not_like => '%T15:open311_protect,I1:1%' },
    });
}


sub should_skip_sending_update {
    my ($self, $update ) = @_;

    my $contact = $update->problem->contact;
    return 0 if $contact && $contact->email =~ /^Alloy/; # Can always send these

    # Oxfordshire HIAMS stores the external id of the problem as a customer
    # reference in metadata, it arrives in a fetched update (but give up if it
    # never does, or the update is for an old pre-ref report)
    my $customer_ref = $update->problem->get_extra_metadata('customer_reference');
    my $diff = time() - $update->confirmed->epoch;
    return 1 if !$customer_ref && $diff > 60*60*24;
    return 'WAIT' if !$customer_ref;
    return 0;
}

sub open311_skip_report_fetch {
    my ($self, $problem) = @_;

    # Abuse this hook a little bit to tidy up the report
    $problem->title($problem->category);
    $problem->detail($problem->category);
    $problem->name($self->council_name);

    return 0;
}

sub report_inspect_update_extra {
    my ( $self, $problem ) = @_;

    foreach (qw(defect_item_category defect_item_type defect_item_detail defect_location_description)) {
        my $value = $self->{c}->get_param($_);
        $problem->set_extra_metadata($_ => $value) if $value;
    }
}

sub on_map_default_status { return 'open'; }

sub admin_user_domain { 'oxfordshire.gov.uk' }

sub admin_pages {
    my $self = shift;

    my $user = $self->{c}->user;

    my $pages = $self->next::method();

    if ( $user->has_body_permission_to('defect_type_edit') ) {
        $pages->{defecttypes} = [ ('Defect Types'), 11 ];
        $pages->{defecttype_edit} = [ undef, undef ];
    };

    return $pages;
}

sub user_extra_fields {
    return [ 'initials' ];
}

sub display_days_ago_threshold { 28 }

sub max_detailed_info_length { 164 }

sub defect_type_extra_fields {
    return [
        'activity_code',
        'defect_code',
    ];
};

sub available_permissions {
    my $self = shift;

    my $perms = $self->next::method();
    $perms->{Bodies}->{defect_type_edit} = "Add/edit defect types";

    return $perms;
}

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns( external_ref => 'HIAMS/Exor Ref' );

    $csv->csv_extra_data(sub {
        my $report = shift;
        # Try and get a HIAMS reference first of all
        my $ref = $report->get_extra_metadata('customer_reference');
        unless ($ref) {
            # No HIAMS ref which means it's either an older Exor report
            # or a HIAMS report which hasn't had its reference set yet.
            # We detect the latter case by the id and external_id being the same.
            $ref = $report->external_id if $report->id ne ( $report->external_id || '' );
        }
        return {
            external_ref => ( $ref || '' ),
        };
    });
}

sub defect_wfs_query {
    my ($self, $bbox) = @_;

    my $filter = "
    <ogc:Filter xmlns:ogc=\"http://www.opengis.net/ogc\">
        <ogc:And>
            <ogc:PropertyIsEqualTo matchCase=\"true\">
                <ogc:PropertyName>APPROVAL_STATUS_NAME</ogc:PropertyName>
                <ogc:Literal>With Contractor</ogc:Literal>
            </ogc:PropertyIsEqualTo>
            <ogc:BBOX>
                <ogc:PropertyName>SHAPE_GEOMETRY</ogc:PropertyName>
                <gml:Envelope xmlns:gml=\"http://www.opengis.net/gml\" srsName=\"$bbox->[4]\">
                    <gml:lowerCorner>$bbox->[0] $bbox->[1]</gml:lowerCorner>
                    <gml:upperCorner>$bbox->[2] $bbox->[3]</gml:upperCorner>
                </gml:Envelope>
            </ogc:BBOX>
        </ogc:And>
    </ogc:Filter>";
    $filter =~ s/\n\s+//g;

    my $uri = URI->new("https://tilma.mysociety.org/proxy/occ/nsg/");
    $uri->query_form(
        REQUEST => "GetFeature",
        SERVICE => "WFS",
        SRSNAME => "urn:ogc:def:crs:EPSG::4326",
        TYPENAME => "WFS_DEFECTS_FOR_QUERYING",
        VERSION => "1.1.0",
        filter => $filter,
        propertyName => 'ITEM_CATEGORY_NAME,ITEM_TYPE_NAME,REQUIRED_COMPLETION_DATE,SHAPE_GEOMETRY',
        outputformat => "application/json"
    );

    try {
        my $response = get($uri);
        my $json = JSON->new->utf8->allow_nonref;
        return $json->decode($response);
    } catch {
        # Ignore WFS errors.
        return {};
    };
}

# Get defects from WDM feed and display them on /around page.
sub pins_from_wfs {
    my ($self, $bbox) = @_;

    my $wfs = $self->defect_wfs_query($bbox);

    # Generate a negative fake ID so it doesn't clash with FMS report IDs.
    my $fake_id = -1;
    my @pins = map {
        my $coords = $_->{geometry}->{coordinates};
        my $props = $_->{properties};
        my $category = $props->{ITEM_CATEGORY_NAME};
        my $type = $props->{ITEM_TYPE_NAME};
        my $category_type;
        $category =~ s/\s+$//;
        $type =~ s/\s+$//;
        if ($category eq $type) {
            $category_type = $category;
        } else {
            $category_type = "$category ($type)";
        }
        my $completion_date = DateTime::Format::W3CDTF->parse_datetime($props->{REQUIRED_COMPLETION_DATE})->strftime('%A %e %B %Y');
        my $title = "$category_type\nEstimated completion date: $completion_date";
        {
            id => $fake_id--,
            latitude => @$coords[1],
            longitude => @$coords[0],
            colour => 'defects',
            title => $title,
        };
    } @{ $wfs->{features} };

    return \@pins;
}

sub extra_nearby_pins {
    my ($self, $latitude, $longitude, $dist) = @_;

    my ($easting, $northing) = Utils::convert_latlon_to_en($latitude, $longitude);
    my $bbox = [$easting-$dist, $northing-$dist, $easting+$dist, $northing+$dist, 'EPSG:27700'];

    my $pins = $self->pins_from_wfs($bbox);

    return map {
        [ $_->{latitude}, $_->{longitude}, $_->{colour},
          $_->{id}, $_->{title}, "normal", JSON->false
        ]
    } @$pins;
}

sub extra_around_pins {
    my ($self, $bbox) = @_;

    if (!defined($bbox)) {
        return [];
    }

    my @box = split /,/, $bbox;
    @box = (@box, 'EPSG:4326');

    my $res = $self->pins_from_wfs(\@box);

    return $res;
}

sub extra_reports_pins {
    my $self = shift;

    my $bbox = $self->{c}->get_param('bbox');
    my $zoom = $self->{c}->get_param('zoom');

    if (!$bbox) {
        return [];
    }

    # Only show pins at certain zoom levels
    if (!defined($zoom) || int($zoom) < 15) {
        return [];
    }

    my @box = split /,/, $bbox;
    @box = (@box, 'EPSG:4326');

    return $self->pins_from_wfs(\@box);
}

1;
