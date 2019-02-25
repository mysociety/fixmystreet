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

sub map_javascript {
    $map_class->map_javascript;
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
        $p{min_lon} = Utils::truncate_coordinate($p{longitude} - $lon_delta);
        $p{min_lat} = Utils::truncate_coordinate($p{latitude} - $lat_delta);
        $p{max_lon} = Utils::truncate_coordinate($p{longitude} + $lon_delta);
        $p{max_lat} = Utils::truncate_coordinate($p{latitude} + $lat_delta);
    } else {
        $p{longitude} = Utils::truncate_coordinate(($p{max_lon} + $p{min_lon} ) / 2);
        $p{latitude} = Utils::truncate_coordinate(($p{max_lat} + $p{min_lat} ) / 2);
    }

    my $report_age = $c->stash->{show_old_reports} ? undef : $c->cobrand->report_age;
    $p{report_age} = $report_age;

    $p{page} = $c->get_param('p') || 1;
    my $on_map = $c->cobrand->problems_on_map->around_map( $c, %p );
    my $pager = $c->stash->{pager} = $on_map->pager;
    $on_map = [ $on_map->all ];

    if ( $c->{stash}->{show_old_reports} ) {
        # if show_old_reports is on then there must be old reports
        $c->stash->{num_old_reports} = 1;
    } else {
        my $older = $c->cobrand->problems_on_map->around_map( $c, %p, report_age => undef, page => 1 );
        $c->stash->{num_old_reports} = $older->pager->total_entries - $pager->total_entries;
    }

    # if there are fewer entries than our paging limit on the map then
    # also return nearby entries for display
    my $nearby;
    if (@$on_map < $pager->entries_per_page && $pager->current_page == 1) {
        $p{limit} = 20;
        $p{ids} = [ map { $_->id } @$on_map ];
        $p{distance} = FixMyStreet::Gaze::get_radius_containing_population( $p{latitude}, $p{longitude} );
        $nearby = $c->model('DB::Nearby')->nearby($c, %p);
    }

    return ( $on_map, $nearby );
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
