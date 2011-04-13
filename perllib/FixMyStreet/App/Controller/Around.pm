package FixMyStreet::App::Controller::Around;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::Map;
use List::MoreUtils qw(any);
use Encode;

=head1 NAME

FixMyStreet::App::Controller::Around - Catalyst Controller

=head1 DESCRIPTION

Allow the user to search for reports around a particular location.

=head1 METHODS

=head2 around

Find the location search and display nearby reports (for pc or lat,lon).

For x,y searches convert to lat,lon and 301 redirect to them.

If no search redirect back to the homepage.

=cut

sub around_index : Path : Args(0) {
    my ( $self, $c ) = @_;

    # check for x,y requests and redirect them to lat,lon
    my $x = $c->req->param('x');
    my $y = $c->req->param('y');
    if ( $x || $y ) {
        my ( $lat, $lon ) = FixMyStreet::Map::tile_xy_to_wgs84( $x, $y );
        my $ll_uri = $c->uri_for( '/around', { lat => $lat, lon => $lon } );
        $c->res->redirect( $ll_uri, 301 );
        return;
    }

    # Try to create a location for whatever we have
    return
      unless $c->forward('determine_location_from_coords')
          || $c->forward('determine_location_from_pc');

    # Check to see if the spot is covered by a council - if not show an error.
    return unless $c->forward('check_location_is_acceptable');

    # If we have a partial - redirect to /report/new so that it can be
    # completed.
    warn "FIXME - implement";

    # Show the nearby reports
    $c->forward('display_location');

}

=head2 display_location

Display a specific lat/lng location (which may have come from a pc search).

=cut

sub display_location : Private {
    my ( $self, $c ) = @_;

#     # Deal with pin hiding/age
#     my ( $hide_link, $hide_text, $all_link, $all_text, $interval );
#     if ( $input{all_pins} ) {
#         $all_link =
#           NewURL( $q, -retain => 1, no_pins => undef, all_pins => undef );
#         $all_text = _('Hide stale reports');
#     }
#     else {
#         $all_link = NewURL( $q, -retain => 1, no_pins => undef, all_pins => 1 );
#         $all_text = _('Include stale reports');
#         $interval = '6 months';
#     }

#     my ( $on_map_all, $on_map, $around_map, $dist ) =
#       FixMyStreet::Map::map_features( $q, $latitude, $longitude, $interval );
#     my @pins;
#     foreach (@$on_map_all) {
#         push @pins,
#           [
#             $_->{latitude}, $_->{longitude},
#             ( $_->{state} eq 'fixed' ? 'green' : 'red' ), $_->{id}
#           ];
#     }
#     my $on_list = '';
#     foreach (@$on_map) {
#         my $report_url = NewURL( $q, -url => '/report/' . $_->{id} );
#         $report_url = Cobrand::url( $cobrand, $report_url, $q );
#         $on_list .= '<li><a href="' . $report_url . '">';
#         $on_list .= ent( $_->{title} ) . '</a> <small>(';
#         $on_list .= Page::prettify_epoch( $q, $_->{time}, 1 ) . ')</small>';
#         $on_list .= ' <small>' . _('(fixed)') . '</small>'
#           if $_->{state} eq 'fixed';
#         $on_list .= '</li>';
#     }
#     $on_list = $q->li( _('No problems have been reported yet.') )
#       unless $on_list;
#
#     my $around_list = '';
#     foreach (@$around_map) {
#         my $report_url =
#           Cobrand::url( $cobrand, NewURL( $q, -url => '/report/' . $_->{id} ),
#             $q );
#         $around_list .= '<li><a href="' . $report_url . '">';
#         my $dist = int( $_->{distance} * 10 + 0.5 );
#         $dist = $dist / 10;
#         $around_list .= ent( $_->{title} ) . '</a> <small>(';
#         $around_list .= Page::prettify_epoch( $q, $_->{time}, 1 ) . ', ';
#         $around_list .= $dist . 'km)</small>';
#         $around_list .= ' <small>' . _('(fixed)') . '</small>'
#           if $_->{state} eq 'fixed';
#         $around_list .= '</li>';
#         push @pins,
#           [
#             $_->{latitude}, $_->{longitude},
#             ( $_->{state} eq 'fixed' ? 'green' : 'red' ), $_->{id}
#           ];
#     }
#     $around_list = $q->li( _('No problems found.') )
#       unless $around_list;

#     if ( $input{no_pins} ) {
#         $hide_link = NewURL( $q, -retain => 1, no_pins => undef );
#         $hide_text = _('Show pins');
#         @pins      = ();
#     }
#     else {
#         $hide_link = NewURL( $q, -retain => 1, no_pins => 1 );
#         $hide_text = _('Hide pins');
#     }

#     my $map_links =
# "<p id='sub_map_links'><a id='hide_pins_link' rel='nofollow' href='$hide_link'>$hide_text</a>";
#     if ( mySociety::Config::get('COUNTRY') eq 'GB' ) {
#         $map_links .=
# " | <a id='all_pins_link' rel='nofollow' href='$all_link'>$all_text</a></p> <input type='hidden' id='all_pins' name='all_pins' value='$input_h{all_pins}'>";
#     }
#     else {
#         $map_links .= "</p>";
#     }

#     # truncate the lat,lon for nicer rss urls, and strings for outputting
#     my ( $short_lat, $short_lon ) =
#       map { Utils::truncate_coordinate($_) }    #
#       ( $latitude, $longitude );
#
#     my $url_skip = NewURL(
#         $q,
#         -url       => '/report/new',
#         -retain    => 1,
#         x          => undef,
#         y          => undef,
#         latitude   => $short_lat,
#         longitude  => $short_lon,
#         submit_map => 1,
#         skipped    => 1
#     );
#
#     my $pc_h = ent( $q->param('pc') || '' );
#
#     my $rss_url;
#     if ($pc_h) {
#         $rss_url = "/rss/pc/" . URI::Escape::uri_escape_utf8($pc_h);
#     }
#     else {
#         $rss_url = "/rss/l/$short_lat,$short_lon";
#     }
#     $rss_url = Cobrand::url( $cobrand, NewURL( $q, -url => $rss_url ), $q );
#
#     my %vars = (
#         'map' => FixMyStreet::Map::display_map(
#             $q,
#             latitude  => $short_lat,
#             longitude => $short_lon,
#             type      => 1,
#             pins      => \@pins,
#             post      => $map_links
#         ),
#         map_end   => FixMyStreet::Map::display_map_end(1),
#         url_home  => Cobrand::url( $cobrand, '/', $q ),
#         url_rss   => $rss_url,
#         url_email => Cobrand::url(
#             $cobrand,
#             NewURL(
#                 $q,
#                 lat  => $short_lat,
#                 lon  => $short_lon,
#                 -url => '/alert',
#                 feed => "local:$short_lat:$short_lon"
#             ),
#             $q
#         ),
#         url_skip          => $url_skip,
#         email_me          => _('Email me new local problems'),
#         rss_alt           => _('RSS feed'),
#         rss_title         => _('RSS feed of recent local problems'),
#         reports_on_around => $on_list,
#         reports_nearby    => $around_list,
#         heading_problems  => _('Problems in this area'),
#         heading_on_around => _('Reports on and around the map'),
#         heading_closest   => sprintf(
#             _('Closest nearby problems <small>(within&nbsp;%skm)</small>'),
#             $dist
#         ),
#         distance => $dist,
#         pc_h     => $pc_h,
#         errors   => @errors
#         ? '<ul class="error"><li>' . join( '</li><li>', @errors ) . '</li></ul>'
#         : '',
#         text_to_report => _(
#             'To report a problem, simply
#             <strong>click on the map</strong> at the correct location.'
#         ),
#         text_skip => sprintf(
#             _(
# "<small>If you cannot see the map, <a href='%s' rel='nofollow'>skip this
#             step</a>.</small>"
#             ),
#             $url_skip
#         ),
#     );
#
#     my %params = (
#         rss    => [ _('Recent local problems, FixMyStreet'), $rss_url ],
#         js     => FixMyStreet::Map::header_js(),
#         robots => 'noindex,nofollow',
#     );
#
#     return (
#         Page::template_include( 'map', $q, Page::template_root($q), %vars ),
#         %params );
}

