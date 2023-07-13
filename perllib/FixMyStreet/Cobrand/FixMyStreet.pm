package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::UK';

use Moo;
use LWP::Simple;
use JSON::MaybeXS;
use Try::Tiny;
with 'FixMyStreet::Roles::BoroughEmails';

use constant COUNCIL_ID_BROMLEY => 2482;
use constant COUNCIL_ID_ISLEOFWIGHT => 2636;

sub on_map_default_status { return 'open'; }

sub on_welsh_site {
    my $self = shift;
    return $self->{c} && $self->{c}->req->uri->host =~ /^cy\./;
}

sub map_type {
    my $self = shift;
    return 'OSM::Cymru' if $self->on_welsh_site;
    return $self->next::method();
}

sub suggest_duplicates { 1 };

sub around_nearby_filter {
    my ($self, $params) = @_;

    if (!$params->{bodies}) {
        $params->{fms_no_duplicate} = 1;
        return;
    }
    my $bodies = decode_json($params->{bodies});
    my $bodies_with_duplicate_feature = FixMyStreet->config('COBRAND_FEATURES')->{suggest_duplicates} || {};
    my @cobrands;
    for my $cobrand (keys %$bodies_with_duplicate_feature) {
        push @cobrands, FixMyStreet::Cobrand->get_class_for_moniker($cobrand)->new;
    }
    for my $council (@cobrands) {
        if ($council->body && grep( { $_ eq $council->body->name || $_ eq $council->body->cobrand_name } @$bodies)) {
            return;
        }
    };

    $params->{fms_no_duplicate} = 1;
}

sub example_places {
    my $self = shift;
    return [ 'SY23 4AD', 'Abertawe' ] if $self->on_welsh_site;
    return $self->next::method();
}

sub disambiguate_location {
    my $self = shift;
    my $ret = $self->next::method();
    if ($self->on_welsh_site) {
        $ret->{bing_culture} = 'cy';
        $ret->{bing_country} = 'Y Deyrnas Unedig';
    }
    return $ret;
}

sub recent_photos {
    my ($self, $area, $num, $lat, $lon, $dist) = @_;
    return $self->problems->recent_photos({
        num => $num,
        point => [$lat, $lon, $dist],
        $self->on_welsh_site ? (
            extra_key => 'cy',
            bodies => [
                2549, 2554, 2557, 2558, 2559, 2560, 2570, 2585, 2592, 2595, 2599,
                2602, 2603, 2604, 2605, 2616, 2624, 2637, 2638, 2639, 2640, 2641,
            ],
        ) : (),
    });
}

# Show TfL pins as grey
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->to_body_named('TfL');
    return $self->next::method($p, $context);
}

# Special extra
sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web/fixmystreet.com' ),
    ];
}
sub path_to_email_templates {
    my ( $self, $lang_code ) = @_;
    return [
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com', $lang_code ),
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com'),
        FixMyStreet->path_to( 'templates', 'email', 'default', $lang_code ),
    ];
}

# FixMyStreet should return all cobrands
sub restriction {
    return {};
}

# FixMyStreet needs to not show TfL reports or Bromley waste reports
sub problems_restriction {
    my ($self, $rs) = @_;
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    return $rs->search({
        "$table.cobrand" => { '!=' => 'tfl' },
        "$table.cobrand_data" => { '!=' => 'waste' },
    });
}
sub problems_sql_restriction {
    my $self = shift;
    return "AND cobrand != 'tfl'";
    # Doesn't need Bromley one as all waste reports non-public
}

sub relative_url_for_report {
    my ( $self, $report ) = @_;
    return $report->cobrand eq 'tfl' ? FixMyStreet::Cobrand::TfL->base_url : "";
}

sub munge_around_category_where {
    my ($self, $where) = @_;

    my $iow = grep { $_->name eq 'Isle of Wight Council' } @{ $self->{c}->stash->{around_bodies} };
    if ($iow) {
        # display all the categories on Isle of Wight at the moment as there's no way to
        # do the expand bit later as we fetch it using ajax which uses a bounding box so
        # can't determine the body
        $where->{send_method} = [ { '!=' => 'Triage' }, undef ];
    }
    my $waste = grep { $_->name =~ /Bromley Council|Peterborough City Council/ } @{ $self->{c}->stash->{around_bodies} };
    if ($waste) {
        $where->{'-or'} = [
            extra => undef,
            -not => { extra => { '@>' => '{"type":"waste"}' } }
        ];
    }
}

