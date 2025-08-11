=head1 NAME

FixMyStreet::Cobrand::TfL - code specific to the Transport for London cobrand

=head1 SYNOPSIS

Transport for London is an FMS integration. It covers multiple London Borough areas

=cut

package FixMyStreet::Cobrand::TfL;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;
use utf8;

use Moo;

=head1 DESCRIPTION

TfL has features related to covering multiple London areas. It doesn't have an external
integration with a backend, but does have single sign-on with Azure for staff users - they
are assigned an FMS account and user role when logging in.

=cut

with 'FixMyStreet::Roles::BoroughEmails';

use POSIX qw(strcoll);

use FixMyStreet::MapIt;
use mySociety::ArrayUtils;
use Utils;

sub council_area_id { [ $_[0]->london_boroughs, $_[0]->surrounding_london ] }

sub council_area { return 'TfL'; }
sub council_name { return 'TfL'; }
sub council_url { return 'tfl'; }
sub area_types  { [ 'LBO', 'UTA', 'DIS' ] }

=head1 Defaults

=over 4

=item * TfL only allows contact form to report abusive reports

=cut

sub abuse_reports_only { 1 }

=item * Reports made to TfL do not get followed up by a questionnaire

=cut

sub send_questionnaires { 0 }

=item * TfL geocoding automatically sets town to London

=cut

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    if ($string =~ /victoria coach station|vcs/i) {
        return { result => { latitude => 51.49228, longitude => -0.1488 } };
    }

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => "London",
        result_strip => ', London, Greater London, England',
    };
}

=item * TfL is not a council so prevent council related versions of text appearing on the web and in emails

=cut

sub is_council { 0 }

=item * TfL is set to resend a report if the category is updated

=cut

sub category_change_force_resend { 1 }

=item * TfL has customised front page prompt for entering a search

=cut

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a London postcode, or street name and area, or a reference number of a problem previously reported';
}

=item * TfL has its own privacy policy, which we redirect to from /about/privacy

=cut

sub privacy_policy_url { 'https://tfl.gov.uk/corporate/privacy-and-cookies/reporting-street-problems' }

sub about_hook {
    my $self = shift;
    my $c = $self->{c};

    if ($c->stash->{template} eq 'about/privacy.html') {
        $c->res->redirect($self->privacy_policy_url);
        $c->detach;
    }
}

=item * TfL has green pins for closed/fixed, red for confirmed, and orange for everything else

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'green' if $p->is_closed;
    return 'green' if $p->is_fixed;
    return 'red' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

=item * Superusers and TfL staff can access the TfL admin

=cut

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
    return undef unless defined $user->from_body;
    return $user->from_body->get_column('name') eq 'TfL';
}


=item * Restrict admin users to tfl.gov.uk email addresses

=cut

sub admin_user_domain { 'tfl.gov.uk' }

=item * Sets anonymous reports to show a button for anonymous reporting

=cut

sub allow_anonymous_reports { 'button' }

=item * TfL sends out confirmation emails when a report is made

=cut

sub report_sent_confirmation_email { 'id' }

=item * TfL only shows reports on the map and in the report list for 6 weeks

=cut

sub report_age { '6 weeks' }

=item * TfL doesn't show reports made before the go-live date (2019-12-09)

=cut

sub cut_off_date { '2019-12-09 12:00' }

=back

=head2 relative_url_for_report & base_url_for_report

These are overridden so the method in UKCouncils doesn't create
a fixmystreet.com link (because of the false-returning owns_problem call)

=cut

sub relative_url_for_report { "" }
sub base_url_for_report {
    my $self = shift;
    return $self->base_url;
}

=head1 Multi council features

TfL covers a lot of areas and has features necessary to work across areas.
It sends emails in some categories to different addresses depending on Borough
using L<FixMyStreet::Roles::BoroughEmails>.

The cobrand covers London and its surrounding areas, as e.g. some bus stops are
outside London.

=cut

# A list of all the London Borough MapIt IDs
sub london_boroughs { (
    2511, 2489, 2494, 2488, 2482, 2505, 2512, 2481, 2484, 2495,
    2493, 2508, 2502, 2509, 2487, 2485, 2486, 2483, 2507, 2503,
    2480, 2490, 2492, 2500, 2510, 2497, 2499, 2491, 2498, 2506,
    2496, 2501, 2504,
) }

=pod

These are Clockwise from top left: South Bucks, Three Rivers, Watford, Hertsmere,
Welwyn Hatfield, Broxbourne, Epping Forest, Brentwood, Thurrock, Dartford, Sevenoaks,
Tandridge, Reigate and Banstead, Epsom and Ewell, Mole Valley, Elmbridge, Spelthorne, Slough

