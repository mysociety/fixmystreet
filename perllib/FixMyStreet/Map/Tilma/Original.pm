#!/usr/bin/perl
#
# FixMyStreet:Map
# Adding the ability to have different maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map;

use strict;
use LWP::Simple;

use Cobrand;
use mySociety::Locale;
use mySociety::Web qw(ent NewURL);
use Utils;

sub _ll_to_en {
    my ($lat, $lon) = @_;
    return Utils::convert_latlon_to_en( $lat, $lon );
}

sub header_js {
    return '
<script type="text/javascript" src="/js/map-tilma.js"></script>
';
}

# display_map Q PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# TYPE is 1 if the map is clickable, 2 if clickable and has a form upload,
#     0 if not clickable
# PINS is array of pins to show, location and colour
# PRE/POST are HTML to show above/below map
sub _display_map {
    my ($q, %params) = @_;
    $params{pre} ||= '';
    $params{post} ||= '';
    my $mid_point = TILE_WIDTH; # Map is 2 TILE_WIDTHs in size, square.
    if ($q->{site} eq 'barnet') { # Map is c. 380px wide
        $mid_point = 189;
    }

    # convert map center point to easting, northing
    ( $params{easting}, $params{northing} ) =
      _ll_to_en( $params{latitude}, $params{longitude} );

    # FIXME - convert all pins to lat, lng
    # all the pins are currently [lat, lng, colour] - convert them
    foreach my $pin ( @{ $params{pins} ||= [] } ) {
        my ( $lat, $lon ) = ( $pin->[0], $pin->[1] );
        my ( $e, $n ) = _ll_to_en( $lat, $lon );
        ( $pin->[0], $pin->[1] ) = ( $e, $n );
    }

    # X/Y tile co-ords may be overridden in the query string
    my @vars = qw(x y);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    ($input{x}) = $input{x} =~ /^(\d+)/; $input{x} ||= 0;
    ($input{y}) = $input{y} =~ /^(\d+)/; $input{y} ||= 0;

    my ($x, $y, $px, $py) = FixMyStreet::Map::os_to_px_with_adjust($q, $params{easting}, $params{northing}, $input{x}, $input{y});

    my $pins = '';
    foreach my $pin (@{$params{pins}}) {
        my $pin_x = FixMyStreet::Map::os_to_px($pin->[0], $x);
        my $pin_y = FixMyStreet::Map::os_to_px($pin->[1], $y, 1);
        $pins .= FixMyStreet::Map::display_pin($q, $pin_x, $pin_y, $pin->[2]);
    }

    $px = defined($px) ? $mid_point - $px : 0;
    $py = defined($py) ? $mid_point - $py : 0;
    $x = int($x)<=0 ? 0 : $x;
    $y = int($y)<=0 ? 0 : $y;
    my $url = 'http://tilma.mysociety.org/tileserver/' . TILE_TYPE . '/';
    my $tiles_url = $url . ($x-1) . '-' . $x . ',' . ($y-1) . '-' . $y . '/RABX';
    my $tiles = LWP::Simple::get($tiles_url);
    return '<div id="map_box"> <div id="map"><div id="drag">' . _("Unable to fetch the map tiles from the tile server.") . '</div></div></div><div id="side">' if !$tiles;
    my $tileids = RABX::unserialise($tiles);
    my $tl = ($x-1) . '.' . $y;
    my $tr = $x . '.' . $y;
    my $bl = ($x-1) . '.' . ($y-1);
    my $br = $x . '.' . ($y-1);
    return '<div id="side">' if (!$tileids->[0][0] || !$tileids->[0][1] || !$tileids->[1][0] || !$tileids->[1][1]);
    my $tl_src = $url . $tileids->[0][0];
    my $tr_src = $url . $tileids->[0][1];
    my $bl_src = $url . $tileids->[1][0];
    my $br_src = $url . $tileids->[1][1];

    my $cobrand = Page::get_cobrand($q);
    my $root_path_js = Cobrand::root_path_js($cobrand, $q);
    my $out = FixMyStreet::Map::header($q, $params{type});
    my $img_type;
    if ($params{type}) {
        $out .= <<EOF;
<input type="hidden" name="x" id="formX" value="$x">
<input type="hidden" name="y" id="formY" value="$y">
EOF
        $img_type = '<input type="image"';
    } else {
        $img_type = '<img';
    }
    my $imgw = TILE_WIDTH . 'px';
    my $tile_width = TILE_WIDTH;
    my $tile_type = TILE_TYPE;
    $out .= <<EOF;
<script type="text/javascript">
$root_path_js
var fixmystreet = {
    'x': $x - 3,
    'y': $y - 3,
    'start_x': $px,
    'start_y': $py,
    'tile_type': '$tile_type',
    'tilewidth': $tile_width,
    'tileheight': $tile_width
};
</script>
<div id="map_box">
$params{pre}
    <div id="map"><div id="drag">
        $img_type alt="NW map tile" id="t2.2" name="tile_$tl" src="$tl_src" style="top:0px; left:0;">$img_type alt="NE map tile" id="t2.3" name="tile_$tr" src="$tr_src" style="top:0px; left:$imgw;"><br>$img_type alt="SW map tile" id="t3.2" name="tile_$bl" src="$bl_src" style="top:$imgw; left:0;">$img_type alt="SE map tile" id="t3.3" name="tile_$br" src="$br_src" style="top:$imgw; left:$imgw;">
        <div id="pins">$pins</div>
    </div>
EOF
    $out .= '<div id="watermark"></div>' if $params{watermark};
    $out .= compass($q, $x, $y);
    my $copyright = $params{copyright};
    $out .= <<EOF;
    </div>
    <p id="copyright">$copyright</p>
$params{post}
</div>
<div id="side">
EOF
    return $out;
}

