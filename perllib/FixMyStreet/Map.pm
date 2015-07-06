# FixMyStreet:Map
# Adding the ability to have different maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map;

use strict;

use Module::Pluggable
  sub_name    => 'maps',
  search_path => __PACKAGE__,
  require     => 1;

# Get the list of maps we want and load map classes at compile time
my @ALL_MAP_CLASSES = allowed_maps();

use mySociety::Gaze;
use mySociety::Locale;
use Utils;

=head2 allowed_maps

Returns an array of all the map classes that were found and that
are permitted by the config.

=cut

sub allowed_maps {
    my @allowed = split /,/, ( FixMyStreet->config('MAP_TYPE') or "");
    push @allowed, 'OSM'; # OSM is always allowed
    @allowed = map { __PACKAGE__.'::'.$_ } @allowed;
    my %avail = map { $_ => 1 } __PACKAGE__->maps;
    return grep { $avail{$_} } @allowed;
}

=head2 map_class

Set and return the appropriate class given a query parameter string.

=cut

our $map_class;
sub set_map_class {
    my $str = shift;
    $str = __PACKAGE__.'::'.$str if $str;
    my %avail = map { $_ => 1 } @ALL_MAP_CLASSES;
    $str = $ALL_MAP_CLASSES[0] unless $str && $avail{$str};
    $map_class = $str;
}

sub display_map {
    return $map_class->display_map(@_);
}

sub map_features {
    my ( $c, $lat, $lon, $interval, $category, $states ) = @_;

   # TODO - be smarter about calculating the surrounding square
   # use deltas that are roughly 500m in the UK - so we get a 1 sq km search box
    my $lat_delta = 0.00438;
    my $lon_delta = 0.00736;
    return _map_features(
        $c, $lat, $lon,
        $lon - $lon_delta, $lat - $lat_delta,
        $lon + $lon_delta, $lat + $lat_delta,
        $interval, $category, $states
    );
}

sub map_features_bounds {
    my ( $c, $min_lon, $min_lat, $max_lon, $max_lat, $interval, $category, $states ) = @_;

    my $lat = ( $max_lat + $min_lat ) / 2;
    my $lon = ( $max_lon + $min_lon ) / 2;
    return _map_features(
        $c, $lat, $lon,
        $min_lon, $min_lat,
        $max_lon, $max_lat,
        $interval, $category,
        $states
    );
}

sub _map_features {
    my ( $c, $lat, $lon, $min_lon, $min_lat, $max_lon, $max_lat, $interval, $category, $states ) = @_;

    # list of problems around map can be limited, but should show all pins
    my $around_limit = $c->cobrand->on_map_list_limit || undef;

    my @around_args = ( $min_lat, $max_lat, $min_lon, $max_lon, $interval );
    my $around_map      = $c->cobrand->problems->around_map( @around_args, undef, $category, $states );
    my $around_map_list = $around_limit
        ? $c->cobrand->problems->around_map( @around_args, $around_limit, $category, $states )
        : $around_map;

    my $dist;
    mySociety::Locale::in_gb_locale {
        $dist =
          mySociety::Gaze::get_radius_containing_population( $lat, $lon,
            200000 );
    };
    $dist = int( $dist * 10 + 0.5 ) / 10;

    my $limit  = 20;
    my @ids    = map { $_->id } @$around_map_list;
    my $nearby = $c->model('DB::Nearby')->nearby(
        $c, $dist, \@ids, $limit, $lat, $lon, $interval, $category, $states
    );

    return ( $around_map, $around_map_list, $nearby, $dist );
}

sub map_pins {
    my ($c, $interval) = @_;

    my $bbox = $c->get_param('bbox');
    my ( $min_lon, $min_lat, $max_lon, $max_lat ) = split /,/, $bbox;
    my $category = $c->get_param('filter_category');

    $c->forward( '/reports/stash_report_filter_status' );
    my $states = $c->stash->{filter_problem_states};

    my ( $around_map, $around_map_list, $nearby, $dist ) =
      FixMyStreet::Map::map_features_bounds( $c, $min_lon, $min_lat, $max_lon, $max_lat, $interval, $category, $states );

    # create a list of all the pins
    my @pins = map {
        # Here we might have a DB::Problem or a DB::Nearby, we always want the problem.
        my $p = (ref $_ eq 'FixMyStreet::App::Model::DB::Nearby') ? $_->problem : $_;
        my $colour = $c->cobrand->pin_colour( $p, 'around' );
        [ $p->latitude, $p->longitude,
          $colour,
          $p->id, $p->title_safe
        ]
    } @$around_map, @$nearby;

    return (\@pins, $around_map_list, $nearby, $dist);
}

sub click_to_wgs84 {
    return $map_class->click_to_wgs84(@_);
}

=head2 tile_xy_to_wgs84

Takes the tile x,y and converts to lat, lon. Legacy to deal with old URLs,
hence hard-coded things.

=cut

sub tile_xy_to_wgs84 {
    my ( $x, $y ) = @_;
    my $easting  = int( $x * (5000/31) + 0.5 );
    my $northing = int( $y * (5000/31) + 0.5 );
    my ( $lat, $lon ) = Utils::convert_en_to_latlon( $easting, $northing );
    return ( $lat, $lon );
}

1;