=cut

sub surrounding_london { (
    2256, 2338, 2346, 2339, 2344, 2340, 2311, 2309, 2615,
    2358, 2350, 2448, 2453, 2457, 2454, 2455, 2456, 2606,
) }

=over 4

=item * For staff, the Borough the report is made in is shown when listing reports

=cut

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

=item * Extra bodies can appear from configuration (e.g. hire bike companies)

=item * A few categories don't appear to admins as we don't want to be able to resend reports to them

=cut

sub categories_restriction {
    my ($self, $rs) = @_;
    my $bodies = [ 'TfL', 'National Highways' ];
    push @$bodies, @{$self->feature('categories_restriction_bodies') || []};
    $rs = $rs->search( { 'body.name' => $bodies } );
    return $rs unless $self->{c}->stash->{categories_for_point}; # Admin page
    return $rs->search( { category => { -not_in => $self->_tfl_no_resend_categories } } );
}

=back

=head1 Problem display and searching

=over 4

=item * You can search for reports from the front page using FMS[id].

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

=item * Limit problem listings history to problems that have been updated in the last 3 years

=cut

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

=item * Reports are deleted from TfL after 7 years if they are safety critical, or after 3 years if they are not

=cut

sub inactive_reports_filter {
    my ($self, $time, $rs) = @_;
    if ($time < 7*12) {
        $rs = $rs->search({ extra => { '@>' => '{"_fields":[{"name":"safety_critical","value":"no"}]}' } });
    } else {
        $rs = $rs->search({ extra => { '@>' => '{"_fields":[{"name":"safety_critical","value":"yes"}]}' } });
    }
    return $rs;
}

=item * Include all reports in duplicate spotting, not just open ones

=cut

sub around_nearby_filter {
    my ($self, $params) = @_;

    delete $params->{states};
}

=back

=head1 OIDC single sign on

TfL staff users use an Azure single-sign on integration

=over 4

=item * Single sign on is enabled if the configuration is set up

=cut

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

=item * Non-staff users must change their passwords annually; staff users don't use passwords so are excluded

=cut

sub password_expiry {
    my ($self) = @_;

    my $email = $self->{c}->user->email;
    my $domain_email = $self->admin_user_domain;
    return if $email =~ /$domain_email$/;

    # uncoverable statement
    86400 * 365
}

=item * Different single sign-ons send user details differently, user_from_oidc extracts the relevant parts

=cut

sub user_from_oidc {
    my ($self, $payload) = @_;

    my $name = join(" ", $payload->{given_name}, $payload->{family_name});
    my $email = $payload->{email} ? lc($payload->{email}) : '';

    return ($name, $email);
}

sub state_groups_inspect {
    my $rs = FixMyStreet::DB->resultset("State");
    my @open = grep { $_ !~ /^(planned|investigating|for triage|twin)$/ } FixMyStreet::DB::Result::Problem->open_states;
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
    my ($self, $csv) = @_;

    $csv->modify_csv_header( Ward => 'Borough' );

    $csv->add_csv_columns(
        bike_number => "Bike number",
        assigned_to => "Agent responsible",
        safety_critical => "Safety critical",
        delivered_to => "Delivered to",
        closure_email_at => "Closure email at",
        reassigned_at => "Reassigned at",
        reassigned_by => "Reassigned by",
    );
    $csv->splice_csv_column('fixed', action_scheduled => 'Action scheduled');

    my @contacts = $csv->body->contacts->order_by('category')->all;
    my %extra_columns;
    foreach my $contact (@contacts) {
        foreach (@{$contact->get_metadata_for_storage}) {
            next if $_->{code} eq 'safety_critical';
            $extra_columns{"extra.$_->{code}"} = $_->{description} || $_->{code};
        }
    }
    my @extra_columns = map { $_ => $extra_columns{$_} } sort keys %extra_columns;
    $csv->add_csv_columns(@extra_columns);

    if ($csv->dbi) {
        $csv->csv_extra_data(sub {
            my $report = shift;

            my $user_name_display = $report->{anonymous}
                ? '(anonymous ' . $report->{id} . ')' : $report->{name};

            my $bike_number = $csv->_extra_field($report, 'Question') || '';
            my $safety_critical = $csv->_extra_field($report, 'safety_critical') || 'no';
            my $delivered_to = $csv->_extra_metadata($report, 'sent_to') || [];
            my $closure_email_at = $csv->_extra_metadata($report, 'closure_alert_sent_at') || '';
            $closure_email_at = DateTime->from_epoch(
                epoch => $closure_email_at, time_zone => FixMyStreet->local_time_zone
            ) if $closure_email_at;
            my $fields = {
                acknowledged => $report->{whensent},
                user_name_display => $user_name_display,
                safety_critical => $safety_critical,
                delivered_to => join(',', @$delivered_to),
                closure_email_at => $closure_email_at,
                bike_number => $bike_number,
            };
            foreach (@{$csv->_extra_field($report)}) {
                next if $_->{name} eq 'safety_critical';
                $fields->{"extra.$_->{name}"} = $_->{value};
            }
            return $fields;
        });
        return;
    }

    $csv->csv_extra_data(sub {
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

        my $bike_number = $csv->_extra_field($report, 'Question') || '';
        my $safety_critical = $csv->_extra_field($report, 'safety_critical') || 'no';
        my $delivered_to = $csv->_extra_metadata($report, 'sent_to') || [];
        my $closure_email_at = $csv->_extra_metadata($report, 'closure_alert_sent_at') || '';
        $closure_email_at = DateTime->from_epoch(
            epoch => $closure_email_at, time_zone => FixMyStreet->local_time_zone
        ) if $closure_email_at;
        my $fields = {
            acknowledged => $report->whensent,
            assigned_to => $agent ? $agent->name : '',
            user_name_display => $user_name_display,
            safety_critical => $safety_critical,
            delivered_to => join(',', @$delivered_to),
            closure_email_at => $closure_email_at,
            reassigned_at => $reassigned_at,
            reassigned_by => $reassigned_by,
            bike_number => $bike_number,
        };
        foreach (@{$csv->_extra_field($report)}) {
            next if $_->{name} eq 'safety_critical';
            $fields->{"extra.$_->{name}"} = $_->{value};
        }
        return $fields;
    });
}

