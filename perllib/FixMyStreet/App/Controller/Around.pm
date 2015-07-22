package FixMyStreet::App::Controller::Around;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::Map;
use Encode;
use Utils;

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

    # handle old coord systems
    $c->forward('redirect_en_or_xy_to_latlon');

    # Check if we have a partial report
    my $partial_report = $c->forward('load_partial');

    # Try to create a location for whatever we have
    my $ret = $c->forward('/location/determine_location_from_coords')
        || $c->forward('/location/determine_location_from_pc');
    unless ($ret) {
        return $c->res->redirect('/') unless $c->get_param('pc') || $partial_report;
        return;
    }

    # Check to see if the spot is covered by a area - if not show an error.
    return unless $c->cobrand->moniker eq 'fixmybarangay' || $c->forward('check_location_is_acceptable');

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

=head2 redirect_en_or_xy_to_latlon

    # detaches if there was a redirect
    $c->forward('redirect_en_or_xy_to_latlon');

Handle coord systems that are no longer in use.

=cut

sub redirect_en_or_xy_to_latlon : Private {
    my ( $self, $c ) = @_;

    # check for x,y or e,n requests
    my $x = $c->get_param('x');
    my $y = $c->get_param('y');
    my $e = $c->get_param('e');
    my $n = $c->get_param('n');

    # lat and lon - fill in below if we need to
    my ( $lat, $lon );

    if ( $x || $y ) {
        ( $lat, $lon ) = FixMyStreet::Map::tile_xy_to_wgs84( $x, $y );
        ( $lat, $lon ) = map { Utils::truncate_coordinate($_) } ( $lat, $lon );
    }
    elsif ( $e || $n ) {
        ( $lat, $lon ) = Utils::convert_en_to_latlon_truncated( $e, $n );
    }
    else {
        return;
    }

    # create a uri and redirect to it
    my $ll_uri = $c->uri_for( '/around', { lat => $lat, lon => $lon } );
    $c->res->redirect( $ll_uri, 301 );
    $c->detach;
}

=head2 load_partial

    my $partial_report = $c->forward('load_partial');

Check for the partial token and load the partial report. If found save it and
token to stash and return report. Otherwise return false.

=cut

sub load_partial : Private {
    my ( $self, $c ) = @_;

    my $partial = $c->get_param('partial')
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
    my $report = $c->cobrand->problems                       #
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

    # Deal with pin hiding/age
    my $all_pins = $c->get_param('all_pins') ? 1 : undef;
    $c->stash->{all_pins} = $all_pins;
    my $interval = $all_pins ? undef : $c->cobrand->on_map_default_max_pin_age;

    $c->forward( '/reports/stash_report_filter_status' );

    # Check the category to filter by, if any, is valid
    $c->forward('check_and_stash_category');

    # get the map features
    my ( $on_map_all, $on_map, $around_map, $distance ) =
      FixMyStreet::Map::map_features( $c, $latitude, $longitude,
        $interval, $c->stash->{filter_category}, $c->stash->{filter_problem_states} );

    # copy the found reports to the stash
    $c->stash->{on_map}     = $on_map;
    $c->stash->{around_map} = $around_map;
    $c->stash->{distance}   = $distance;

    # create a list of all the pins
    my @pins;
    unless ($c->get_param('no_pins') || $c->cobrand->moniker eq 'emptyhomes') {
        @pins = map {
            # Here we might have a DB::Problem or a DB::Nearby, we always want the problem.
            my $p = (ref $_ eq 'FixMyStreet::App::Model::DB::Nearby') ? $_->problem : $_;
            my $colour = $c->cobrand->pin_colour( $p, 'around' );
            {
                latitude  => $p->latitude,
                longitude => $p->longitude,
                colour    => $colour,
                id        => $p->id,
                title     => $p->title_safe,
            }
        } @$on_map_all, @$around_map;
    }

    $c->stash->{page} = 'around'; # So the map knows to make clickable pins, update on pan
    FixMyStreet::Map::display_map(
        $c,
        latitude  => $latitude,
        longitude => $longitude,
        clickable => 1,
        pins      => \@pins,
        area      => $c->cobrand->areas_on_around,
    );

    return 1;
}

=head2 check_location_is_acceptable

Find the lat and lon in stash and check that they are acceptable to the area,
and that they are in UK (if we are in UK).

=cut

sub check_location_is_acceptable : Private {
    my ( $self, $c ) = @_;

    # check that there are areas that can accept this location
    $c->stash->{area_check_action} = 'submit_problem';
    $c->stash->{remove_redundant_areas} = 1;
    return $c->forward('/council/load_and_check_areas');
}

=head2 check_and_stash_category

