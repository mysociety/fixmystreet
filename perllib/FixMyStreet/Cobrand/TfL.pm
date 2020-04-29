package FixMyStreet::Cobrand::TfL;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::BoroughEmails';

use POSIX qw(strcoll);

use FixMyStreet::MapIt;
use mySociety::ArrayUtils;
use Utils;

sub london_boroughs { (
    2511, 2489, 2494, 2488, 2482, 2505, 2512, 2481, 2484, 2495,
    2493, 2508, 2502, 2509, 2487, 2485, 2486, 2483, 2507, 2503,
    2480, 2490, 2492, 2500, 2510, 2497, 2499, 2491, 2498, 2506,
    2496, 2501, 2504,
) }

# Surrounding areas for bus stops which can be outside London
sub surrounding_london { (
    # Clockwise from top left: South Bucks, Three Rivers, Watford, Hertsmere,
    # Welwyn Hatfield, Broxbourne, Epping Forest, Brentwood, Thurrock,
    # Dartford, Sevenoaks, Tandridge, Reigate and Banstead, Epsom and Ewell,
    # Mole Valley, Elmbridge, Spelthorne, Slough
    2256, 2338, 2346, 2339, 2344, 2340, 2311, 2309, 2615,
    2358, 2350, 2448, 2453, 2457, 2454, 2455, 2456, 2606,
) }

sub council_area_id { [ $_[0]->london_boroughs, $_[0]->surrounding_london ] }

sub council_area { return 'TfL'; }
sub council_name { return 'TfL'; }
sub council_url { return 'tfl'; }
sub area_types  { [ 'LBO', 'UTA', 'DIS' ] }
sub is_council { 0 }

sub borough_for_report {
    my ($self, $problem) = @_;

    # Get relevant area ID from report
    my %areas = map { $_ => 1 } split ',', $problem->areas;
    my ($council_match) = grep { $areas{$_} } @{ $self->council_area_id };
    return unless $council_match;

    # Look up area names if not already fetched
    my $areas = $self->{c}->stash->{children} ||= $self->fetch_area_children;
    return $areas->{$council_match}{name};
}

sub abuse_reports_only { 1 }
sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => "London",
    };
}

sub get_geocoder { 'OSM' }

sub category_change_force_resend { 1 }

sub do_not_reply_email { shift->feature('do_not_reply_email') }

sub area_check {
    my ( $self, $params, $context ) = @_;

    my $councils = $params->{all_areas};
    my $council_match = grep { $councils->{$_} } @{ $self->council_area_id };

    return 1 if $council_match;
    return ( 0, $self->area_check_error_message($params, $context) );
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a London postcode, or street name and area, or a reference number of a problem previously reported';
}

sub privacy_policy_url { 'https://tfl.gov.uk/corporate/privacy-and-cookies/reporting-street-problems' }

sub about_hook {
    my $self = shift;
    my $c = $self->{c};

    if ($c->stash->{template} eq 'about/privacy.html') {
        $c->res->redirect($self->privacy_policy_url);
        $c->detach;
    }
}

sub body {
    # Overridden because UKCouncils::body excludes TfL
    FixMyStreet::DB->resultset('Body')->search({ name => 'TfL' })->first;
}

# These need to be overridden so the method in UKCouncils doesn't create
# a fixmystreet.com link (because of the false-returning owns_problem call)
sub relative_url_for_report { "" }
sub base_url_for_report {
    my $self = shift;
    return $self->base_url;
}

sub categories_restriction {
    my ($self, $rs) = @_;
    $rs = $rs->search( { 'body.name' => [ 'TfL', 'Highways England' ] } );
    return $rs unless $self->{c}->stash->{categories_for_point}; # Admin page
    return $rs->search( { category => { -not_in => $self->_tfl_no_resend_categories } } );
}

sub admin_user_domain { 'tfl.gov.uk' }

sub allow_anonymous_reports { 'button' }

sub anonymous_account {
    my $self = shift;
    return {
        email => $self->feature('anonymous_account') . '@' . $self->admin_user_domain,
        name => 'Anonymous user',
    };
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

sub report_sent_confirmation_email { 'id' }

sub report_age { '6 weeks' }

# We don't want any reports made before the go-live date visible
sub cut_off_date { '2019-12-09 12:00' }

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    $rs = $self->next::method($rs);
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    $rs = $rs->search({
        "$table.lastupdate" => { '>=', \"now() - '3 years'::interval" }
    });
    return $rs;
}

