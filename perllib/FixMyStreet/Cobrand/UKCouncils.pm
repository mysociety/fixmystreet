package FixMyStreet::Cobrand::UKCouncils;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

use Carp;
use URI::Escape;
use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;

sub is_council {
    1;
}

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

# UK cobrands assume that each MapIt area ID maps both ways with one
# body. Except TfL.
sub body {
    my $self = shift;
    my $body = FixMyStreet::DB->resultset('Body')->for_areas($self->council_area_id)->search({ name => { '!=', 'TfL' } })->first;
    return $body;
}

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    return $rs->to_body($self->body);
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
        my $domain = $self->admin_user_domain;
        push @$or_query, email => { ilike => "%\@$domain" };
    }

    return $rs->search($or_query);
}

sub base_url {
    my $self = shift;
    my $base_url = FixMyStreet->config('BASE_URL');
    my $u = $self->council_url;
    if ( $base_url !~ /$u/ ) {
        $base_url =~ s{(https?://)(?!www\.)}{$1$u.}g;
        $base_url =~ s{(https?://)www\.}{$1$u.}g;
    }
    return $base_url;
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a ' . $self->council_area . ' postcode, or street name and area';
}

sub area_check {
    my ( $self, $params, $context ) = @_;

    return 1 if FixMyStreet->staging_flag('skip_checks');

    my $councils = $params->{all_areas};
    my $council_match = defined $councils->{$self->council_area_id};
    if ($council_match) {
        return 1;
    }
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
    my $error_msg = "That location is not covered by " . $self->council_name . ".
Please visit <a href=\"$url\">the main FixMyStreet site</a>.";
    return ( 0, $error_msg );
}

# All reports page only has the one council.
sub all_reports_single_body {
    my $self = shift;
    return { name => $self->council_name };
}

sub reports_body_check {
    my ( $self, $c, $code ) = @_;

    # We want to make sure we're only on our page.
    unless ( $self->council_name =~ /^\Q$code\E/ ) {
        $c->res->redirect( 'https://www.fixmystreet.com' . $c->req->uri->path_query, 301 );
        $c->detach();
    }

    return;
}

sub recent_photos {
    my ( $self, $area, $num, $lat, $lon, $dist ) = @_;
    $num = 2 if $num == 3;
    return $self->problems->recent_photos( $num, $lat, $lon, $dist );
}

# Returns true if the cobrand owns the problem.
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
    # Want to ignore the TfL body that covers London councils
    my %areas = map { %{$_->areas} } grep { $_->name ne 'TfL' } @bodies;
    return $areas{$self->council_area_id} ? 1 : undef;
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
    return $self->owns_problem($report) ? "" : FixMyStreet->config('BASE_URL');
}

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
    return undef unless defined $user->from_body;
    return $user->from_body->areas->{$self->council_area_id};
}

sub available_permissions {
    my $self = shift;

    my $perms = $self->next::method();
    $perms->{Problems}->{default_to_body} = "Default to creating reports/updates as " . $self->council_name;
    $perms->{Problems}->{contribute_as_body} = "Create reports/updates as " . $self->council_name;
    $perms->{Problems}->{view_body_contribute_details} = "See user detail for reports created as " . $self->council_name;
    $perms->{Users}->{user_assign_areas} = "Assign users to areas in " . $self->council_name;

    return $perms;
}

sub prefill_report_fields_for_inspector { 1 }

sub social_auth_disabled { 1 }

=head2 lookup_site_code

Reports made via FMS.com or the app probably won't have a site code
value (required for Confirm integrations) because we don't display
the adopted highways layer on those frontends.
Instead we'll look up the closest asset from the WFS
service at the point we're sending the report over Open311.

NB this requires the cobrand to implement `lookup_site_code_config` -
see Buckinghamshire or Lincolnshire for an example.


=cut

sub lookup_site_code {
    my $self = shift;
    my $row = shift;
    my $buffer = shift;

    my $cfg = $self->lookup_site_code_config;

    $buffer ||= $cfg->{buffer}; # metres
    my ($x, $y) = $row->local_coords;
    my ($w, $s, $e, $n) = ($x-$buffer, $y-$buffer, $x+$buffer, $y+$buffer);

    my $uri = URI->new($cfg->{url});
    $uri->query_form(
        REQUEST => "GetFeature",
        SERVICE => "WFS",
        SRSNAME => $cfg->{srsname},
        TYPENAME => $cfg->{typename},
        VERSION => "1.1.0",
        outputformat => "geojson",
        BBOX => "$w,$s,$e,$n"
    );

    my $response = get($uri);

    my $j = JSON->new->utf8->allow_nonref;
    try {
        $j = $j->decode($response);
    } catch {
        # There was either no asset found, or an error with the WFS
        # call - in either case let's just proceed without the USRN.
        return '';
    };

    # We have a list of features, and we want to find the one closest to the
    # report location.
    my $site_code = '';
    my $nearest;

    for my $feature ( @{ $j->{features} } ) {
        next unless $cfg->{accept_feature}($feature);

        # We shouldn't receive anything aside from these two geometry types, but belt and braces.
        next unless $feature->{geometry}->{type} eq 'MultiLineString' || $feature->{geometry}->{type} eq 'LineString';

        my @coordinates = @{ $feature->{geometry}->{coordinates} };
        if ( $feature->{geometry}->{type} eq 'MultiLineString') {
            # The coordinates are stored as a list of lists, so flatten 'em out
            @coordinates = map { @{ $_ } } @coordinates;
        }

        # If any of this feature's points are closer than those we've seen so
        # far then use the site_code from this feature.
        for my $coords ( @coordinates ) {
            my ($fx, $fy) = @$coords;
            my $distance = $self->_distance($x, $y, $fx, $fy);
            if ( !defined $nearest || $distance < $nearest ) {
                $site_code = $feature->{properties}->{$cfg->{property}};
                $nearest = $distance;
            }
        }
    }

    return $site_code;
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


=head2 _distance

Returns the cartesian distance between two coordinates.
This is not a general-purpose distance function, it's intended for use with
fairly nearby coordinates in EPSG:27700 where a spheroid doesn't need to be
taken into account.

=cut
sub _distance {
    my ($self, $ax, $ay, $bx, $by) = @_;
    return sqrt( (($ax - $bx) ** 2) + (($ay - $by) ** 2) );
}


1;
