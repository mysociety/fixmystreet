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

use FixMyStreet::Gaze;
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

=head2 reload_allowed_maps

Allows tests to override MAP_TYPE at run time.

=cut

sub reload_allowed_maps {
    @ALL_MAP_CLASSES = allowed_maps();
}

=head2 map_class

Sets the appropriate class given a query parameter string.
Returns the old map class, if any.

=cut

our $map_class;
sub set_map_class {
    my $str = shift;
    $str = __PACKAGE__.'::'.$str if $str;
    my %avail = map { $_ => 1 } @ALL_MAP_CLASSES;
    $str = $ALL_MAP_CLASSES[0] unless $str && $avail{$str};
    my $old_map_class = $map_class;
    $map_class = $str;
    return $old_map_class;
}

sub display_map {
    return $map_class->display_map(@_);
}

sub map_features {
    my ( $c, %p ) = @_;

    if ($p{bbox}) {
        @p{"min_lon", "min_lat", "max_lon", "max_lat"} = split /,/, $p{bbox};
    }

    if (defined $p{latitude} && defined $p{longitude}) {
        # TODO - be smarter about calculating the surrounding square
        # use deltas that are roughly 500m in the UK - so we get a 1 sq km search box
        my $lat_delta = 0.00438;
        my $lon_delta = 0.00736;
        $p{min_lon} = $p{longitude} - $lon_delta;
        $p{min_lat} = $p{latitude} - $lat_delta;
        $p{max_lon} = $p{longitude} + $lon_delta;
        $p{max_lat} = $p{latitude} + $lat_delta;
    } else {
        $p{longitude} = ($p{max_lon} + $p{min_lon} ) / 2;
        $p{latitude} = ($p{max_lat} + $p{min_lat} ) / 2;
    }

    # list of problems around map can be limited, but should show all pins
    my $around_limit = $c->cobrand->on_map_list_limit || undef;

    my $on_map_all = $c->cobrand->problems_on_map->around_map( undef, %p );
    my $on_map_list = $around_limit
        ? $c->cobrand->problems_on_map->around_map( $around_limit, %p )
        : $on_map_all;

    my $dist = FixMyStreet::Gaze::get_radius_containing_population( $p{latitude}, $p{longitude} );

    my $limit  = 20;
    my @ids    = map { $_->id } @$on_map_list;
    my $nearby = $c->model('DB::Nearby')->nearby(
        $c, $dist, \@ids, $limit, @p{"latitude", "longitude", "interval", "categories", "states"}
    );

    return ( $on_map_all, $on_map_list, $nearby, $dist );
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
