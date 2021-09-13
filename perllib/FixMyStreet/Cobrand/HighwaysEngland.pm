package FixMyStreet::Cobrand::HighwaysEngland;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;
use Data::Dumper;

sub council_name { 'Highways England' }

sub council_url { 'highwaysengland' }

sub site_key { 'highwaysengland' }

sub restriction { { cobrand => shift->moniker } }

sub hide_areas_on_reports { 1 }

sub all_reports_single_body { { name => 'Highways England' } }

sub body {
    my $self = shift;
    my $body = FixMyStreet::DB->resultset('Body')->search({ name => 'Highways England' })->first;
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
    return $user->from_body->name eq 'Highways England';
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

sub admin_user_domain { 'highwaysengland.co.uk' }

sub abuse_reports_only { 1 }

sub anonymous_account {
    my $self = shift;
    return {
        email => $self->feature('anonymous_account') . '@' . $self->admin_user_domain,
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
    my $on_he_road = $self->{c}->stash->{on_he_road} = $self->report_new_is_on_he_road;
    my $on_he_road_for_litter = $self->{c}->stash->{on_he_road_for_litter} = $self->report_new_is_on_he_road_for_litter;
    # On the cobrand there is only the HE body
    if ($self->{c}->stash->{on_he_road_for_litter}) {
        %$bodies = map { $_->id => $_ } grep { $_->name eq 'Highways England' } values %$bodies;
    }
}

# Want to remove the group our categories are all in
sub munge_report_new_contacts {
    my ($self, $contacts) = @_;
    # my $on_he_road = $self->report_new_is_on_he_road;
    # my $on_he_road_for_litter = $self->report_new_is_on_he_road_for_litter;
    # if ($on_he_road && !$on_he_road_for_litter) {
    #     # Change litter to use local council
    #         $self->munge_litter_picking_categories($contacts, 0);
    #     } else {
    #         @$contacts = grep { ( $_->body->name eq 'Highways England') } @$contacts;
    # }
    foreach (@$contacts) {
        $_->unset_extra_metadata("group");
    }
}

sub report_new_is_on_he_road_for_litter {
    my ( $self ) = @_;

    my ($x, $y) = (
        $self->{c}->stash->{longitude},
        $self->{c}->stash->{latitude},
    );

    my $cfg = {
        url => "https://tilma.staging.mysociety.org/mapserver/highways",
        srsname => "urn:ogc:def:crs:EPSG::4326",
        typename => "highways_litter_pick",
        filter => "<Filter><DWithin><PropertyName>geom</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point><Distance units='m'>15</Distance></DWithin></Filter>",
    };
    my $ukc = FixMyStreet::Cobrand::UKCouncils->new;
    my $features = $ukc->_fetch_features($cfg, $x, $y);
    return scalar @$features ? 1 : 0;
}

sub munge_litter_picking_categories {
    my ($self, $contacts, $he_litter_category_bool) = @_;
    my %cleaning_cats = map { $_ => 1 } @{ $self->_cleaning_categories };
    if ($he_litter_category_bool) {
        @$contacts = grep {
            ( $_->body->name ne 'Highways England' && !$cleaning_cats{$_->category} )
            || ($_->body->name eq 'Highways England' && $_->category eq 'Litter')
        } @$contacts;
    } else {
        @$contacts = grep {
            ( $_->body->name ne 'Highways England' && $cleaning_cats{$_->category} )
            || ($_->body->name eq 'Highways England' && $_->category ne 'Litter')
        } @$contacts;
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

# select distinct category from contacts where category ilike '%litter%' or category ilike '%clean%' or category ilike '%fly%tip%';
# search to find categories in all contacts and then manually edited
sub _cleaning_categories { [
    #Bus Station Cleaning - Windows,
    #Car Park Cleansing,
    #Litter Bin overflow,
    'General Litter / Rubbish Collection',
    #Bus Station Cleaning - General,
    'Excessive or dangerous littering',
    #Litter bins,
    'Litter and Bins',
    #Litter Bins,
    'Flytipping',
    'Flytipping/flyposting',
    'Fly Tipping',
    'Street cleaning',
    'Litter removal',
    #Litter or flytipping in a woodland,
    #Litter Bins Full/Damaged/Missing,
    #Damage to litter bin,
    #Damage Public Litter Bin,
    #Flytipping (TfL),
    'Fly-tipping',
    'Litter in Parks & Open spaces',
    #Overflowing Street Litter Bin,
    #Bus Station Cleaning - Toilets,
    'Flytipping and dumped rubbish',
    'Fly tipping',
    'Hazardous fly tipping',
    'Street Cleaning',
    #'Litter bin damaged',
    #'Litter bin full',
    #Bus Station Cleaning - Floor,
    'General fly tipping',
    'Litter in the street',
    #Shelter needs cleaning (not including litter),
    #Litter Bin on a verge or open space,
    'Litter On Road/Street Cleaning',
    #Bench/cycle rack/litter bin/planter,
    'Cleanliness Issue',
    #River Piers - Cleaning,
    #Litter Bin,
    #Planter not Clean and Tidy,
    'General (Cleanliness)',
    'Fly-Tipping',
    #Overflowing Litter Bin / Dog Bin,
    #Litter Bin overflow in Parks & Open spaces,
    #'Litter bin',
    'Fly Tipping on a road, footway, verge or open space',
    #Fly Tipping on a public right of way,
    'Litter',
    #Fly tipping - Enforcement Request,
    'Accumulated Litter',
    'Rubbish or fly tipping on the roads',
    #Shelter needs cleaning (hazardous waste),
    'Sweeping & Cleansing Hazard',
    'Littering',
    #Pavement cleaning,
    #Overflowing litter bin,
    #Street Cleaning Enquiry,
    #Litter Bin Overflowing,
    #Street Cleansing,
    'Street cleaning and litter',
    #Dog and litter bins,
    'Cleanliness Sub Standard',
    'Street cleansing',
    #'Flytipping (off-road)',
] }
1;
