=head1 NAME

FixMyStreet::Cobrand::HighwaysEngland - code specific to the National Highways cobrand

=head1 SYNOPSIS

National Highways, previously Highways England, is the national roads
authority, and responsible for motorways and major roads in England.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::HighwaysEngland;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;
use utf8;
use DateTime;
use JSON::MaybeXS;
use LWP::UserAgent;

sub council_name { 'National Highways' }

sub council_url { 'highwaysengland' }

sub site_key { 'highwaysengland' }

sub restriction { { cobrand => shift->moniker } }

sub hide_areas_on_reports { 1 }

sub send_questionnaires { 0 }

sub suggest_duplicates { 1 }

sub all_reports_single_body { { name => 'National Highways' } }

=over 4

=item * It is not a council, so inherits from UK, not UKCouncils, but a number of functions are shared with what councils do

=cut

sub cut_off_date { '2020-11-09' }
sub problems_restriction { FixMyStreet::Cobrand::UKCouncils::problems_restriction($_[0], $_[1]) }
sub problems_on_map_restriction { $_[0]->problems_restriction($_[1]) }
sub problems_sql_restriction { FixMyStreet::Cobrand::UKCouncils::problems_sql_restriction($_[0], $_[1]) }
sub users_restriction { FixMyStreet::Cobrand::UKCouncils::users_restriction($_[0], $_[1]) }
sub updates_restriction { FixMyStreet::Cobrand::UKCouncils::updates_restriction($_[0], $_[1]) }
sub base_url { FixMyStreet::Cobrand::UKCouncils::base_url($_[0]) }
sub contact_name { FixMyStreet::Cobrand::UKCouncils::contact_name($_[0]) }
sub contact_email { FixMyStreet::Cobrand::UKCouncils::contact_email($_[0]) }

=item * Any report made when the site was only fully anonymous should remain anonymous

=cut

my $non_anon = DateTime->new( year => 2022, month => 10, day => 5 );

sub munge_problem_list {
    my ($self, $problem) = @_;
    if ($problem->created < $non_anon) {
        $problem->anonymous(1);
    }
}
sub munge_update_list {
    my ($self, $update) = @_;
    if ($update->created < $non_anon) {
        $update->anonymous(1);
    }
}

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
    return undef unless defined $user->from_body;
    return $user->from_body->name eq 'National Highways';
}

=item * We reword a few admin permissions to be clearer

=cut

sub available_permissions {
    my $self = shift;
    my $perms = $self->next::method();
    $perms->{Problems}->{default_to_body} = "Default to creating reports/updates as " . $self->council_name;
    $perms->{Problems}->{contribute_as_body} = "Create reports/updates as " . $self->council_name;
    $perms->{Problems}->{view_body_contribute_details} = "See user detail for reports created as " . $self->council_name;
    return $perms;
}

=item * There is an extra question asking where you heard about the site

=cut

sub report_form_extras {
    ( { name => 'where_hear' } )
}

sub enter_postcode_text { 'Enter a location, road name or postcode' }

sub example_places {
    my $self = shift;
    return $self->feature('example_places') || $self->next::method();
}

=item * Provide nicer help if it looks like they're searching for a road name

=cut

sub geocode_postcode {
    my ( $self, $s ) = @_;

    if ($s =~ /^\s*[AM]\d+\s*$/i) {
        return {
            error => "Please be more specific about the location of the issue, eg M1, Jct 16 or A5, Towcester"
        };
    }

    return $self->next::method($s);
}

=item * Allow lookup by FMSid

=cut

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

=item * No photos

=cut

sub allow_photo_upload { 0 }

# Bypass photo requirement, we have none
sub recent_photos {
    my ( $self, $area, $num, $lat, $lon, $dist ) = @_;
    return $self->problems->recent if $area eq 'front';
    return [];
}

=item * Anonymous reporting is allowed

=cut