sub problems_sql_restriction {
    my ($self, $item_table) = @_;
    my $q = $self->next::method($item_table);
    if ($item_table ne 'comment') {
        $q .= " AND lastupdate >= now() - '3 years'::interval";
    }
    return $q;
}

sub inactive_reports_filter {
    my ($self, $time, $rs) = @_;
    if ($time < 7*12) {
        $rs = $rs->search({ extra => { like => '%safety_critical,T5:value,T2:no%' } });
    } else {
        $rs = $rs->search({ extra => { like => '%safety_critical,T5:value,T3:yes%' } });
    }
    return $rs;
}

sub password_expiry {
    return if FixMyStreet->test_mode;
    # uncoverable statement
    86400 * 365
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'green' if $p->is_closed;
    return 'green' if $p->is_fixed;
    return 'red' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
    return undef unless defined $user->from_body;
    return $user->from_body->name eq 'TfL';
}

sub around_nearby_filter {
    my ($self, $params) = @_;
    # Include all reports in duplicate spotting
    delete $params->{states};
}

sub state_groups_inspect {
    my $rs = FixMyStreet::DB->resultset("State");
    my @open = grep { $_ !~ /^(planned|action scheduled|for triage)$/ } FixMyStreet::DB::Result::Problem->open_states;
    my @closed = grep { $_ ne 'closed' } FixMyStreet::DB::Result::Problem->closed_states;
    [
        [ $rs->display('confirmed'), \@open ],
        [ $rs->display('fixed'), [ 'fixed - council' ] ],
        [ $rs->display('closed'), \@closed ],
    ]
}

sub fetch_area_children {
    my $self = shift;

    # This is for user admin display, in testing can only be London (for MapIt mock)
    my $ids = FixMyStreet->test_mode ? 'LBO' : $self->council_area_id;
    my $areas = FixMyStreet::MapIt::call('areas', $ids);
    foreach (keys %$areas) {
        $areas->{$_}->{name} =~ s/\s*(Borough|City|District|County) Council$//;
    }
    return $areas;
}

sub available_permissions {
    my $self = shift;

    my $perms = $self->next::method();

    delete $perms->{Problems}->{report_edit_priority};
    delete $perms->{Bodies}->{responsepriority_edit};

    return $perms;
}

sub dashboard_export_problems_add_columns {
    my $self = shift;
    my $c = $self->{c};

    my %groups;
    if ($c->stash->{body}) {
        %groups = FixMyStreet::DB->resultset('Contact')->search({
            body_id => $c->stash->{body}->id,
        })->group_lookup;
    }

    splice @{$c->stash->{csv}->{headers}}, 5, 0, 'Subcategory';
    splice @{$c->stash->{csv}->{columns}}, 5, 0, 'subcategory';

    $c->stash->{csv}->{headers} = [
        map { $_ eq 'Ward' ? 'Borough' : $_ } @{ $c->stash->{csv}->{headers} },
        "Agent responsible",
        "Safety critical",
        "Delivered to",
        "Closure email at",
        "Reassigned at",
        "Reassigned by",
    ];

    $c->stash->{csv}->{columns} = [
        @{ $c->stash->{csv}->{columns} },
        "agent_responsible",
        "safety_critical",
        "delivered_to",
        "closure_email_at",
        "reassigned_at",
        "reassigned_by",
    ];

    if ($c->stash->{category}) {
        my ($contact) = grep { $_->category eq $c->stash->{category} } @{$c->stash->{contacts}};
        if ($contact) {
            foreach (@{$contact->get_metadata_for_storage}) {
                next if $_->{code} eq 'safety_critical';
                push @{$c->stash->{csv}->{columns}}, "extra.$_->{code}";
                push @{$c->stash->{csv}->{headers}}, $_->{description};
            }
        }
    }

    $c->stash->{csv}->{extra_data} = sub {
        my $report = shift;

        my $agent = $report->shortlisted_user;

        my $change = $report->admin_log_entries->search(
            { action => 'category_change' },
            {
                join => 'user',
                '+columns' => ['user.name'],
                rows => 1,
                order_by => { -desc => 'me.id' }
            }
        )->single;
        my $reassigned_at = $change ? $change->whenedited : '';
        my $reassigned_by = $change ? $change->user->name : '';

        my $user_name_display = $report->anonymous
            ? '(anonymous ' . $report->id . ')' : $report->name;

        my $safety_critical = $report->get_extra_field_value('safety_critical') || 'no';
        my $delivered_to = $report->get_extra_metadata('sent_to') || [];
        my $closure_email_at = $report->get_extra_metadata('closure_alert_sent_at') || '';
        $closure_email_at = DateTime->from_epoch(
            epoch => $closure_email_at, time_zone => FixMyStreet->local_time_zone
        ) if $closure_email_at;
        my $fields = {
            acknowledged => $report->whensent,
            agent_responsible => $agent ? $agent->name : '',
            category => $groups{$report->category},
            subcategory => $report->category,
            user_name_display => $user_name_display,
            safety_critical => $safety_critical,
            delivered_to => join(',', @$delivered_to),
            closure_email_at => $closure_email_at,
            reassigned_at => $reassigned_at,
            reassigned_by => $reassigned_by,
        };
        foreach (@{$report->get_extra_fields}) {
            next if $_->{name} eq 'safety_critical';
            $fields->{"extra.$_->{name}"} = $_->{value};
        }
        return $fields;
    };
}

