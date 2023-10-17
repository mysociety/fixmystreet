package FixMyStreet::Cobrand::UKCouncils;
use parent 'FixMyStreet::Cobrand::UK';

use Moo;
use Carp;
use List::Util qw(min max);
use URI::Escape;
use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;
use XML::Simple;
use FixMyStreet::Template;

sub is_council {
    1;
}

sub suggest_duplicates {
    my $self = shift;
    return $self->feature('suggest_duplicates');
}

sub sms_authentication { shift->feature('sms_authentication') }

sub roadworks_categories { encode_json(shift->feature('roadworks_categories') || []) }

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker ),
        FixMyStreet->path_to( 'templates/web/fixmystreet-uk-councils' ),
    ];
}

sub path_to_email_templates {
    my ( $self, $lang_code ) = @_;
    my $paths = [
        FixMyStreet->path_to( 'templates', 'email', $self->moniker, $lang_code ),
        FixMyStreet->path_to( 'templates', 'email', $self->moniker ),
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet-uk-councils' ),
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com'),
    ];
    return $paths;
}

sub site_key {
    my $self = shift;
    return $self->council_url;
}

sub restriction {
    return { cobrand => shift->moniker };
}

sub cut_off_date { '' }

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');

    my $bodies = $self->body;
    if ($self->can('problems_restriction_bodies')) {
        $bodies = $self->problems_restriction_bodies;
    }
    $rs = $rs->to_body($bodies);

    if (my $date = $self->cut_off_date) {
        my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
        $rs = $rs->search({
            "$table.confirmed" => { '>=', $date }
        });
    }
    return $rs;
}

sub problems_sql_restriction {
    my ($self, $item_table) = @_;
    my $q = '';
    if (!$self->is_two_tier && $item_table ne 'comment') {
        my $body_id = $self->body->id;
        $q .= "AND regexp_split_to_array(bodies_str, ',') && ARRAY['$body_id']";
    }
    if (my $date = $self->cut_off_date) {
        $q .= " AND confirmed >= '$date'";
    }
    return $q;
}

sub problems_on_map_restriction {
    my ($self, $rs) = @_;
    # If we're a two-tier council show all problems on the map and not just
    # those for this cobrand's council to reduce duplicate reports.
    return $self->is_two_tier ? $rs : $self->problems_restriction($rs);
}

sub updates_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    return $rs->to_body($self->body);
}

sub users_restriction {
    my ($self, $rs) = @_;

    # Council admins can only see users who are members of the same council,
    # have an email address in a specified domain, or users who have sent a
    # report or update to that council.

    my $problem_user_ids = $self->problems->search(
        undef,
        {
            columns => [ 'user_id' ],
            distinct => 1
        }
    )->as_query;
    my $update_user_ids = $self->updates->search(
        undef,
        {
            columns => [ 'user_id' ],
            distinct => 1
        }
    )->as_query;

    my $or_query = [
        from_body => $self->body->id,
        'me.id' => [ { -in => $problem_user_ids }, { -in => $update_user_ids } ],
    ];
    if ($self->can('admin_user_domain')) {
        my @domains = $self->admin_user_domain;
        @domains = map { { ilike => "%\@$_" } } @domains;
        @domains = [ @domains ] if @domains > 1;
        push @$or_query, email => @domains;
    }

    my $query = {
        is_superuser => 0,
        -or => $or_query
    };
    return $rs->search($query);
}