sub _iow_category_munge {
    my ($self, $body, $categories) = @_;
    my $user = $self->{c}->user;

    if ( $user && ( $user->is_superuser || $user->belongs_to_body( $body->id ) ) ) {
        @$categories = grep { !$_->send_method || $_->send_method ne 'Triage' } @$categories;
        return;
    }

    @$categories = grep { $_->send_method && $_->send_method eq 'Triage' } @$categories;
}

sub munge_reports_category_list {
    my ($self, $categories) = @_;

    my %bodies = map { $_->body->name => $_->body } @$categories;
    if ( my $body = $bodies{'Isle of Wight Council'} ) {
        return $self->_iow_category_munge($body, $categories);
    }

    @$categories = grep { $_->get_extra_metadata('type', '') ne 'waste' } @$categories;
}

sub munge_reports_area_list {
    my ($self, $areas) = @_;
    my $c = $self->{c};
    if ($c->stash->{body}->name eq 'TfL') {
        my %london_hash = map { $_ => 1 } FixMyStreet::Cobrand::TfL->london_boroughs;
        @$areas = grep { $london_hash{$_} } @$areas;
    }
}

sub munge_report_new_bodies {
    my ($self, $bodies) = @_;

    my %bodies = map { $_->name => 1 } values %$bodies;
    if ( $bodies{'TfL'} ) {
        # Presented categories vary if we're on/off a red route
        my $tfl = FixMyStreet::Cobrand::TfL->new({ c => $self->{c} });
        $tfl->munge_surrounding_london($bodies);
    }

    if ( $bodies{'National Highways'} ) {
        my $c = $self->{c};
        my $he = FixMyStreet::Cobrand::HighwaysEngland->new({ c => $c });
        my $on_he_road = $c->stash->{on_he_road} = $he->report_new_is_on_he_road;

        if (!$on_he_road) {
            %$bodies = map { $_->id => $_ } grep { $_->name ne 'National Highways' } values %$bodies;
        }
    }

    if ( $bodies{'Thamesmead'} ) {
        my $thamesmead = FixMyStreet::Cobrand::Thamesmead->new({ c => $self->{c} });
        $thamesmead->munge_thamesmead_body($bodies);
    }

    if ( $bodies{'Bristol City Council'} ) {
        my $bristol = FixMyStreet::Cobrand::Bristol->new({ c => $self->{c} });
        $bristol->munge_overlapping_asset_bodies($bodies);
    }

    if ( $bodies{'Brent Council'} ) {
        my $brent = FixMyStreet::Cobrand::Brent->new({ c => $self->{c} });
        $brent->munge_overlapping_asset_bodies($bodies);
    }
}

sub munge_report_new_contacts {
    my ($self, $contacts) = @_;

    # Ignore contacts with a special type (e.g. waste, noise, claim)
    @$contacts = grep { !$_->get_extra_metadata('type') } @$contacts;

    my %bodies = map { $_->body->name => $_->body } @$contacts;

    if ( my $body = $bodies{'Isle of Wight Council'} ) {
        return $self->_iow_category_munge($body, $contacts);
    }

    if ( $bodies{'TfL'} ) {
        # Presented categories vary if we're on/off a red route
        my $tfl = FixMyStreet::Cobrand->get_class_for_moniker( 'tfl' )->new({ c => $self->{c} });
        $tfl->munge_red_route_categories($contacts);
    }

    if ( $bodies{'Thamesmead'} ) {
        my $thamesmead = FixMyStreet::Cobrand::Thamesmead->new({ c => $self->{c} });
        $thamesmead->munge_categories($contacts);
    }

    if ( $bodies{'Southwark Council'} ) {
        my $southwark = FixMyStreet::Cobrand::Southwark->new({ c => $self->{c} });
        $southwark->munge_categories($contacts);
    }

    if ( $bodies{'National Highways'} ) {
        my $nh = FixMyStreet::Cobrand::HighwaysEngland->new({ c => $self->{c} });
        $nh->national_highways_cleaning_groups($contacts);
    }

    if ( $bodies{'Brent Council'} ) {
        my $brent = FixMyStreet::Cobrand::Brent->new({ c => $self->{c} });
        $brent->munge_cobrand_asset_categories($contacts);
    }
}