sub must_have_2fa {
    my ($self, $user) = @_;

    require Net::Subnet;
    my $ips = $self->feature('internal_ips');
    my $is_internal_network = Net::Subnet::subnet_matcher(@$ips);

    my $ip = $self->{c}->req->address;
    return 'skip' if $is_internal_network->($ip);
    return 1 if $user->is_superuser;
    return 1 if $user->from_body && $user->from_body->name eq 'TfL';
    return 0;
}

sub update_email_shortlisted_user {
    my ($self, $update) = @_;
    my $c = $self->{c};
    my $cobrand = FixMyStreet::Cobrand::TfL->new; # $self may be FMS
    my $shortlisted_by = $update->problem->shortlisted_user;
    if ($shortlisted_by && $shortlisted_by->from_body && $shortlisted_by->from_body->name eq 'TfL' && $shortlisted_by->id ne $update->user_id) {
        $c->send_email('alert-update.txt', {
            additional_template_paths => [
                FixMyStreet->path_to( 'templates', 'email', 'tfl' ),
                FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com'),
            ],
            to => [ [ $shortlisted_by->email, $shortlisted_by->name ] ],
            report => $update->problem,
            cobrand => $cobrand,
            problem_url => $cobrand->base_url . $update->problem->url,
            data => [ {
                item_photo => $update->photo,
                item_text => $update->text,
                item_name => $update->name,
                item_anonymous => $update->anonymous,
            } ],
        });
    }
}

sub report_new_munge_before_insert {
    my ($self, $report) = @_;

    # Sets the safety critical flag on this report according to category/extra
    # fields selected.

    my $safety_critical = 0;
    my $categories = $self->feature('safety_critical_categories');
    my $category = $categories->{$report->category};
    if ( ref $category eq 'HASH' ) {
        # report is safety critical if any of its field values match
        # the critical values from the config
        for my $code (keys %$category) {
            my $value = $report->get_extra_field_value($code);
            my %critical_values = map { $_ => 1 } @{ $category->{$code} };
            $safety_critical ||= $critical_values{$value};
        }
    } elsif ($category) {
        # the entire category is safety critical
        $safety_critical = 1;
    }

    my $extra = $report->get_extra_fields;
    @$extra = grep { $_->{name} ne 'safety_critical' } @$extra;
    push @$extra, { name => 'safety_critical', value => $safety_critical ? 'yes' : 'no' };
    $report->set_extra_fields(@$extra);
}

sub report_new_is_on_tlrn {
    my ( $self ) = @_;

    my ($x, $y) = Utils::convert_latlon_to_en(
        $self->{c}->stash->{latitude},
        $self->{c}->stash->{longitude},
        'G'
    );

    my $cfg = {
        url => "https://tilma.mysociety.org/mapserver/tfl",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "RedRoutes",
        filter => "<Filter><Contains><PropertyName>geom</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point></Contains></Filter>",
    };

    my $features = $self->_fetch_features($cfg, $x, $y);
    return scalar @$features ? 1 : 0;
}

sub munge_reports_area_list {
    my ($self, $areas) = @_;
    my %london_hash = map { $_ => 1 } $self->london_boroughs;
    @$areas = grep { $london_hash{$_} } @$areas;
}

