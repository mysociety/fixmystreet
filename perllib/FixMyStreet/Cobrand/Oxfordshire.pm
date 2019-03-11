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

sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    return 'https://fixmystreet.oxfordshire.gov.uk';
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

sub example_places {
    return ( 'OX20 1SZ', 'Park St, Woodstock' );
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

=head2 problem_response_days

Returns the number of working days that are expected to elapse
between the problem being reported and it being responded to by
the council/body.
If the value 'emergency' is returned, a different template block
is triggered that has custom wording.

=cut

sub problem_response_days {
    my $self = shift;
    my $p = shift;

    return 'emergency' if $p->category eq 'Street lighting';

    # Temporary, see https://github.com/mysociety/fixmystreetforcouncils/issues/291
    return 0;

    return 10 if $p->category eq 'Bridges';
    return 10 if $p->category eq 'Carriageway Defect'; # phone if urgent
    return 10 if $p->category eq 'Debris/Spillage';
    return 10 if $p->category eq 'Drainage';
    return 10 if $p->category eq 'Fences';
    return 10 if $p->category eq 'Flyposting';
    return 10 if $p->category eq 'Footpaths/ Rights of way (usually not tarmac)';
    return 10 if $p->category eq 'Gully and Catchpits';
    return 10 if $p->category eq 'Ice/Snow'; # phone if urgent
    return 10 if $p->category eq 'Manhole';
    return 10 if $p->category eq 'Mud and Debris'; # phone if urgent
    return 10 if $p->category eq 'Oil Spillage';  # phone if urgent
    return 10 if $p->category eq 'Pavements';
    return 10 if $p->category eq 'Pothole'; # phone if urgent
    return 10 if $p->category eq 'Property Damage';
    return 10 if $p->category eq 'Public rights of way';
    return 10 if $p->category eq 'Road Marking';
    return 10 if $p->category eq 'Road traffic signs';
    return 10 if $p->category eq 'Roads/highways';
    return 10 if $p->category eq 'Skips and scaffolding';
    return 10 if $p->category eq 'Traffic lights'; # phone if urgent
    return 10 if $p->category eq 'Traffic';
    return 10 if $p->category eq 'Trees';
    return 10 if $p->category eq 'Utilities';
    return 10 if $p->category eq 'Vegetation';

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

    my $extra = $row->get_extra_fields;
    push @$extra, { name => 'external_id', value => $row->id };
    push @$extra, { name => 'northing', value => $h->{northing} };
    push @$extra, { name => 'easting', value => $h->{easting} };

    if ($h->{closest_address}) {
        push @$extra, { name => 'closest_address', value => "$h->{closest_address}" }
    }
    $row->set_extra_fields( @$extra );

    $params->{extended_description} = 'oxfordshire';
}

sub open311_config_updates {
    my ($self, $params) = @_;
    $params->{use_customer_reference} = 1;
}

sub should_skip_sending_update {
    my ($self, $update ) = @_;

    # Oxfordshire stores the external id of the problem as a customer reference
    # in metadata
    return 1 if !$update->problem->get_extra_metadata('customer_reference');
}

sub on_map_default_status { return 'open'; }

sub contact_email {
    my $self = shift;
    return join( '@', 'highway.enquiries', 'oxfordshire.gov.uk' );
}

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

    # Oxfordshire have a custom admin page for downloading reports in an Exor-
    # friendly format which anyone with report_instruct permission can use.
    if ( $user->has_body_permission_to('report_instruct') ) {
        $pages->{exordefects} = [ ('Download Exor RDI'), 10 ];
    }
    if ( $user->has_body_permission_to('defect_type_edit') ) {
        $pages->{defecttypes} = [ ('Defect Types'), 11 ];
        $pages->{defecttype_edit} = [ undef, undef ];
    };

    return $pages;
}

sub defect_types {
    {
        SFP2 => "SFP2: sweep and fill <1m2",
        POT2 => "POT2",
    };
}

sub exor_rdi_link_id { 1989169 }
sub exor_rdi_link_length { 50 }

sub reputation_increment_states {
    return {
        'action scheduled' => 1,
    };
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

    delete $perms->{Problems}->{report_edit};
    delete $perms->{Problems}->{report_edit_category};
    delete $perms->{Problems}->{report_edit_priority};
    delete $perms->{Problems}->{report_inspect};
    delete $perms->{Problems}->{report_instruct};
    delete $perms->{Problems}->{planned_reports};

    return $perms;
}

1;