sub display_map_end {
    my ($type) = @_;
    my $out = '</div>';
    $out .= '</form>' if ($type);
    return $out;
}

sub display_pin {
    my ($q, $px, $py, $col, $num) = @_;
    $num = '' if !$num || $num > 9;
    my $host = Page::base_url_with_lang($q, undef);
    my %cols = (red=>'R', green=>'G', blue=>'B', purple=>'P');
    my $out = '<img class="pin" src="' . $host . '/i/pin' . $cols{$col}
        . $num . '.gif" alt="' . _('Problem') . '" style="top:' . ($py-59)
        . 'px; left:' . ($px) . 'px; position: absolute;">';
    return $out unless $_ && $_->{id} && $col ne 'blue';
    my $cobrand = Page::get_cobrand($q);
    my $url = Cobrand::url($cobrand, NewURL($q, -retain => 1, 
                                                -url => '/report/' . $_->{id}, 
                                                pc => undef,
                                                x => undef, 
                                                y => undef, 
                                                sx => undef, 
                                                sy => undef, 
                                                all_pins => undef, 
                                                no_pins => undef), $q);
    $out = '<a title="' . ent($_->{title}) . '" href="' . $url . '">' . $out . '</a>';
    return $out;
}

sub map_pins {
    my ($q, $x, $y, $sx, $sy, $interval) = @_;

    my $e = FixMyStreet::Map::tile_to_os($x);
    my $n = FixMyStreet::Map::tile_to_os($y);

    my ( $around_map, $around_map_list, $nearby, $dist ) =
      FixMyStreet::Map::map_features_easting_northing( $q, $e, $n, $interval );

    my $pins = '';
    foreach (@$around_map) {
        ( $_->{easting}, $_->{northing} ) =
          _ll_to_en( $_->{latitude}, $_->{longitude} );
        my $px = FixMyStreet::Map::os_to_px($_->{easting}, $sx);
        my $py = FixMyStreet::Map::os_to_px($_->{northing}, $sy, 1);
        my $col = $_->{state} eq 'fixed' ? 'green' : 'red';
        $pins .= FixMyStreet::Map::display_pin($q, $px, $py, $col);
    }

    foreach (@$nearby) {
        ( $_->{easting}, $_->{northing} ) =
          _ll_to_en( $_->{latitude}, $_->{longitude} );
        my $px = FixMyStreet::Map::os_to_px($_->{easting}, $sx);
        my $py = FixMyStreet::Map::os_to_px($_->{northing}, $sy, 1);
        my $col = $_->{state} eq 'fixed' ? 'green' : 'red';
        $pins .= FixMyStreet::Map::display_pin($q, $px, $py, $col);
    }

    return ($pins, $around_map_list, $nearby, $dist);
}