sub munge_unmixed_category_groups {
    my ($self, $groups, $opts) = @_;
    return unless $opts->{reporting};
    my $bodies = $self->{c}->stash->{bodies};
    my %bodies = map { $_->name => 1 } values %$bodies;
    if ($bodies{"Buckinghamshire Council"}) {
        my @category_groups = grep { $_->{name} ne 'Car park issue' } @$groups;
        my ($car_park_group) = grep { $_->{name} eq 'Car park issue' } @$groups;
        @$groups = (@category_groups, $car_park_group);
    }
}

sub munge_load_and_group_problems {
    my ($self, $where, $filter) = @_;

    return unless $where->{'me.category'} && $self->{c}->stash->{body}->name eq 'Isle of Wight Council';

    my $iow = FixMyStreet::Cobrand->get_class_for_moniker( 'isleofwight' )->new({ c => $self->{c} });
    $where->{'me.category'} = $iow->expand_triage_cat_list($where->{'me.category'}, $self->{c}->stash->{body});
}

sub title_list {
    my $self = shift;
    my $areas = shift;
    my $first_area = ( values %$areas )[0];

    return ["MR", "MISS", "MRS", "MS", "DR"] if $first_area->{id} eq COUNCIL_ID_BROMLEY;
    return undef;
}

sub extra_contact_validation {
    my $self = shift;
    my $c = shift;

    my %errors;

    $c->stash->{dest} = $c->get_param('dest');

    if (!$c->get_param('dest')) {
        $errors{dest} = "Please enter who your message is for";
    } elsif ( $c->get_param('dest') eq 'council' || $c->get_param('dest') eq 'update' ) {
        $errors{not_for_us} = 1;
    }

    return %errors;
}

sub default_map_zoom {
    my $self = shift;

    # If we're displaying the map at the user's GPS location we
    # want to start a bit more zoomed in than if they'd entered
    # a postcode/address.
    return unless $self->{c}; # no c for batch job calling static_map
    return $self->{c}->get_param("geolocate") ? 4 : undef;
}


=head2 council_dashboard_hook

This is for council-specific dashboard pages, which can only be seen by
superusers and logged-in users with an email domain matching a body name.

=cut

sub council_dashboard_hook {
    my $self = shift;
    my $c = $self->{c};

    unless ( $c->user_exists ) {
        $c->res->redirect('/about/council-dashboard');
        $c->detach;
    }

    $c->forward('/admin/fetch_contacts');

    $c->detach('/reports/summary') if $c->user->is_superuser;

    my $body = $self->dashboard_body;
    if ($body) {
        # Matching URL and user's email body
        $c->detach('/reports/summary') if $body->id eq $c->stash->{body}->id;

        # Matched /a/ body, redirect to its summary page
        $c->stash->{body} = $body;
        $c->stash->{wards} = [ { name => 'summary' } ];
        $c->detach('/reports/redirect_body');
    }

    $c->res->redirect('/about/council-dashboard');
}

sub about_hook {
    my $self = shift;
    my $c = $self->{c};

    if ($c->stash->{template} eq 'about/council-dashboard.html') {
        $c->stash->{form_name} = $c->get_param('name') || '';
        $c->stash->{email} = $c->get_param('username') || '';
        if ($c->user_exists) {
            my $body = $self->dashboard_body;
            if ($body) {
                $c->stash->{body} = $body;
                $c->stash->{wards} = [ { name => 'summary' } ];
                $c->detach('/reports/redirect_body');
            }
        }
        if (my $email = $c->get_param('username')) {
            $email = lc $email;
            $email =~ s/\s+//g;
            my $body = $self->_email_to_body($email);
            if ($body) {
                # Send confirmation email (hopefully)
                $c->stash->{template} = 'auth/general.html';
                $c->detach('/auth/general', []);
            } else {
                $c->stash->{error} = 'bad_email';
            }
        }
    }
}

=item site_message

We want to show the reporting page site message from a UK cobrand if one
is relevant to the location we're currently at.

=cut