sub must_have_2fa {
    my ($self, $user) = @_;

    require Net::Subnet;
    my $ips = $self->feature('internal_ips');
    my $is_internal_network = Net::Subnet::subnet_matcher(@$ips);

    my $ip = $self->{c}->req->address;
    return 'skip' if $is_internal_network->($ip);
    return 1 if $user->is_superuser;
    return 1 if $user->from_body && $user->from_body->get_column('name') eq 'TfL';
    return 0;
}

sub update_email_shortlisted_user {
    my ($self, $update) = @_;
    my $c = $self->{c};
    my $cobrand = FixMyStreet::Cobrand::TfL->new; # $self may be FMS
    my $shortlisted_by = $update->problem->shortlisted_user;
    if ($shortlisted_by && $shortlisted_by->from_body && $shortlisted_by->from_body->get_column('name') eq 'TfL' && $shortlisted_by->id ne $update->user_id) {
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

=back

=head2 report_validation

Allow through "TfL" as a name if reporting as staff.

=cut

sub report_validation {
    my ($self, $report, $errors) = @_;

    if ($errors->{name} && $report->name eq 'TfL' && $report->user->from_body) {
        delete $errors->{name};
    }
}

sub report_new_is_on_tlrn {
    my ( $self ) = @_;

    return if FixMyStreet->test_mode eq 'cypress';

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

sub disable_login_for_email {
    my ($self, $email) = @_;

    my $staff_email = $self->admin_user_domain;

    if ($email =~ /$staff_email$/) {
        $self->{c}->detach('/page_error_403_access_denied', ['Please use the staff login option']);
    }
}

sub munge_report_new_bodies {
    my ($self, $bodies) = @_;

    # National Highways handling
    my $c = $self->{c};
    my $he = FixMyStreet::Cobrand::HighwaysEngland->new({ c => $c });
    my $on_he_road = $c->stash->{on_he_road} = $he->report_new_is_on_he_road;

    if (!$on_he_road) {
        %$bodies = map { $_->id => $_ } grep { $_->get_column('name') ne 'National Highways' } values %$bodies;
    }
    # Environment agency added with odour category for FixmyStreet
    # in all England areas, but should not show for cobrands
    if ( $bodies->{'Environment Agency'} ) {
        %$bodies = map { $_->id => $_ } grep { $_->get_column('name') ne 'Environment Agency' } values %$bodies;
    }
}

sub munge_surrounding_london {
    my ($self, $bodies) = @_;
    # Are we in a London borough?
    my $all_areas = $self->{c}->stash->{all_areas};
    my %london_hash = map { $_ => 1 } $self->london_boroughs;
    if (!grep { $london_hash{$_} } keys %$all_areas) {
        # Don't send any TfL categories
        %$bodies = map { $_->id => $_ } grep { $_->get_column('name') ne 'TfL' } values %$bodies;
    }

    # Hackney doesn't have any of the council TfL categories so don't show
    # any Hackney categories on red routes
    my %bodies = map { $_->get_column('name') => $_->id } values %$bodies;
    if ( $bodies{'Hackney Council'} && $self->report_new_is_on_tlrn ) {
        delete $bodies->{ $bodies{'Hackney Council'} };
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
        my %extra_bodies = map { $_ => 1 } @{ $self->feature('categories_restriction_bodies') || [] };
        @$contacts = grep {
            ( $_->body->get_column('name') eq 'TfL' && !$council_cats{$_->category} )
            || $extra_bodies{$_->body->get_column('name')}
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
        @$contacts = grep { !( $_->body->get_column('name') eq 'TfL' && $tlrn_cats{$_->category } ) } @$contacts;
    }
}

sub validate_contact_email {
    my ( $self, $email ) = @_;

    my $email_addresses = $self->feature('borough_email_addresses');
    for my $borough_email (keys %$email_addresses) {
        return 1 if $borough_email eq $email;
    };
}

around 'munge_sendreport_params' => sub {
    my ($orig, $self, $row, $h, $params) = @_;

    $self->$orig($row, $h, $params);

    $params->{From} = [ $self->do_not_reply_email, $self->contact_name ];
    delete $params->{'Reply-To'} if $params->{'Reply-To'};
};

sub is_hardcoded_category {
    my ($self, $category) = @_;

    my %cats = (
        %{ $self->feature('safety_critical_categories') || {} },
        map { $_ => 1 } @{ $self->_tlrn_categories }, @{ $self->_tfl_council_categories }, @{ $self->_tfl_no_resend_categories },
    );

    return $cats{$category};
}

# Reports in these categories can only be made on a red route
sub _tlrn_categories {
    return FixMyStreet::DB->resultset("Config")->get('tlrn_categories') || [];
}
sub tlrn_categories_json {
    return JSON::MaybeXS->new->encode(_tlrn_categories());
}

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
    'Graffiti and Flyposting', # Bromley
    'Street cleaning/sweeping', # Camden
    # Southwark have a variety of flytipping and street littering categories
    'Abandoned Bike (Street)',
    'Clear Broken Glass (Street)',
    'Dog Waste Bin - Emptying',
    'Dog Waste Clearance (Street)',
    'Dog Waste - Signs',
    'Fly Posting - General (Street)',
    'Fly Posting - Racist/Obscene (Street)',
    'Flytipping - Animal Carcass (Street)',
    'Flytipping - Asbestos (Street)',
    'Flytipping - Black Bags (Street)',
    'Flytipping - Blk Bags Commercial (Street)',
    'Flytipping - Builders Rubble (Street)',
    'Flytipping - Chemical Drums (Street)',
    'Flytipping - Clinical (Street)',
    'Flytipping - Drug related Litter (Street)',
    'Flytipping - General (Street)',
    'Flytipping - Green Waste (Street)',
    'Flytipping - Other Electrical (Street)',
    'Flytipping - Other (Unidentified) (Street)',
    'Flytipping - Tyres (Street)',
    'Flytipping - Vehicle Parts (Street)',
    'Flytipping - White Goods (Street)',
    'Graffiti - General (Street)',
    'Graffiti - Racist / Obscene',
    'Litter Bin - Emptying',
    'Litter Bin - Move or Remove',
    'Street - Furniture Cleaning',
    'Street - Leafing Request',
    'Street Litter Picking',
    'Street - Weeding Request',
    # Merton want all of their street cleaning categories visible on Red Routes
    'Abandoned Vehicles',
    'Clinical Waste on Street',
    'Dead Animal',
    'Dog Fouling',
    'Fly-Posting',
    'Graffiti',
    'Litter or Weeds on a Street',
    'Faulty Christmas Lights',
    # Westminster additional categories by request
    'Abandoned bike',
    'Abandoned hire bicycles/e-scooters',
    'Animal Nuisance',
    'Busking and Street performance',
    'Engine idling',
    'Flytipping',
    'Parks/landscapes',
    'Street bin issue',
    'Street cleaning',
] }

sub _cleaning_groups { [ 'Street cleaning', 'Street Cleansing', 'Fly-tipping', 'Street cleaning issues' ] }

sub _tfl_council_categories { [
    'General Litter / Rubbish Collection',
    'Flytipping (TfL)',
] }

sub _tfl_no_resend_categories { [
    'General Litter / Rubbish Collection',
    'Flytipping (TfL)',
    'Other (TfL)',
    'Timings',
] }

1;