sub munge_report_new_contacts { }

sub munge_report_new_bodies {
    my ($self, $bodies) = @_;

    # Highways England handling
    my $c = $self->{c};
    my $he = FixMyStreet::Cobrand::HighwaysEngland->new({ c => $c });
    my $on_he_road = $c->stash->{on_he_road} = $he->report_new_is_on_he_road;

    if (!$on_he_road) {
        %$bodies = map { $_->id => $_ } grep { $_->name ne 'Highways England' } values %$bodies;
    }
}

sub munge_surrounding_london {
    my ($self, $bodies) = @_;
    # Are we in a London borough?
    my $all_areas = $self->{c}->stash->{all_areas};
    my %london_hash = map { $_ => 1 } $self->london_boroughs;
    if (!grep { $london_hash{$_} } keys %$all_areas) {
        # Don't send any TfL categories
        %$bodies = map { $_->id => $_ } grep { $_->name ne 'TfL' } values %$bodies;
    }
}

sub munge_red_route_categories {
    my ($self, $contacts) = @_;
    if ( $self->report_new_is_on_tlrn ) {
        # We're on a red route - only send TfL categories (except the disabled
        # ones that direct the user to borough for street cleaning & flytipping)
        # and borough street cleaning/flytipping categories.
        my %cleaning_cats = map { $_ => 1 } @{ $self->_cleaning_categories };
        my %council_cats = map { $_ => 1 } @{ $self->_tfl_council_categories };
        @$contacts = grep {
            ( $_->body->name eq 'TfL' && !$council_cats{$_->category} )
            || $cleaning_cats{$_->category}
            || @{ mySociety::ArrayUtils::intersection( $self->_cleaning_groups, $_->groups ) }
        } @$contacts;
    } else {
        # We're not on a red route - send all categories except
        # TfL red-route-only and the TfL street cleaning & flytipping.
        my %tlrn_cats = (
            map { $_ => 1 } @{ $self->_tlrn_categories },
            map { $_ => 1 } @{ $self->_tfl_council_categories },
        );
        @$contacts = grep { !( $_->body->name eq 'TfL' && $tlrn_cats{$_->category } ) } @$contacts;
    }
}

# Reports in these categories can only be made on a red route
sub _tlrn_categories { [
    "All out - three or more street lights in a row",
    "Blocked drain",
    "Damage - general (Trees)",
    "Dead animal in the carriageway or footway",
    "Debris in the carriageway",
    "Fallen Tree",
    "Flooding",
    "Graffiti / Flyposting (non-offensive)",
    "Graffiti / Flyposting (offensive)",
    "Graffiti / Flyposting on street light (non-offensive)",
    "Graffiti / Flyposting on street light (offensive)",
    "Grass Cutting and Hedges",
    "Hoardings blocking carriageway or footway",
    "Light on during daylight hours",
    "Lights out in Pedestrian Subway",
    "Low hanging branches and general maintenance",
    "Manhole Cover - Damaged (rocking or noisy)",
    "Manhole Cover - Missing",
    "Mobile Crane Operation",
    "Other (TfL)",
    "Pavement Defect (uneven surface / cracked paving slab)",
    "Pothole",
    "Pothole (minor)",
    "Roadworks",
    "Scaffolding blocking carriageway or footway",
    "Single Light out (street light)",
    "Standing water",
    "Street Light - Equipment damaged, pole leaning",
    "Unstable hoardings",
    "Unstable scaffolding",
    "Worn out road markings",
] }

sub _cleaning_categories { [
    'Street cleaning',
    'Street Cleaning',
    'Street cleaning and litter',
    'Accumulated Litter',
    'Street Cleaning Enquiry',
    'Street Cleansing',
    'Flytipping',
    'Fly tipping',
    'Fly Tipping',
    'Fly-tipping',
    'Fly-Tipping',
    'Fly tipping - Enforcement Request',
] }

sub _cleaning_groups { [ 'Street cleaning', 'Fly-tipping' ] }

sub _tfl_council_categories { [
    'General Litter / Rubbish Collection',
    'Flytipping (TfL)',
] }

sub _tfl_no_resend_categories { [
    'Countdown - not working',
    'General Litter / Rubbish Collection',
    'Flytipping (TfL)',
    'Other (TfL)',
    'Timings',
] }

1;