=head2 determine_location_from_coords

Use latitude and longitude if provided in parameters.

=cut 

sub determine_location_from_coords : Private {
    my ( $self, $c ) = @_;

    my $latitude  = $c->req->param('latitude');
    my $longitude = $c->req->param('longitude');

    if ( defined $latitude && defined $longitude ) {
        $c->stash->{latitude}  = $latitude;
        $c->stash->{longitude} = $longitude;

        # Also save the pc if there is one
        if ( my $pc = $c->req->param('pc') ) {
            $c->stash->{pc} = $pc;
        }

        return 1;
    }

    return;
}

=head2 determine_location_from_pc

User has searched for a location - try to find it for them.

If one match is found returns true and lat/lng is set.

If several possible matches are found puts an array onto stash so that user can be prompted to pick one and returns false.

If no matches are found returns false.

=cut 

sub determine_location_from_pc : Private {
    my ( $self, $c ) = @_;

    # check for something to search
    my $pc = $c->req->param('pc') || return;
    $c->stash->{pc} = $pc;    # for template

    my ( $latitude, $longitude, $error ) =
      eval { FixMyStreet::Geocode::lookup( $pc, $c->req ) };

    # Check that nothing blew up
    if ($@) {
        warn "Error: $@";
        return;
    }

    # If we got a lat/lng set to stash and return true
    if ( defined $latitude && defined $longitude ) {
        $c->stash->{latitude}  = $latitude;
        $c->stash->{longitude} = $longitude;
        return 1;
    }

    # $error doubles up to return multiple choices by being an array
    if ( ref($error) eq 'ARRAY' ) {
        @$error = map {
            decode_utf8($_);
            s/, United Kingdom//;
            s/, UK//;
            $_;
        } @$error;
        $c->stash->{possible_location_matches} = $error;
        return;
    }

    # pass errors back to the template
    $c->stash->{pc_error} = $error;
    return;
}

=head2 check_location_is_acceptable

Find the lat and lon in stash and check that they are acceptable to the council,
and that they are in UK (if we are in UK).

=cut

sub check_location_is_acceptable : Private {
    my ( $self, $c ) = @_;

    # These should be set now
    my $lat = $c->stash->{latitude};
    my $lon = $c->stash->{longitude};

    # Check this location is okay to be displayed for the cobrand
    my ( $success, $error_msg ) = $c->cobrand->council_check(    #
        { lat => $lat, lon => $lon },
        'submit_problem'
    );

    # If in UK and we have a lat,lon coocdinate check it is in UK
    if ( !$error_msg && $lat && $c->config->{COUNTRY} eq 'GB' ) {
        eval { Utils::convert_latlon_to_en( $lat, $lon ); };
        $error_msg =
          _( "We had a problem with the supplied co-ordinates - outside the UK?"
          ) if $@;
    }

    # all good
    return 1 if !$error_msg;

    # show error
    $c->stash->{pc_error} = $error_msg;
    return;

}

__PACKAGE__->meta->make_immutable;

1;