sub base_url {
    my $self = shift;

    my $base_url = $self->feature('base_url');
    return $base_url if $base_url;

    $base_url = FixMyStreet->config('BASE_URL');
    my $u = $self->council_url;
    if ( $base_url !~ /$u/ ) {
        $base_url =~ s{(https?://)(?!www\.)}{$1$u.}g;
        $base_url =~ s{(https?://)www\.}{$1$u.}g;
    }
    return $base_url;
}

sub example_places {
    my $self = shift;
    return $self->feature('example_places') || $self->next::method();
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a ' . $self->council_area . ' postcode, or street name and area';
}

sub area_check {
    my ( $self, $params, $context ) = @_;

    return 1 if FixMyStreet->staging_flag('skip_checks');

    my $councils = $params->{all_areas};

    return 1 if $self->responsible_for_areas($councils);

    return ( 0, $self->area_check_error_message($params, $context) );
}

=head2 responsible_for_areas

Tests to see if the cobrand is responsible for a location. This is done through
checking if it has the area set in council_area_id and also checking if the
coverage is limited only to an overlapping asset by testing the hook
report_is_on_cobrand_asset

=cut

sub responsible_for_areas {
    my ($self, $councils) = @_;

    if ($self->can('check_report_is_on_cobrand_asset')) {
        # This will need changing for two tier councils
        if (grep ($self->council_area_id->[0] == $_, keys %$councils)) {
            return 1;
        } elsif ($self->check_report_is_on_cobrand_asset) {
            return 1;
        } else {
            return 0;
        }
    } else {
        # The majority of cobrands only cover a single area, but e.g. Northamptonshire
        # covers multiple so we need to handle that situation.
        my $council_area_ids = $self->council_area_id;
        $council_area_ids = [ $council_area_ids ] unless ref $council_area_ids eq 'ARRAY';
        foreach (@$council_area_ids) {
            return 1 if defined $councils->{$_};
        }

        return 0;
    }
}

sub area_check_error_message {
    my ( $self, $params, $context ) = @_;

    my $url = 'https://www.fixmystreet.com/';
    if ($context eq 'alert') {
        $url .= 'alert';
    } else {
        $url .= 'around';
    }
    $url .= '?pc=' . URI::Escape::uri_escape( $self->{c}->get_param('pc') )
      if $self->{c}->get_param('pc');
    $url .= '?latitude=' . URI::Escape::uri_escape( $self->{c}->get_param('latitude') )
         .  '&amp;longitude=' . URI::Escape::uri_escape( $self->{c}->get_param('longitude') )
      if $self->{c}->get_param('latitude');
    return "That location is not covered by " . $self->council_name . ".
Please visit <a href=\"$url\">the main FixMyStreet site</a>.";
}

# All reports page only has the one council.
sub all_reports_single_body {
    my $self = shift;
    return { name => $self->council_name };
}

sub reports_body_check {
    my ( $self, $c, $code ) = @_;

    # Deal with Bexley/Greenwich name not starting with short name
    if ($code =~ /bexley|greenwich/i) {
        my $body = $c->model('DB::Body')->search( { name => { -like => "%$code%" } } )->single;
        $c->stash->{body} = $body;
        return $body;
    }

    # We want to make sure we're only on our page.
    my $council_name = $self->council_name;
    if (my $override = $self->all_reports_single_body) {
        $council_name = $override->{name};
    }
    unless ( $council_name =~ /^\Q$code\E/ ) {
        $c->res->redirect( 'https://www.fixmystreet.com' . $c->req->uri->path_query, 301 );
        $c->detach();
    }

    return;
}

sub recent_photos {
    my ( $self, $area, $num, $lat, $lon, $dist ) = @_;
    $num = 2 if $num == 3;
    return $self->problems->recent_photos({
        num => $num,
        point => [$lat, $lon, $dist]
    });
}

# Returns true if the cobrand owns the problem, i.e. it was sent to the body
# associated with this cobrand.
sub owns_problem {
    my ($self, $report) = @_;
    my @bodies;
    if (ref $report eq 'HASH') {
        return unless $report->{bodies_str};
        @bodies = split /,/, $report->{bodies_str};
        @bodies = FixMyStreet::DB->resultset('Body')->search({ id => \@bodies })->all;
    } else { # Object
        @bodies = values %{$report->bodies};
    }

    foreach (@bodies) {
        return 1 if $_->get_extra_metadata('cobrand', '') eq $self->moniker;
    }
}

# If the council is two-tier, or e.g. TfL reports,
# then show pins for the other council as grey
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if !$self->owns_problem( $p );
    return $self->next::method($p, $context);
}

# If we ever link to a county problem report, or a TfL report,
# needs to be to main FixMyStreet
sub base_url_for_report {
    my ( $self, $report ) = @_;
    if ( $self->owns_problem( $report ) ) {
        return $self->base_url;
    } else {
        return FixMyStreet->config('BASE_URL');
    }
}

sub relative_url_for_report {
    my ( $self, $report ) = @_;
    return "" if $self->owns_problem($report);
    return FixMyStreet::Cobrand::TfL->base_url if $report->cobrand eq 'tfl';
    return FixMyStreet->config('BASE_URL');
}

sub problem_state_processed {
    my ($self, $comment) = @_;

    my $state = $comment->problem_state || '';
    my $code = $comment->get_extra_metadata('external_status_code') || '';

    my $cfg = $self->feature('extra_state_mapping');

    $state = ( $cfg->{$state}->{$code} || $state ) if $cfg->{$state};

    return $state;
}

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
    return undef unless defined $user->from_body;
    # Make sure TfL staff can't access other London cobrand admins
    return undef if $user->from_body->name eq 'TfL';
    return $user->from_body->get_extra_metadata('cobrand', '') eq $self->moniker;
}

sub admin_show_creation_graph { 0 }

sub available_permissions {
    my $self = shift;

    my $perms = $self->next::method();
    $perms->{Problems}->{default_to_body} = "Default to creating reports/updates as " . $self->council_name;
    $perms->{Problems}->{contribute_as_body} = "Create reports/updates as " . $self->council_name;
    $perms->{Problems}->{view_body_contribute_details} = "See user detail for reports created as " . $self->council_name;
    $perms->{Users}->{user_assign_areas} = "Assign users to areas in " . $self->council_name;

    my $features = $self->feature('waste_features') || {};
    if ( $features->{admin_config_enabled} ) {
        $perms->{Waste}->{wasteworks_config} = "Can edit WasteWorks configuration";
    }

    return $perms;
}

sub prefill_report_fields_for_inspector { 1 }

sub social_auth_disabled { 1 }

# By default for UK councils, we send confirmation emails
# only for Waste reports
sub report_sent_confirmation_email {
    my ($self, $report) = @_;
    return 'Report ID if WasteWorks report' unless $report; # no report passed when called from /admin/config template
    my $contact = $report->contact or return;
    return 'id' if $report->contact->get_extra_metadata('type', '') eq 'waste';
    return '';
}

sub munge_around_category_where {
    my ($self, $where) = @_;
    $where->{'-or'} = [
        extra => undef,
        -not => { extra => { '@>' => '{"type":"waste"}' } }
    ];
}

sub munge_reports_category_list {
    my ($self, $categories) = @_;
    my $c = $self->{c};
    return if $c->action eq 'dashboard/heatmap';

    unless ( $c->user_exists && $c->user->from_body && $c->user->has_permission_to('report_mark_private', $self->body->id) ) {
        @$categories = grep { $_->get_extra_metadata('type', '') ne 'waste' } @$categories;
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

    # Environment agency added with odour category for FixmyStreet
    # in all England areas, but should not show for cobrands
    if ( $bodies{'Environment Agency'} ) {
        %$bodies = map { $_->id => $_ } grep { $_->name ne 'Environment Agency' } values %$bodies;
    }

    if ( $bodies{'Thamesmead'} ) {
        my $thamesmead = FixMyStreet::Cobrand::Thamesmead->new({ c => $self->{c} });
        $thamesmead->munge_thamesmead_body($bodies);
    }

    if ( $bodies{'Bristol City Council'} ) {
        my $bristol = FixMyStreet::Cobrand::Bristol->new({ c => $self->{c} });
        $bristol->munge_overlapping_asset_bodies($bodies);
    }
}

sub munge_report_new_contacts {
    my ($self, $contacts) = @_;

    if ($self->{c}->action =~ /^waste/) {
        @$contacts = grep { $_->get_extra_metadata('type', '') eq 'waste' } @$contacts;
        return;
    }

    if ($self->{c}->stash->{categories_for_point}) {
        # Have come from an admin tool
    } else {
        @$contacts = grep { !$_->get_extra_metadata('type') } @$contacts;
    }

    my %bodies = map { $_->body->name => $_->body } @$contacts;
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
}

=item wasteworks_config

Returns any database-stored WasteWorks configuration.

=cut

has wasteworks_config => (
    is => 'lazy',
    default => sub { $_[0]->body->get_extra_metadata( 'wasteworks_config', {} ) },
);

sub open311_extra_data {
    my $self = shift;
    my $include = $self->call_hook(open311_extra_data_include => @_);
    my $exclude = $self->call_hook(open311_extra_data_exclude => @_);
    push @$exclude, 'sect_label', 'road_name', 'area_name';
    return ($include, $exclude);
};

=head2 lookup_site_code

Reports made via FMS.com or the app probably won't have a site code
value (required for Confirm integrations) because we don't display
the adopted highways layer on those frontends.
Instead we'll look up the closest asset from the WFS
service at the point we're sending the report over Open311.

NB this requires the cobrand to implement `lookup_site_code_config` -
see Buckinghamshire or Lincolnshire for an example.

Assumes all coordinates are in eastings/northings (EPSG 27700), unless the
_nearest_uses_latlon config key is set by lookup_site_code_config, in which
case lat/lons (EPSG 4326) are used. Useful if the assets are served by e.g.
Alloy, not Confirm.


=cut

sub lookup_site_code {
    my $self = shift;
    my $row = shift;
    my $field = shift;

    my $cfg = $self->lookup_site_code_config($field);
    my ($x, $y) = $row->local_coords;

    my $features = $self->_fetch_features($cfg, $x, $y);
    if ($cfg->{_nearest_uses_latlon}) {
        ($x, $y) = ($row->longitude, $row->latitude);
    }
    return $self->_nearest_feature($cfg, $x, $y, $features);
}

sub _fetch_features {
    my ($self, $cfg, $x, $y, $xml) = @_;

    # default to a buffered bounding box around the given point unless
    # a custom filter parameter has been specified.
    unless ( $cfg->{filter} ) {
        my $buffer = $cfg->{buffer};
        my ($w, $s, $e, $n) = ($x-$buffer, $y-$buffer, $x+$buffer, $y+$buffer);
        $cfg->{bbox} = "$w,$s,$e,$n";
    }

    my $uri = $self->_fetch_features_url($cfg);
    my $response = get($uri) or return;
    if (!$xml) {
        my $j = JSON->new->utf8->allow_nonref;
        try {
            $j = $j->decode($response);
        } catch {
            # There was either no asset found, or an error with the WFS
            # call - in either case let's just proceed without the USRN.
            return;
        };
        return $j->{features};
    } else {
        my $x = XML::Simple->new(
            ForceArray => [ 'gml:featureMember' ],
            KeyAttr => {},
            SuppressEmpty => undef,
        );
        try {
            $x = $x->parse_string($response);
        } catch {
            # There was either no asset found, or an error with the WFS
            # call - in either case we'll respond with no asset found
            return;
        };
        return $x->{'gml:featureMember'};
    }
}

sub _fetch_features_url {
    my ($self, $cfg) = @_;

    my $uri = URI->new($cfg->{url});
    $uri->query_form(
        REQUEST => "GetFeature",
        SERVICE => "WFS",
        SRSNAME => $cfg->{srsname},
        TYPENAME => $cfg->{typename},
        VERSION => "1.1.0",
        outputformat => $cfg->{outputformat} || "geojson",
        $cfg->{filter} ? ( Filter => $cfg->{filter} ) : ( BBOX => $cfg->{bbox} ),
    );

    return $uri;
}


sub _nearest_feature {
    my ($self, $cfg, $x, $y, $features) = @_;

    # We have a list of features, and we want to find the one closest to the
    # report location.
    my $chosen = '';
    my $nearest;

    # We shouldn't receive anything aside from these geometry types, but belt and braces.
    my $accept_types = $cfg->{accept_types} || {
        LineString => 1,
        MultiLineString => 1
    };

    for my $feature ( @{$features || []} ) {
        next unless $cfg->{accept_feature}($feature);
        next unless $accept_types->{$feature->{geometry}->{type}};

        my @linestrings = @{ $feature->{geometry}->{coordinates} };
        if ( $feature->{geometry}->{type} eq 'LineString' ) {
            @linestrings = ([ @linestrings ]);
        }
        # If it is a point, upgrade it to a one-segment zero-length
        # MultiLineString so it can be compared by the distance function.
        if ( $feature->{geometry}->{type} eq 'Point') {
            @linestrings = ([ [ @linestrings ], [ @linestrings ] ]);
        }

        foreach my $coordinates (@linestrings) {
            for (my $i=0; $i<@$coordinates-1; $i++) {
                my $distance = $self->_distanceToLine($x, $y, $coordinates->[$i], $coordinates->[$i+1]);
                if ( !defined $nearest || $distance < $nearest ) {
                    $chosen = $feature;
                    $nearest = $distance;
                }
            }
        }
    }

    return $cfg->{property} && $chosen ? $chosen->{properties}->{$cfg->{property}} : $chosen;
}

sub contact_name {
    my $self = shift;
    return $self->feature('contact_name') || $self->next::method();
}

sub contact_email {
    my $self = shift;
    return $self->feature('contact_email') || $self->next::method();
}

sub do_not_reply_email {
    my $self = shift;
    return $self->feature('do_not_reply_email') || $self->next::method();
}

sub verp_email_domain {
    my $self = shift;
    return $self->feature('verp_email_domain');
}

sub extra_contact_validation {
    my $self = shift;
    my $c = shift;

    # Don't care about dest unless reporting abuse
    return () unless $c->stash->{problem};

    my %errors;

    $c->stash->{dest} = $c->get_param('dest');

    if (!$c->get_param('dest')) {
        $errors{dest} = "Please enter a topic of your message";
    } elsif ( $c->get_param('dest') eq 'council' || $c->get_param('dest') eq 'update' ) {
        $errors{not_for_us} = 1;
    }

    return %errors;
}


=head2 _distanceToLine

Returns the cartesian distance of a point from a line.
This is not a general-purpose distance function, it's intended for use with
fairly nearby coordinates in EPSG:27700 where a spheroid doesn't need to be
taken into account.

=cut

sub _distanceToLine {
    my ($self, $x, $y, $start, $end) = @_;
    my $dx = $end->[0] - $start->[0];
    my $dy = $end->[1] - $start->[1];
    my $along = ($dx == 0 && $dy == 0) ? 0 : (($dx * ($x - $start->[0])) + ($dy * ($y - $start->[1]))) / ($dx**2 + $dy**2);
    $along = max(0, min(1, $along));
    my $fx = $start->[0] + $along * $dx;
    my $fy = $start->[1] + $along * $dy;
    return sqrt( (($x - $fx) ** 2) + (($y - $fy) ** 2) );
}

# Do a manual prefetch of all staff users for contributed_by lookup
sub csv_staff_users {
    my $self = shift;

    my @user_ids = FixMyStreet::DB->resultset('User')->search(
        { from_body => $self->body->id },
        { columns => [ 'id', 'email' ] })->all;

    my %user_lookup = map { $_->id => $_->email } @user_ids;
    return \%user_lookup;
}

sub csv_staff_user_lookup {
    my ($self, $contributed_by, $user_lookup) = @_;
    return '' unless $contributed_by;
    return $user_lookup->{$contributed_by} //= do {
        my $user = FixMyStreet::DB->resultset('User')->find({ id => $contributed_by });
        $user ? $user->email : '';
    };
}

sub csv_staff_roles {
    my ($self, $user_lookup) = @_;

    my $userroles = FixMyStreet::DB->resultset("UserRole")->search({
        user_id => [ keys %$user_lookup ],
    }, {
        prefetch => 'role'
    });
    my %userroles;
    while (my $userrole = $userroles->next) {
        my $user_id = $userrole->user_id;
        my $role = $userrole->role->name;
        push @{$userroles{$user_id}}, $role;
    }
    return \%userroles;
}

sub nearby_distances {
    my $self = shift;
    return $self->feature('nearby_distances') || $self->next::method();
}

=head2 _post_report_sent_close

Helper function to mark a report as closed when it's sent, including an update.

=cut

sub _post_report_sent_close {
    my ($self, $problem, $template) = @_;

    my @include_path = @{ $self->path_to_web_templates };
    push @include_path, FixMyStreet->path_to( 'templates', 'web', 'default' );
    my $tt = FixMyStreet::Template->new({
        INCLUDE_PATH => \@include_path,
        disable_autoescape => 1,
    });
    my $text;
    $tt->process($template, {}, \$text);

    $problem->update({
        state => 'closed'
    });
    $problem->add_to_comments({
        text => $text,
        user_id => $self->body->comment_user_id,
        problem_state => 'closed',
        cobrand => $problem->cobrand,
        send_state => 'processed',
    });
}

1;
