package FixMyStreet::Cobrand::Oxfordshire;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

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
sub default_map_zoom { return 3; }

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

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
    $params->{extended_description} = 'oxfordshire';
}

sub open311_extra_data {
    my ($self, $row, $h, $extra) = @_;

    return [
        { name => 'external_id', value => $row->id },
        { name => 'northing', value => $h->{northing} },
        { name => 'easting', value => $h->{easting} },
        $h->{closest_address} ? { name => 'closest_address', value => "$h->{closest_address}" } : (),
    ];
}

sub open311_config_updates {
    my ($self, $params) = @_;
    $params->{use_customer_reference} = 1;
}

sub open311_pre_send {
    my ($self, $row, $open311) = @_;

    if ($row->get_extra_field_value('feature_id')) {
        my $text = $row->detail;
        $text .= "\n\nAsset Id: " . $row->get_extra_field_value('feature_id') . "\n";
        $row->detail($text);
    }

    if ($row->get_extra_field_value('usrn')) {
        my $text = $row->detail;
        $text .= "\n\nUSRN: " . $row->get_extra_field_value('usrn') . "\n";
        $row->detail($text);
    }
}

sub should_skip_sending_update {
    my ($self, $update ) = @_;

    # Oxfordshire stores the external id of the problem as a customer reference
    # in metadata
    return 1 if !$update->problem->get_extra_metadata('customer_reference');
}

sub on_map_default_status { return 'open'; }

sub admin_user_domain { 'oxfordshire.gov.uk' }

sub traffic_management_options {
    return [
        "Signs and Cones",
        "Stop and Go Boards",
        "High Speed Roads",
    ];
}

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

1;
