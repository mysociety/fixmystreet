package FixMyStreet::Cobrand::HighwaysEngland;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

sub council_name { 'National Highways' }

sub council_url { 'highwaysengland' }

sub site_key { 'highwaysengland' }

sub restriction { { cobrand => shift->moniker } }

sub hide_areas_on_reports { 1 }

sub all_reports_single_body { { name => 'National Highways' } }

sub body {
    my $self = shift;
    my $body = FixMyStreet::DB->resultset('Body')->search({ name => 'National Highways' })->first;
    return $body;
}

# Copying of functions from UKCouncils that are needed here also - factor out to a role of some sort?
sub cut_off_date { '2020-11-09' }
sub problems_restriction { FixMyStreet::Cobrand::UKCouncils::problems_restriction($_[0], $_[1]) }
sub problems_on_map_restriction { $_[0]->problems_restriction($_[1]) }
sub problems_sql_restriction { FixMyStreet::Cobrand::UKCouncils::problems_sql_restriction($_[0], $_[1]) }
sub users_restriction { FixMyStreet::Cobrand::UKCouncils::users_restriction($_[0], $_[1]) }
sub updates_restriction { FixMyStreet::Cobrand::UKCouncils::updates_restriction($_[0], $_[1]) }
sub base_url { FixMyStreet::Cobrand::UKCouncils::base_url($_[0]) }
sub contact_name { FixMyStreet::Cobrand::UKCouncils::contact_name($_[0]) }
sub contact_email { FixMyStreet::Cobrand::UKCouncils::contact_email($_[0]) }

sub munge_problem_list {
    my ($self, $problem) = @_;
    $problem->anonymous(1);
}
sub munge_update_list {
    my ($self, $update) = @_;
    $update->anonymous(1);
}

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
    return undef unless defined $user->from_body;
    return $user->from_body->name eq 'National Highways';
}

sub report_form_extras {
    ( { name => 'where_hear' } )
}

sub enter_postcode_text { 'Enter a location, road name or postcode' }

sub example_places {
    my $self = shift;
    return $self->feature('example_places') || $self->next::method();
}

sub geocode_postcode {
    my ( $self, $s ) = @_;

    if ($s =~ /^\s*[AM]\d+\s*$/i) {
        return {
            error => "Please be more specific about the location of the issue, eg M1, Jct 16 or A5, Towcester"
        };
    }

    return $self->next::method($s);
}

sub lookup_by_ref_regex {
    return qr/^\s*((?:FMS\s*)?\d+)\s*$/i;
}

sub lookup_by_ref {
    my ($self, $ref) = @_;

    if ( $ref =~ s/^\s*FMS\s*//i ) {
        return { 'id' => $ref };
    }

    return 0;
}

sub allow_photo_upload { 0 }

sub allow_anonymous_reports { 'button' }

sub admin_user_domain { ( 'highwaysengland.co.uk', 'nationalhighways.co.uk' ) }

sub abuse_reports_only { 1 }

sub anonymous_account {
    my $self = shift;
    return {
        email => $self->feature('anonymous_account') . '@' . 'highwaysengland.co.uk',
        name => 'Anonymous user',
    };
}

sub updates_disallowed {
    my ($self, $problem) = @_;
    return 1 if $problem->is_fixed || $problem->is_closed;
    return 1 if $problem->get_extra_metadata('closed_updates');
    return 0;
}

# Bypass photo requirement, we have none
sub recent_photos {
    my ( $self, $area, $num, $lat, $lon, $dist ) = @_;
    return $self->problems->recent if $area eq 'front';
    return [];
}

sub area_check {
    my ( $self, $params, $context ) = @_;

    my $areas = $params->{all_areas};
    $areas = {
        map { $_->{id} => $_ }
        # If no country, is prefetched area and can assume is E
        grep { ($_->{country} || 'E') eq 'E' }
        values %$areas
    };
    return $areas if %$areas;

    my $error_msg = 'Sorry, this site only covers England.';
    return ( 0, $error_msg );
}

sub fetch_area_children {
    my $self = shift;

    my $areas = FixMyStreet::MapIt::call('areas', $self->area_types);
    $areas = {
        map { $_->{id} => $_ }
        grep { ($_->{country} || 'E') eq 'E' }
        values %$areas
    };
    return $areas;
}

sub munge_report_new_bodies {
    my ($self, $bodies) = @_;
    # On the cobrand there is only the HE body
    %$bodies = map { $_->id => $_ } grep { $_->name eq 'National Highways' } values %$bodies;
}

# Want to remove the group our categories are all in
sub munge_report_new_contacts {
    my ($self, $contacts) = @_;
    foreach (@$contacts) {
        $_->unset_extra_metadata("group");
    }
}

sub report_new_is_on_he_road {
    my ( $self ) = @_;

    my ($x, $y) = (
        $self->{c}->stash->{longitude},
        $self->{c}->stash->{latitude},
    );

    my $cfg = {
        url => "https://tilma.mysociety.org/mapserver/highways",
        srsname => "urn:ogc:def:crs:EPSG::4326",
        typename => "Highways",
        filter => "<Filter><DWithin><PropertyName>geom</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point><Distance units='m'>15</Distance></DWithin></Filter>",
    };

    my $ukc = FixMyStreet::Cobrand::UKCouncils->new;
    my $features = $ukc->_fetch_features($cfg, $x, $y);
    return scalar @$features ? 1 : 0;
}

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->modify_csv_header( Ward => 'Council' );

    $csv->objects_attrs({
        '+columns' => ['comments.text', 'comments.extra', 'user.name'],
        join => { comments => 'user' },
    });

    $csv->add_csv_columns(
        area_name => 'Area name',
        where_hear => 'How you found us',
    );
    for (my $i=1; $i<=5; $i++) {
        $csv->add_csv_columns(
            "update_text_$i" => "Update $i",
            "update_date_$i" => "Update $i date",
            "update_name_$i" => "Update $i name",
        );
    }

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $fields = {
            area_name => $report->get_extra_field_value('area_name'),
            where_hear => $report->get_extra_metadata('where_hear'),
        };

        my $i = 1;
        for my $update ($report->comments->search(undef, { order_by => ['confirmed', 'id'] })) {
            next unless $update->state eq 'confirmed';
            last if $i > 5;
            $fields->{"update_text_$i"} = $update->text;
            $fields->{"update_date_$i"} = $update->confirmed;
            my $staff = $update->get_extra_metadata('contributed_by') || $update->get_extra_metadata('is_body_user') || $update->get_extra_metadata('is_superuser');
            $fields->{"update_name_$i"} = $staff ? $update->user->name : 'public';
            $i++;
        }

        return $fields;
    });
}

1;