Check that the 'filter_category' query param is valid, if it's present. Stores
the validated string in the stash as filter_category.
Puts all the valid categories in filter_categories on the stash.

=cut

sub check_and_stash_category : Private {
    my ( $self, $c ) = @_;

    my $all_areas = $c->stash->{all_areas};
    my @bodies = $c->model('DB::Body')->search(
        { 'body_areas.area_id' => [ keys %$all_areas ], deleted => 0 },
        { join => 'body_areas' }
    )->all;
    my %bodies = map { $_->id => $_ } @bodies;

    my @contacts = $c->model('DB::Contact')->not_deleted->search(
        {
            body_id => [ keys %bodies ],
        },
        {
            columns => [ 'category' ],
            order_by => [ 'category' ],
            distinct => 1
        }
    )->all;
    my @categories = map { $_->category } @contacts;
    $c->stash->{filter_categories} = \@categories;


    my $category = $c->get_param('filter_category');
    my %categories_mapped = map { $_ => 1 } @categories;
    if ( defined $category && $categories_mapped{$category} ) {
        $c->stash->{filter_category} = $category;
    }
}

=head2 /ajax

Handle the ajax calls that the map makes when it is dragged. The info returned
is used to update the pins on the map and the text descriptions on the side of
the map.

=cut

sub ajax : Path('/ajax') {
    my ( $self, $c ) = @_;

    $c->res->content_type('application/json; charset=utf-8');

    unless ( $c->get_param('bbox') ) {
        $c->res->status(404);
        $c->res->body('');
        return;
    }

    # assume this is not cacheable - may need to be more fine-grained later
    $c->res->header( 'Cache_Control' => 'max-age=0' );

    # how far back should we go?
    my $all_pins = $c->get_param('all_pins') ? 1 : undef;
    my $interval = $all_pins ? undef : $c->cobrand->on_map_default_max_pin_age;

    # Need to be the class that can handle it
    FixMyStreet::Map::set_map_class( 'OSM' );

    # extract the data from the map
    my ( $pins, $on_map, $around_map, $dist ) =
      FixMyStreet::Map::map_pins( $c, $interval );

    # render templates to get the html
    my $on_map_list_html = $c->render_fragment(
        'around/on_map_list_items.html',
        { on_map => $on_map, around_map => $around_map }
    );
    my $around_map_list_html = $c->render_fragment(
        'around/around_map_list_items.html',
        { on_map => $on_map, around_map => $around_map }
    );

    # JSON encode the response
    my $json = { pins => $pins };
    $json->{current} = $on_map_list_html if $on_map_list_html;
    $json->{current_near} = $around_map_list_html if $around_map_list_html;
    my $body = JSON->new->utf8(1)->encode($json);
    $c->res->body($body);
}


sub location_autocomplete : Path('/ajax/geocode') {
    my ( $self, $c ) = @_;
    $c->res->content_type('application/json; charset=utf-8');
    unless ( $c->get_param('term') ) {
        $c->res->status(404);
        $c->res->body('');
        return;
    }
    # we want the match even if there's no ambiguity, so recommendation doesn't
    # disappear when it's the last choice being offered in the autocomplete.
    $c->stash->{allow_single_geocode_match_strings} = 1;
    return $self->_geocode( $c, $c->get_param('term') );
}

sub location_lookup : Path('/ajax/lookup_location') {
    my ( $self, $c ) = @_;
    $c->res->content_type('application/json; charset=utf-8');
    unless ( $c->get_param('term') ) {
        $c->res->status(404);
        $c->res->body('');
        return;
    }

    return $self->_geocode( $c, $c->get_param('term') );
}

sub _geocode : Private {
    my ( $self, $c, $term ) = @_;

    my ( $lat, $long, $suggestions ) =
        FixMyStreet::Geocode::lookup( $c->get_param('term'), $c );

    my ($response, @addresses, @locations);

    if ( $lat && $long ) {
        $response = { latitude => $lat, longitude => $long };
    } else {
        if ( ref($suggestions) eq 'ARRAY' ) {
            foreach (@$suggestions) {
                push @addresses, decode_utf8($_->{address});
                push @locations, { address => decode_utf8($_->{address}), lat => $_->{latitude}, long => $_->{longitude} };
            }
            $response = { suggestions => \@addresses, locations => \@locations };
        } else {
            $response = { error => $suggestions };
        }
    }

    if ( $c->stash->{allow_single_geocode_match_strings} ) {
        $response = \@addresses;
    }

    my $body = JSON->new->utf8(1)->encode(
        $response
    );
    $c->res->body($body);

}

__PACKAGE__->meta->make_immutable;

1;