sub site_message {
    my $self = shift;
    my ($type) = @_;

    return unless $type && $type eq 'reporting';

    # Body list might come from /report/new or /around data
    my $c = $self->{c};
    my @bodies = do {
        if ($c->stash->{bodies_to_list}) {
            values %{$c->stash->{bodies_to_list}};
        } else {
            @{$c->stash->{around_bodies}};
        }
    };

    foreach my $body (@bodies) {
        my $cobrand = $body->get_cobrand_handler || next;
        my $msg = $cobrand->site_message($type);
        if ($msg) {
            $msg = "Message from " . $body->name . ": " . $msg;
            return FixMyStreet::Template::SafeString->new($msg);
        }
    }
}

sub per_body_config {
    my ($self, $feature, $problem) = @_;

    # This is a hash of council name to match, and what to do
    my $cfg = $self->feature($feature) || {};

    my $value;
    my $body = '';
    foreach (keys %$cfg) {
        if ($problem->to_body_named($_)) {
            $value = $cfg->{$_};
            $body = $_;
            last;
        }
    }
    return ($value, $body);
}

sub updates_disallowed {
    my $self = shift;
    my ($problem) = @_;
    my $c = $self->{c};

    # If closed due to problem/category closure, want that to take precedence
    my $parent = FixMyStreet::Cobrand::Default->updates_disallowed($problem);
    return $parent if $parent;

    my ($type, $body) = $self->per_body_config('updates_allowed', $problem);
    $type //= '';

    my $body_user = $c->user_exists && $c->user->from_body && $c->user->from_body->name =~ /$body/;
    return $self->_updates_disallowed_check($type, $problem, $body_user);
}

=head2 body_disallows_state_change

Determines whether state change is disallowed across the board.

=cut

sub body_disallows_state_change {
    my $self = shift;
    my ($problem) = @_;
    my $c = $self->{c};

    my ($disallowed, $body) = $self->per_body_config('update_states_disallowed', $problem);
    $disallowed //= 0;
    return $disallowed;
}

sub problem_state_processed {
    my ($self, $comment) = @_;

    my $state = $comment->problem_state || '';
    my $code = $comment->get_extra_metadata('external_status_code') || '';

    my ($cfg) = $self->per_body_config('extra_state_mapping', $comment->problem);

    $state = ( $cfg->{$state}->{$code} || $state ) if $cfg->{$state};

    return $state;
}

sub suppress_reporter_alerts {
    my $self = shift;
    my $c = $self->{c};
    my $problem = $c->stash->{report};
    if ($problem->to_body_named('Westminster')) {
        return 1;
    }
    return 0;
}

sub must_have_2fa {
    my ($self, $user) = @_;
    return 1 if $user->is_superuser && !FixMyStreet->staging_flag('skip_must_have_2fa');
    return 1 if $user->from_body && $user->from_body->name eq 'TfL';
    return 0;
}

sub send_questionnaire {
    my ($self, $problem) = @_;
    my ($send, $body) = $self->per_body_config('send_questionnaire', $problem);
    return $send // 1;
}

sub update_email_shortlisted_user {
    my ($self, $update) = @_;
    FixMyStreet::Cobrand::TfL::update_email_shortlisted_user($self, $update);
    FixMyStreet::Cobrand::Hackney::update_email_shortlisted_user($self, $update);
}

sub manifest {
    return {
        related_applications => [
            { platform => 'play', url => 'https://play.google.com/store/apps/details?id=org.mysociety.FixMyStreet', id => 'org.mysociety.FixMyStreet' },
            { platform => 'itunes', url => 'https://apps.apple.com/gb/app/fixmystreet/id297456545', id => 'id297456545' },
        ],
    };
}

sub report_new_munge_before_insert {
    my ($self, $report) = @_;

    # Make sure TfL reports are marked safety critical
    $self->SUPER::report_new_munge_before_insert($report);

    FixMyStreet::Cobrand::Buckinghamshire::report_new_munge_before_insert($self, $report);
    FixMyStreet::Cobrand::Merton::report_new_munge_before_insert($self, $report);
}

sub report_new_munge_after_insert {
    my ($self, $report) = @_;
    $self->SUPER::report_new_munge_after_insert($report);
}