sub allow_anonymous_reports { 'button' }

=item * Two domains for admin users

=cut

sub admin_user_domain { ( 'highwaysengland.co.uk', 'nationalhighways.co.uk' ) }

=item * No contact form

=cut

sub abuse_reports_only { 1 }

=item * Only works in England

=cut

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

sub new_report_title_field_label {
    "Summarise the problem and location"
}

sub new_report_title_field_hint {
    "eg ‘Obscured road sign by the northbound M1 junction 23 exit’"
}

sub new_report_detail_field_hint {
    "eg ‘This road sign has been obscured for two months and…’"
}

=item * New reports are possibly redacted

=cut

sub report_new_munge_after_insert {
    my ($self, $report) = @_;

    my %new = (
        title => _redact($report->title),
        detail => _redact($report->detail),
    );

    # Data used by report_moderate_audit
    my $c = $self->{c};
    $c->stash->{history} = $report->new_related( moderation_original_data => {
        title => $report->title,
        detail => $report->detail,
        photo => $report->photo,
        anonymous => $report->anonymous,
        longitude => $report->longitude,
        latitude => $report->latitude,
        category => $report->category,
        $report->extra ? (extra => $report->extra) : (),
    });
    $c->stash->{problem} = $report;
    $c->stash->{moderation_reason} = 'Automatic data redaction';
    $c->stash->{moderation_no_email} = 1;

    my @types;
    foreach (qw(title detail)) {
        if ($report->$_ ne $new{$_}) {
            $report->$_($new{$_});
            push @types, $_;
        }
    }

    $c->forward( '/moderate/report_moderate_audit', \@types );
}

