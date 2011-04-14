package FixMyStreet::App::Controller::Around;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::Map;
use List::MoreUtils qw(any);
use Encode;
use FixMyStreet::Map;

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

    # Check if we have a partial report
    my $partial_report = $c->forward('load_partial');

    # Try to create a location for whatever we have
    return
      unless $c->forward('determine_location_from_coords')
          || $c->forward('determine_location_from_pc');

    # Check to see if the spot is covered by a council - if not show an error.
    return unless $c->forward('check_location_is_acceptable');

    # If we have a partial - redirect to /report/new so that it can be
    # completed.
    if ($partial_report) {
        my $new_uri = $c->uri_for(
            '/report/new',
            {
                partial   => $c->stash->{partial_token}->token,
                latitude  => $c->stash->{latitude},
                longitude => $c->stash->{longitude},
                pc        => $c->stash->{pc},
            }
        );
        return $c->res->redirect($new_uri);
    }

    # Show the nearby reports
    $c->detach('display_location');
}

=head2 load_partial

    my $partial_report = $c->forward('load_partial');

Check for the partial token and load the partial report. If found save it and
token to stash and return report. Otherwise return false.

=cut

sub load_partial : Private {
    my ( $self, $c ) = @_;

    my $partial = scalar $c->req->param('partial')
      || return;

    # is it in the database
    my $token =
      $c->model("DB::Token")
      ->find( { scope => 'partial', token => $partial } )    #
      || last;

    # can we get an id from it?
    my $report_id = $token->data                             #
      || last;

    # load the related problem
    my $report = $c->model("DB::Problem")                    #
      ->search( { id => $report_id, state => 'partial' } )   #
      ->first
      || last;

    # save what we found on the stash.
    $c->stash->{partial_token}  = $token;
    $c->stash->{partial_report} = $report;

    return $report;
}

=head2 display_location

Display a specific lat/lng location (which may have come from a pc search).

=cut

sub display_location : Private {
    my ( $self, $c ) = @_;

    # set the template to use
    $c->stash->{template} = 'around/display_location.html';

    # get the lat,lng
    my $latitude  = $c->stash->{latitude};
    my $longitude = $c->stash->{longitude};

    # truncate the lat,lon for nicer rss urls, and strings for outputting
    my $short_latitude  = Utils::truncate_coordinate($latitude);
    my $short_longitude = Utils::truncate_coordinate($longitude);
    $c->stash->{short_latitude}  = $short_latitude;
    $c->stash->{short_longitude} = $short_longitude;

    # Deal with pin hiding/age
    my $all_pins = $c->req->param('all_pins') ? 1 : undef;
    $c->stash->{all_pins} = $all_pins;

    # Setup some bits of text
    my $all_link = $c->req->uri_with( { no_pins => undef, all_pins => undef } );
    my $all_text =
      $all_pins ? _('Hide stale reports') : _('Include stale reports');
    my $interval = $all_pins ? undef : $c->cobrand->on_map_default_max_pin_age;

    # get the map features
    my ( $on_map_all, $on_map, $around_map, $distance ) =
      FixMyStreet::Map::map_features( $c->req, $latitude, $longitude,
        $interval );

    # copy the found reports to the stash
    $c->stash->{on_map}     = $on_map;
    $c->stash->{around_map} = $around_map;
    $c->stash->{distance}   = $distance;

    # create a list of all the pins
    my @pins = map {
        my $pin_colour = $_->{state} eq 'fixed' ? 'green' : 'red';
        [ $_->{latitude}, $_->{longitude}, $pin_colour, $_->{id} ];
    } @$on_map_all, @$around_map;

    {    # FIXME - ideally this indented code should be in the templates
        my $no_pins = $c->req->param('no_pins') || '';
        my $toggle_pins_link =
          $c->req->uri_with( { no_pins => $no_pins ? 0 : 1 } );
        my $toggle_pins_text = $no_pins ? _('Show pins') : _('Hide pins');

        my $map_links =
            "<p id='sub_map_links'>"
          . "  <a id='hide_pins_link' rel='nofollow' href='$toggle_pins_link'>"
          . "    $toggle_pins_text"    #
          . "  </a>";

        $map_links .=                                                   #
          " | "                                                         #
          . "<a id='all_pins_link' rel='nofollow' href='$all_link'>"    #
          . "  $all_text"                                               #
          . "</a>"
          if mySociety::Config::get('COUNTRY') eq 'GB';

        $map_links .= "</p>";

        $map_links .=                                                     #
          "<input type='hidden' id='all_pins' name='all_pins' value='"    #
          . ( $all_pins || '' )                                           #
          . "'>"
          if mySociety::Config::get('COUNTRY') eq 'GB';

        $map_links .= "</p>";

        $c->stash->{map_html} = FixMyStreet::Map::display_map(
            $c->req,
            latitude  => $latitude,
            longitude => $longitude,
            type      => 1,
            pins      => \@pins,
            post      => $map_links
        );
        $c->stash->{map_end_html} = FixMyStreet::Map::display_map_end(1);
        $c->stash->{map_js}       = FixMyStreet::Map::header_js();
    }

    return 1;
}

