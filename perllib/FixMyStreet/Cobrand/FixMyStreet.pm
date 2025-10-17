package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::UK';

use Moo;
use JSON::MaybeXS;
use List::Util qw(any);
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

    my $iow = grep { $_->get_column('name') eq 'Isle of Wight Council' } @{ $self->{c}->stash->{around_bodies} };
    if ($iow) {
        # display all the categories on Isle of Wight at the moment as there's no way to
        # do the expand bit later as we fetch it using ajax which uses a bounding box so
        # can't determine the body
        $where->{send_method} = [ { '!=' => 'Triage' }, undef ];
    }
    $where->{'-or'} = [
        extra => undef,
        -not => { extra => { '@>' => '{"type":"waste"}' } }
    ];
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

    my %bodies = map { $_->body->get_column('name') => $_->body } @$categories;
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

    my %bodies = map { $_->get_column('name') => 1 } values %$bodies;
    if ( $bodies{'TfL'} ) {
        # Presented categories vary if we're on/off a red route
        my $tfl = FixMyStreet::Cobrand::TfL->new({ c => $self->{c} });
        $tfl->munge_surrounding_london($bodies);
    }

    if ( $bodies{'National Highways'} || $bodies{'Traffic Scotland'} ) {
        # Traffic Scotland and National Highways have a combined layer
        my $c = $self->{c};
        my $he = FixMyStreet::Cobrand::HighwaysEngland->new({ c => $c });
        my $on_he_road = $c->stash->{on_he_road} = $he->report_new_is_on_he_road;

        my $highways_body_name = $bodies{'National Highways'} ? 'National Highways' : 'Traffic Scotland';
        if (!$on_he_road) {
            %$bodies = map { $_->id => $_ } grep { $_->get_column('name') ne $highways_body_name } values %$bodies;
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

    if ( $bodies{'Camden Borough Council'} ) {
        my $camden = FixMyStreet::Cobrand::Camden->new({ c => $self->{c} });
        $camden->munge_overlapping_asset_bodies($bodies);
    }

    if ( $bodies{'Lewisham Borough Council'} ) {
        my $bromley = FixMyStreet::Cobrand::Bromley->new({ c => $self->{c} });
        $bromley->munge_overlapping_asset_bodies($bodies);
    }

    if ( $bodies{'Merton Council'} ) {
        my $merton = FixMyStreet::Cobrand::Merton->new({ c => $self->{c} });
        $merton->munge_overlapping_asset_bodies($bodies);
    }
}

sub munge_report_new_contacts {
    my ($self, $contacts) = @_;

    # Ignore contacts with a special type (e.g. waste, noise, claim)
    @$contacts = grep { !$_->get_extra_metadata('type') } @$contacts;

    my %bodies = map { $_->body->get_column('name') => $_->body } @$contacts;

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

    if ( $bodies{'Traffic Scotland'} ) {
        my $nh = FixMyStreet::Cobrand::HighwaysEngland->new({ c => $self->{c} });
        $nh->munge_report_new_contacts($contacts, 'TS');
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
    my %bodies = map { $_->get_column('name') => 1 } values %$bodies;
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

    return ["MR", "MISS", "MRS", "MS", "DR", "PCSO", "PC", "N/A"] if $first_area->{id} eq COUNCIL_ID_BROMLEY;
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


    if ($problem->to_body_named('Bristol')) {
        return !($c->user_exists && $c->user->id == $problem->user->id);
    }

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
    my ($self, $problem) = @_;
    if ($problem->to_body_named('Westminster')) {
        return 1;
    }
    return 0;
}

sub must_have_2fa {
    my ($self, $user) = @_;
    return 1 if $user->is_superuser && !FixMyStreet->staging_flag('skip_must_have_2fa');
    return 1 if $user->from_body && $user->from_body->get_column('name') eq 'TfL';
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

    if ($report->to_body_named('Brent')) {
        my $brent = FixMyStreet::Cobrand->get_class_for_moniker('brent')->new();
        $brent->report_new_munge_before_insert($report);
    }
    FixMyStreet::Cobrand::Buckinghamshire::report_new_munge_before_insert($self, $report);
    FixMyStreet::Cobrand::Merton::report_new_munge_before_insert($self, $report);
}

sub report_new_munge_after_insert {
    my ($self, $report) = @_;
    $self->SUPER::report_new_munge_after_insert($report);
}

sub munge_contacts_to_bodies {
    my ($self, $contacts, $report) = @_;

    my %bodies = map { $_->body->get_column('name') => 1 } @$contacts;

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

    # Check if this is a Dott report made within Bristol
    # and change the destination email address if so.
    my @areas = split(",", $row->areas);
    my %ids = map { $_ => 1 } @areas;
    if ($row->category eq 'Abandoned Dott bike or scooter' && $ids{2561}) {
        my $cobrand = FixMyStreet::Cobrand::Bristol->new;
        if (my $email = $cobrand->feature("dott_email")) {
            $params->{To}->[0]->[0] = $email;
        }
    }

    my $to = $params->{To}->[0]->[0];

    # Special National Highways - due to NH exemption in UK's
    # get_body_handler_for_problem, we are here on .com NH reports
    if ($to =~ /\@nh$/) {
        my $cobrand = FixMyStreet::Cobrand::HighwaysEngland->new;
        return $cobrand->munge_sendreport_params($row, $h, $params);
    }

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
    my $cobrand = $problem->body_handler;
    return 1 if $cobrand && $cobrand ne $self && $cobrand->reopening_disallowed($problem);
    return $self->next::method($problem);
}

=head2 add_extra_areas_for_admin

Add the parish IDs from Buckinghamshire's cobrand, plus any other IDs from
configuration, so that we can manually add specific parish councils.

=cut

sub add_extra_areas_for_admin {
    my ($self, $areas) = @_;

    my $bucks = FixMyStreet::Cobrand::Buckinghamshire->new;
    my @extra = @{ $bucks->_parish_ids };
    my $extra = FixMyStreet::DB->resultset("Config")->get('extra_parishes') || [];
    push @extra, @$extra;
    my $ids_string = join ",", @extra;
    return $areas unless $ids_string;
    my $extra_areas = mySociety::MaPit::call('areas', [ $ids_string ]);
    my %all_areas = ( %$areas, %$extra_areas );
    return \%all_areas;
}

=head2 fetch_area_children

If we are looking at the All Reports page for one of the extra London (TfL)
bodies (the bike providers), we want the children to be the London councils,
not all the wards of London.

=cut

sub fetch_area_children {
    my $self = shift;
    my ($area_ids, $body, $all_generations) = @_;

    my $features = FixMyStreet->config('COBRAND_FEATURES') || {};
    my $bodies = $features->{categories_restriction_bodies} || {};
    $bodies = $bodies->{tfl} || [];
    if ($body && any { $_ eq $body->get_column('name') } @$bodies) {
        my $areas = FixMyStreet::MapIt::call('areas', 'LBO');
        foreach (keys %$areas) {
            $areas->{$_}->{name} =~ s/\s*(Borough|City|District|County) Council$//;
        }
        return $areas;
    } else {
        return $self->next::method(@_);
    }
}

# For staging demo purposes

sub open311_extra_data {
    my ($self, $row, $h) = @_;
    if (FixMyStreet->config('STAGING_SITE')) {
        my @bodies = values %{$row->bodies};
        if ($bodies[0]->jurisdiction eq 'alloy_demo') {
            my $include = [
                { name => 'report_url',
                  value => $h->{url} },
                { name => 'title',
                  value => $row->title },
                { name => 'description',
                  value => $row->detail },
                { name => 'category',
                  value => $row->category },
                { name => 'group',
                  value => $row->get_extra_metadata('group', '') },
            ];
            return ($include);
        }
    }
};

1;
