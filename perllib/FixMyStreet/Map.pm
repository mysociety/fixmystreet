#!/usr/bin/perl
#
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
  except      => 'FixMyStreet::Map::Tilma::Original',
  require     => 1;

# Get the list of maps we want and load map classes at compile time
my @ALL_MAP_CLASSES = allowed_maps();

use Problems;
use Cobrand;
use mySociety::Config;
use mySociety::Gaze;
use mySociety::Locale;
use mySociety::Web qw(ent);

=head2 allowed_maps

Returns an array of all the map classes that were found and that
are permitted by the config.

=cut

sub allowed_maps {
    my @allowed = split /,/, mySociety::Config::get('MAP_TYPE');
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

sub header_js {
    return $map_class->header_js(@_);
}

sub display_map {
    return $map_class->display_map(@_);
}

sub display_map_end {
    my ($type) = @_;
    my $out = '</div>';
    $out .= '</form>' if ($type);
    return $out;
}

sub header {
    my ( $q, $type ) = @_;
    return '' unless $type;

    my $cobrand = Page::get_cobrand($q);
    my $cobrand_form_elements =
      Cobrand::form_elements( $cobrand, 'mapForm', $q );
    my $form_action = Cobrand::url( $cobrand, '/report/new', $q );
    my $encoding = '';
    $encoding = ' enctype="multipart/form-data"' if $type == 2;
    my $pc = ent($q->param('pc') || '');
    my $map = ent($q->param('map') || '');
    return <<EOF;
<form action="$form_action" method="post" name="mapForm" id="mapForm"$encoding>
<input type="hidden" name="submit_map" value="1">
<input type="hidden" name="map" value="$map">
<input type="hidden" name="pc" value="$pc">
$cobrand_form_elements
EOF
}

sub map_features {
    my ( $q, $lat, $lon, $interval ) = @_;

   # TODO - be smarter about calculating the surrounding square
   # use deltas that are roughly 500m in the UK - so we get a 1 sq km search box
    my $lat_delta = 0.00438;
    my $lon_delta = 0.00736;

    my $min_lat = $lat - $lat_delta;
    my $max_lat = $lat + $lat_delta;

    my $min_lon = $lon - $lon_delta;
    my $max_lon = $lon + $lon_delta;

    # list of problems around map can be limited, but should show all pins
    my $around_limit    #
      = Cobrand::on_map_list_limit( Page::get_cobrand($q) ) || undef;

    my @around_args = ( $min_lat, $max_lat, $min_lon, $max_lon, $interval );
    my $around_map_list = Problems::around_map( @around_args, $around_limit );
    my $around_map      = Problems::around_map( @around_args, undef );

    my $dist;
    mySociety::Locale::in_gb_locale {
        $dist =
          mySociety::Gaze::get_radius_containing_population( $lat, $lon,
            200000 );
    };
    $dist = int( $dist * 10 + 0.5 ) / 10;

    my $limit  = 20;
    my @ids    = map { $_->{id} } @$around_map_list;
    my $nearby = Problems::nearby( $dist, join( ',', @ids ),
        $limit, $lat, $lon, $interval );

    return ( $around_map, $around_map_list, $nearby, $dist );
}

sub map_pins {
    return $map_class->map_pins(@_);
}

sub click_to_wgs84 {
    return $map_class->click_to_wgs84(@_);
}

sub tile_xy_to_wgs84 {
    return $map_class->tile_xy_to_wgs84(@_);
}

1;
