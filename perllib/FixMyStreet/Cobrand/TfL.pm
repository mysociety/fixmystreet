package FixMyStreet::Cobrand::TfL;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use POSIX qw(strcoll);

use FixMyStreet::MapIt;
use mySociety::ArrayUtils;
use Utils;

sub council_area_id { return [
    2511, 2489, 2494, 2488, 2482, 2505, 2512, 2481, 2484, 2495,
    2493, 2508, 2502, 2509, 2487, 2485, 2486, 2483, 2507, 2503,
    2480, 2490, 2492, 2500, 2510, 2497, 2499, 2491, 2498, 2506,
    2496, 2501, 2504
]; }
sub council_area { return 'TfL'; }
sub council_name { return 'TfL'; }
sub council_url { return 'tfl'; }
sub area_types  { [ 'LBO' ] }
sub is_council { 0 }

sub abuse_reports_only { 1 }
sub send_questionnaires { 0 }

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
    return 'Enter a London postcode, or street name and area, or a reference number of a problem previous reported';
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
    return $rs->search( { 'body.name' => 'TfL' } );
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

    my $areas = FixMyStreet::MapIt::call('areas', $self->area_types);
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
        %groups = FixMyStreet::DB->resultset('Contact')->active->search({
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
            { prefetch => 'user', rows => 1, order_by => { -desc => 'me.id' } }
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
    my $shortlisted_by = $update->problem->shortlisted_user;
    if ($shortlisted_by && $shortlisted_by->from_body && $shortlisted_by->from_body->name eq 'TfL' && $shortlisted_by->id ne $update->user_id) {
        $c->send_email('alert-update.txt', {
            to => [ [ $shortlisted_by->email, $shortlisted_by->name ] ],
            report => $update->problem,
            problem_url => $c->cobrand->base_url_for_report($update->problem) . $update->problem->url,
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

=head2 munge_sendreport_params

TfL want reports made in certain categories sent to different email addresses
depending on what London Borough they were made in. To achieve this we have
some config in COBRAND_FEATURES that specifies what address to direct reports
to based on the MapIt area IDs it's in.

Contacts that use this technique have a short code in their email field,
which is looked up in the `borough_email_addresses` hash.

For example, if you wanted Pothole reports in Bromley and Barnet to be sent to
one email address, and Pothole reports in Hounslow to be sent to another,
create a contact with category = "Potholes" and email = "BOROUGHPOTHOLES" and
use the following config in general.yml:

COBRAND_FEATURES:
  borough_email_addresses:
    tfl:
      BOROUGHPOTHOLES:
        - email: bromleybarnetpotholes@example.org
          areas:
            - 2482 # Bromley
            - 2489 # Barnet
        - email: hounslowpotholes@example.org
          areas:
            - 2483 # Hounslow

=cut

sub munge_sendreport_params {
    my ($self, $row, $h, $params) = @_;

    my $addresses = $self->feature('borough_email_addresses');
    return unless $addresses;

    my @report_areas = grep { $_ } split ',', $row->areas;

    my $to = $params->{To};
    my @munged_to = ();
    for my $recip ( @$to ) {
        my ($email, $name) = @$recip;
        if (my $teams = $addresses->{$email}) {
            for my $team (@$teams) {
                my %team_area_ids = map { $_ => 1 } @{ $team->{areas} };
                if ( grep { $team_area_ids{$_} } @report_areas ) {
                    $recip = [
                        $team->{email},
                        $name
                    ];
                }
            }
        }
        push @munged_to, $recip;
    }
    $params->{To} = \@munged_to;
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

sub munge_report_new_category_list { }

sub munge_red_route_categories {
    my ($self, $options, $contacts) = @_;
    if ( $self->report_new_is_on_tlrn ) {
        # We're on a red route - only send TfL categories (except the disabled
        # one that directs the user to borough for street cleaning) and borough
        # street cleaning categories.
        my %cleaning_cats = map { $_ => 1 } @{ $self->_cleaning_categories };
        @$contacts = grep {
            ( $_->body->name eq 'TfL' && $_->category ne $self->_tfl_council_category )
            || $cleaning_cats{$_->category}
            || @{ mySociety::ArrayUtils::intersection( $self->_cleaning_groups, $_->groups ) }
        } @$contacts;
    } else {
        # We're not on a red route - send all categories except
        # TfL red-route-only and the TfL street cleaning.
        my %tlrn_cats = map { $_ => 1 } @{ $self->_tlrn_categories };
        $tlrn_cats{$self->_tfl_council_category} = 1;
        @$contacts = grep { !( $_->body->name eq 'TfL' && $tlrn_cats{$_->category } ) } @$contacts;
    }
    my $seen = { map { $_->category => 1 } @$contacts };
    @$options = grep { my $c = ($_->{category} || $_->category); $c =~ 'Pick a category' || $seen->{ $c } } @$options;
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
    "Flytipping (TfL)",
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
    "Unstable hoardings",
    "Unstable scaffolding",
    "Worn out road markings",
] }

sub _cleaning_categories { [
    'Street cleaning',
    'Street Cleaning',
    'Accumulated Litter',
    'Street Cleaning Enquiry',
    'Street Cleansing',
] }

sub _cleaning_groups { [ 'Street cleaning' ] }

sub _tfl_council_category { 'General Litter / Rubbish Collection' }

1;