sub _redact {
    my $s = shift;

    my $regex = Utils::email_regex;

    $s =~ s/$regex/[email removed]/g;

    $s =~ s/\(?\+?[0-9](?:[\s()-]*[0-9]){9,}/[phone removed]/g;
    return $s;
}

=back

=head1 OIDC single sign on

Noational Highways has a single-sign on option

=over 4

=item * Single sign on is enabled if the configuration is set up

=cut

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

=item * Different single sign-ons send user details differently, user_from_oidc extracts the relevant parts

=cut

sub user_from_oidc {
    my ($self, $payload, $access_token) = @_;

    my $name = $payload->{name} ? $payload->{name} : '';
    my $email = $payload->{email} ? lc($payload->{email}) : '';

    if ($payload->{oid} && $access_token) {
        my $ua = LWP::UserAgent->new;
        my $response = $ua->get(
            'https://graph.microsoft.com/v1.0/users/' . $payload->{oid} . '?$select=displayName,department',
            Authorization => 'Bearer ' . $access_token,
        );
        my $user = decode_json($response->decoded_content);
        $payload->{roles} = [ $user->{department} ] if $user->{department};
    }

    return ($name, $email);
}

=head2 Report categories


There is special handling of NH body/contacts, to handle the fact litter is not
NH responsibility on most, but not all, NH roads; NH categories must end "(NH)"
(this is stripped for display).

=cut

sub munge_report_new_bodies {
    my ($self, $bodies) = @_;
    # On the cobrand there is only the HE body
    %$bodies = map { $_->id => $_ } grep { $_->name eq 'National Highways' } values %$bodies;
}

# Strip all (NH) from end of category names
sub munge_report_new_contacts {
    my ($self, $contacts) = @_;
    foreach my $c (@$contacts) {
        my $clean_name = $c->category_display;
        if ($clean_name =~ s/ \(NH\)//) {
            $c->set_extra_metadata(display_name => $clean_name);
        }
    }
}

sub national_highways_cleaning_groups {
    my ($self, $contacts) = @_;

    my $c = $self->{c};
    my $not_he_litter = $c->stash->{report_new_is_on_he_road_not_litter};
    if (!defined $not_he_litter) {
        # We delayed working it out because every /around page calls
        # report_new_is_on_he_road but do it now we need to know
        my ($x, $y) = ($c->stash->{longitude}, $c->stash->{latitude});
        $not_he_litter = $self->_report_new_is_on_he_road_not_litter($x, $y);
    }

    $self->munge_report_new_contacts($contacts);

    # Don't change anything else unless we're on a HE non-litter road
    return unless $not_he_litter;

    # If we've come from flytipping/litter on NH site, we only want to show
    # council street cleaning categories; otherwise we want to show those
    # plus non-street cleaning NH categories
    my %cleaning_cats = map { $_ => 1 } @{ $self->_cleaning_categories };
    if (defined $c->stash->{he_referral}) {
        @$contacts = grep {
            my @groups = @{$_->groups};
            $_->body->name ne 'National Highways'
            && ( $cleaning_cats{$_->category_display} || grep { $cleaning_cats{$_} } @groups )
        } @$contacts;
    } else {
        @$contacts = grep {
            # Mark any council street cleaning categories we can find,
            # so they'll still appear if "on the NH road" is picked
            my @groups = @{$_->groups};
            if ( $cleaning_cats{$_->category_display} || grep { $cleaning_cats{$_} } @groups ) {
                $_->set_extra_metadata(nh_council_cleaning => 1);
            }
            $_->body->name ne 'National Highways'
            || ( $_->category_display !~ /Flytipping/ && $_->groups->[0] ne 'Litter' )
        } @$contacts;
    }
}

sub report_new_is_on_he_road {
    my ( $self ) = @_;

    return if FixMyStreet->test_mode eq 'cypress';

    my ($x, $y) = (
        $self->{c}->stash->{longitude},
        $self->{c}->stash->{latitude},
    );

    my $cfg = {
        url => "https://tilma.mysociety.org/mapserver/highways",
        srsname => "urn:ogc:def:crs:EPSG::4326",
        typename => "Highways",
        filter => "<Filter><DWithin><PropertyName>geom</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point><Distance units='m'>15</Distance></DWithin></Filter>",
        accept_feature => sub { 1 },
    };

    my $ukc = FixMyStreet::Cobrand::UKCouncils->new;
    my $features = $ukc->_fetch_features($cfg, $x, $y);
    my $nearest = $ukc->_nearest_feature($cfg, $x, $y, $features);
    # National Highways responsible for litter on Motorways and AM roads
    # And doesn't matter if we are not on a NH road
    if ($nearest && $nearest->{properties}->{'ROA_NUMBER'} =~ /^(M|A\d+M)/) {
        $self->{c}->stash->{report_new_is_on_he_road_not_litter} = 0;
    } elsif (!scalar @$features) {
        $self->{c}->stash->{report_new_is_on_he_road_not_litter} = 0;
    }
    return scalar @$features ? 1 : 0;
}

sub _report_new_is_on_he_road_not_litter {
    my ( $self, $x, $y ) = @_;

    my $cfg = {
        url => "https://tilma.mysociety.org/mapserver/highways",
        srsname => "urn:ogc:def:crs:EPSG::4326",
        typename => "highways_litter_pick",
        filter => "<Filter><DWithin><PropertyName>geom</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point><Distance units='m'>15</Distance></DWithin></Filter>",
    };
    my $ukc = FixMyStreet::Cobrand::UKCouncils->new;
    my $features = $ukc->_fetch_features($cfg, $x, $y);
    # If we've matched then litter is their responsibility, so return reverse of that
    return scalar @$features ? 0 : 1;
}

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->modify_csv_header( Ward => 'Council' );

    $csv->objects_attrs({
        '+columns' => [
            'comments.text', 'comments.extra',
            {'comments.user.name' => 'user.name'},
            {'user.email' => 'user_2.email'},
            {'user.phone' => 'user_2.phone'},
        ],
        join => ['user', { comments => 'user' }],
    });

    $csv->add_csv_columns(
        user_email => 'User Email',
        user_phone => 'User Phone',
        area_name => 'Area name',
        road_name => 'Road name',
        sect_label => 'Section label',
        where_hear => 'How you found us',
    );
    for (my $i=1; $i<=5; $i++) {
        $csv->add_csv_columns(
            "update_text_$i" => "Update $i",
            "update_date_$i" => "Update $i date",
            "update_name_$i" => "Update $i name",
        );
    }

   my $initial_extra_data = sub {
        my $report = shift;
        my $fields = {
            road_name => $csv->_extra_field($report, 'road_name'),
            area_name => $csv->_extra_field($report, 'area_name'),
            sect_label => $csv->_extra_field($report, 'sect_label'),
            where_hear => $csv->_extra_metadata($report, 'where_hear'),
        };
        return $fields;
    };

    if ($csv->dbi) {
        my $JSON = JSON::MaybeXS->new->allow_nonref;
        $csv->csv_extra_data(sub {
            my $report = shift;

            my $fields = $initial_extra_data->($report);
            $fields->{user_name_display} = $report->{name};

            my $i = $report->{comment_rn};
            if ($report->{comment_id} && $i <= 5) {
                $fields->{"update_text_$i"} = $report->{comment_text};
                $fields->{"update_date_$i"} = $report->{comment_confirmed};
                my $extra = $JSON->decode($report->{comment_extra} || '{}');
                my $staff = $extra->{contributed_by} || $extra->{is_body_user} || $extra->{is_superuser};
                $fields->{"update_name_$i"} = $staff ? $report->{comment_name} : 'public';
            }

            return $fields;
        });
        return;
    }

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $fields = $initial_extra_data->($report);
        $fields->{user_name_display} = $report->name;
        $fields->{user_email} = $report->user ? $report->user->email : '';
        $fields->{user_phone} = $report->user ? $report->user->phone : '';

        my $i = 1;
        my @updates = $report->comments->all;
        @updates = sort { $a->confirmed <=> $b->confirmed || $a->id <=> $b->id } @updates;
        for my $update (@updates) {
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
sub _cleaning_categories {
    my @litter_rs = FixMyStreet::DB->resultset('Contact')->not_deleted->search( { extra => { '@>' => '{"litter_category_for_he":1}' } } )->all;
    my @checked_litter_categories = map { $_->category } @litter_rs;
    my @default_litter_categories = (
        'Accumulated Litter',
        'Cleanliness Issue',
        'Cleanliness Sub Standard',
        'Cleansing',
        'Excessive or dangerous littering',
        'Fly Tipping on a road, footway, verge or open space',
        'Fly Tipping',
        'Fly tipping',
        'Fly-Tipping',
        'Fly-tipping',
        'Flytipping and dumped rubbish',
        'Flytipping',
        'Flytipping/flyposting',
        'General (Cleanliness)',
        'General Litter / Rubbish Collection',
        'General fly tipping',
        'Hazardous fly tipping',
        'Litter On Road/Street Cleaning',
        'Litter and Bins',
        'Litter in Parks & Open spaces',
        'Litter in the street',
        'Litter removal',
        'Litter',
        'Littering',
        'Littering and cleanliness',
        'Rubbish or fly tipping on the roads',
        'Street Cleaning',
        'Street Cleansing',
        'Street cleaning and litter',
        'Street cleaning',
        'Street cleansing',
        'Sweeping & Cleansing Hazard',

        # Northumberland's litter categories
        'Damaged Litter Bin (Litter)',
        'Full Litter Bin (Litter)',
        'Littering (Litter)',
        'Other (Litter)',
    );
    push(@default_litter_categories, @checked_litter_categories);
    return \@default_litter_categories;
 }

sub admin_contact_validate_category {
    my ( $self, $category ) = @_;
    return "(NH)" eq substr($category, -4) ? "" : "Category must end with (NH).";
}

1;