=head2 determine_location_from_coords

Use latitude and longitude if provided in parameters.

=cut 

sub determine_location_from_coords : Private {
    my ( $self, $c ) = @_;

    my $latitude  = $c->req->param('latitude')  || $c->req->param('lat');
    my $longitude = $c->req->param('longitude') || $c->req->param('lon');

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
    $c->stash->{location_error} = $error;
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

    # show error
    if ($error_msg) {
        $c->stash->{location_error} = $error_msg;
        return;
    }

    # check that there are councils that can accept this location
    return $c->forward('/report/new/load_and_check_councils');
}

=head2 /ajax

Handle the ajax calls that the map makes when it is dragged. The info returned
is used to update the pins on the map and the text descriptions on the side of
the map.

=cut

sub ajax : Path('/ajax') {
    my ( $self, $c ) = @_;

    # Our current X/Y middle of visible map
    my $x = ( $c->req->param('x') || 0 ) + 0;
    my $y = ( $c->req->param('y') || 0 ) + 0;

    # Where we started as that's the (0,0) we have to work to
    my $sx = ( $c->req->param('sx') || 0 ) + 0;
    my $sy = ( $c->req->param('sy') || 0 ) + 0;

    # how far back should we go?
    my $all_pins = $c->req->param('all_pins') ? 1 : undef;
    my $interval = $all_pins ? undef : $c->cobrand->on_map_default_max_pin_age;

    # extract the data from the map
    my ( $pins, $on_map, $around_map, $dist ) =
      FixMyStreet::Map::map_pins( $c->fake_q, $x, $y, $sx, $sy, $interval );

    # render templates to get the html
    # my $on_map_list_html = $c->forward(
    #     "View::Web", "render",
    my $on_map_list_html =
      $c->view('Web')
      ->render( $c, 'around/on_map_list_items.html', { on_map => $on_map } );

    # my $around_map_list_html = $c->forward(
    #     "View::Web", "render",
    my $around_map_list_html = $c->view('Web')->render(
        $c,
        'around/around_map_list_items.html',
        { around_map => $around_map, dist => $dist }
    );

    # JSON encode the response
    my $body = JSON->new->utf8(1)->pretty(1)->encode(
        {
            pins         => $pins,
            current      => $on_map_list_html,
            current_near => $around_map_list_html,
        }
    );

    # assume this is not cacheable - may need to be more fine-grained later
    $c->res->content_type('text/javascript; charset=utf-8');
    $c->res->header( 'Cache_Control' => 'max-age=0' );

    # Set the body - note that the js needs the surrounding brackets.
    $c->res->body("($body)");
}

__PACKAGE__->meta->make_immutable;

1;