# P is easting or northing
# C is centre tile reference of displayed map
sub os_to_px {
    my ($p, $c, $invert) = @_;
    return tile_to_px(os_to_tile($p), $c, $invert);
}

# Convert tile co-ordinates to pixel co-ordinates from top left of map
# C is centre tile reference of displayed map
sub tile_to_px {
    my ($p, $c, $invert) = @_;
    $p = TILE_WIDTH * ($p - $c + 1);
    $p = 2 * TILE_WIDTH - $p if $invert;
    $p = int($p + .5 * ($p <=> 0));
    return $p;
}

# Tile co-ordinates are linear scale of OS E/N
# Will need more generalising when more zooms appear
sub os_to_tile {
    return $_[0] / SCALE_FACTOR;
}

sub tile_to_os {
    return int($_[0] * SCALE_FACTOR + 0.5);
}

=head2 tile_xy_to_wgs84

    ($lat, $lon) = tile_xy_to_wgs84( $x, $y );

Takes the tile x,y and converts to lat, lon.

=cut

sub tile_xy_to_wgs84 {
    my ( $x, $y ) = @_;

    my $easting  = tile_to_os($x);
    my $northing = tile_to_os($y);

    my ( $lat, $lon ) = Utils::convert_en_to_latlon( $easting, $northing );
    return ( $lat, $lon );
}


sub click_to_tile {
    my ($pin_tile, $pin, $invert) = @_;
    $pin -= TILE_WIDTH while $pin > TILE_WIDTH;
    $pin += TILE_WIDTH while $pin < 0;
    $pin = TILE_WIDTH - $pin if $invert; # image submits measured from top down
    return $pin_tile + $pin / TILE_WIDTH;
}

# Given some click co-ords (the tile they were on, and where in the
# tile they were), convert to OSGB36 and return.
sub click_to_os {
    my ($pin_tile_x, $pin_x, $pin_tile_y, $pin_y) = @_;
    my $tile_x = FixMyStreet::Map::click_to_tile($pin_tile_x, $pin_x);
    my $tile_y = FixMyStreet::Map::click_to_tile($pin_tile_y, $pin_y, 1);
    my $easting = FixMyStreet::Map::tile_to_os($tile_x);
    my $northing = FixMyStreet::Map::tile_to_os($tile_y);
    return ($easting, $northing);
}

# Given some click co-ords (the tile they were on, and where in the
# tile they were), convert to WGS84 and return.
sub click_to_wgs84 {
    my ( $easting, $northing ) = FixMyStreet::Map::click_to_os(@_);
    my ( $lat, $lon ) = national_grid_to_wgs84( $easting, $northing, 'G' );
    return ( $lat, $lon );
}

# Given (E,N) and potential override (X,Y), return the X/Y tile for the centre
# of the map (either to get the point near the middle, or the override X,Y),
# and the pixel co-ords of the point, relative to that map.
sub os_to_px_with_adjust {
    my ($q, $easting, $northing, $in_x, $in_y) = @_;

    my $x = FixMyStreet::Map::os_to_tile($easting);
    my $y = FixMyStreet::Map::os_to_tile($northing);
    my $x_tile = $in_x || int($x);
    my $y_tile = $in_y || int($y);

    # Try and have point near centre of map
    if (!$in_x && $x - $x_tile > 0.5) {
        $x_tile += 1;
    }
    if (!$in_y && $y - $y_tile > 0.5) {
        $y_tile += 1;
    }

    my $px = FixMyStreet::Map::os_to_px($easting, $x_tile);
    my $py = FixMyStreet::Map::os_to_px($northing, $y_tile, 1);
    if ($q->{site} eq 'barnet') { # Map is 380px, so might need to adjust
        if (!$in_x && $px > 380) {
            $x_tile++;
            $px = FixMyStreet::Map::os_to_px($easting, $x_tile);
        }
        if (!$in_y && $py > 380) {
            $y_tile--;
            $py = FixMyStreet::Map::os_to_px($northing, $y_tile, 1);
        }
    }

    return ($x_tile, $y_tile, $px, $py);
}

1;