sub munge_contacts_to_bodies {
    my ($self, $contacts, $report) = @_;

    my %bodies = map { $_->body->name => 1 } @$contacts;

    if ($bodies{'Buckinghamshire Council'}) {
        # Make sure Bucks grass cutting reports are routed correctly
        my $bucks = FixMyStreet::Cobrand::Buckinghamshire->new;
        $bucks->munge_contacts_to_bodies($contacts, $report);
    }
}

sub get_body_handler_for_problem {
    my ($self, $row) = @_;

    # Have a parish handled by Buckinghamshire to use its
    # report_sent_confirmation_email
    my $bucks = FixMyStreet::Cobrand::Buckinghamshire->new;
    my @parishes = $bucks->parish_bodies->all;
    my @parish_ids = map { $_->id } @parishes;

    # Have Kingston/Sutton made FMS reports not use the cobrand as its handler
    my $kingston = FixMyStreet::Cobrand::Kingston->new->body;
    my $sutton = FixMyStreet::Cobrand::Sutton->new->body;
    $kingston = $kingston ? $kingston->id : 0;
    $sutton = $sutton ? $sutton->id : 0;

    foreach my $body_id (@{$row->bodies_str_ids}) {
        if (grep { $body_id == $_ } @parish_ids) {
            # Report is to a Bucks parish
            return $bucks;
        }
        if ($body_id == $kingston || $body_id == $sutton) {
            return ref $self ? $self : $self->new;
        }
    }

    return $self->next::method($row);
}

around 'munge_sendreport_params' => sub {
    my ($orig, $self, $row, $h, $params) = @_;

    my $to = $params->{To}->[0]->[0];
    if ($to !~ /(cumbria|northamptonshire|nyorks|somerset)$/) {
        return $self->$orig($row, $h, $params);
    }

    # The district areas won't exist in MapIt at some point, so look up what
    # district this report would have been in and temporarily override the
    # areas column so BoroughEmails::munge_sendreport_params can do its thing.
    my ($lat, $lon) = ($row->latitude, $row->longitude);
    my $district = FixMyStreet::MapIt::call( 'point', "4326/$lon,$lat", type => 'DIS', generation => 36 );
    ($district) = keys %$district;

    my $original_areas = $row->areas;
    $row->areas(",$district,");

    $self->$orig($row, $h, $params);

    $row->areas($original_areas);
};

sub reopening_disallowed {
    my ($self, $problem) = @_;
    my $c = $self->{c};
    return 1 if $problem->to_body_named("Southwark") && $c->user_exists && (!$c->user->from_body || $c->user->from_body->name ne "Southwark Council");
    return 1 if $problem->to_body_named("Merton") && $c->user_exists && (!$c->user->from_body || $c->user->from_body->name ne "Merton Council");
    return 1 if $problem->to_body_named("Northumberland") && $c->user_exists && (!$c->user->from_body || $c->user->from_body->name ne "Northumberland County Council");
    return $self->next::method($problem);
}

# Make sure CPC areas are included in point lookups for new reports
# This is so that parish bodies (e.g. in Buckinghamshire) are available
# for reporting to on .com
sub add_extra_area_types {
    my ($self, $types) = @_;

    my @types = (
        @$types,
        'CPC',
    );
    return \@types;
}

sub user_survey_information {
    my $self = shift;
    my $c = $self->{c};

    my $q = $c->stash->{questionnaire};
    my $p = $q->problem;

    my $count = FixMyStreet::DB->resultset("Problem")->search({ user_id => $p->user_id })->count;
    my $by_user = do {
        if ($count > 100) { '101+' }
        elsif ($count > 50) { '51-100' }
        elsif ($count > 20) { '21-50' }
        elsif ($count > 10) { '11-20' }
        elsif ($count > 5) { '6-10' }
        elsif ($count > 1) { '2-5' }
        else { '1' }
    };

    my $imd = get('https://tilma.mysociety.org/lsoa_to_decile.php?lat=' . $p->latitude . '&lon=' . $p->longitude);
    $imd = try {
        decode_json($imd);
    };

    my $uri = URI->new;
    $uri->query_form(
        ever_reported => $q->ever_reported,
        been_fixed => $c->stash->{been_fixed},
        category => $p->category,
        num_reports_by_user => $by_user,
        imd_decile => $imd->{UK_IMD_E_pop_decile},
        cobrand => $p->cobrand,
    );
    return $uri->query;
}

1;
