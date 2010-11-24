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

use Problems;
use Cobrand;
use mySociety::Config;
use mySociety::Gaze;
use mySociety::GeoUtil;
use mySociety::Locale;
use mySociety::Web qw(ent NewURL);

use constant TILE_WIDTH => mySociety::Config::get('TILES_WIDTH');
use constant TIF_SIZE_M => mySociety::Config::get('TILES_TIFF_SIZE_METRES');
use constant TIF_SIZE_PX => mySociety::Config::get('TILES_TIFF_SIZE_PIXELS');
use constant SCALE_FACTOR => TIF_SIZE_M / (TIF_SIZE_PX / TILE_WIDTH);

# display_map Q PARAMS
# PARAMS include:
# EASTING, NORTHING for the centre point of the map
# TYPE is 1 if the map is clickable, 2 if clickable and has a form upload,
#     0 if not clickable
# PINS is array of pins to show, location and colour
# PRE/POST are HTML to show above/below map
sub display_map {
    my ($q, %params) = @_;
    $params{pre} ||= '';
    $params{post} ||= '';
    my $mid_point = TILE_WIDTH; # Map is 2 TILE_WIDTHs in size, square.
    if ($q->{site} eq 'barnet') { # Map is c. 380px wide
        $mid_point = 189;
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
    my $url = mySociety::Config::get('TILES_URL');
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

    my $out = '';
    my $cobrand = Page::get_cobrand($q);
    my $root_path_js = Cobrand::root_path_js($cobrand, $q);
    my $cobrand_form_elements = Cobrand::form_elements($cobrand, 'mapForm', $q);
    my $img_type;
    my $form_action = Cobrand::url($cobrand, '', $q);
    if ($params{type}) {
        my $encoding = '';
        $encoding = ' enctype="multipart/form-data"' if ($params{type}==2);
        my $pc = $q->param('pc') || '';
        my $pc_enc = ent($pc);
        $out .= <<EOF;
<form action="$form_action" method="post" name="mapForm" id="mapForm"$encoding>
<input type="hidden" name="submit_map" value="1">
<input type="hidden" name="x" id="formX" value="$x">
<input type="hidden" name="y" id="formY" value="$y">
<input type="hidden" name="pc" value="$pc_enc">
$cobrand_form_elements
EOF
        $img_type = '<input type="image"';
    } else {
        $img_type = '<img';
    }
    my $imgw = TILE_WIDTH . 'px';
    my $tile_width = TILE_WIDTH;
    my $tile_type = mySociety::Config::get('TILES_TYPE');
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
    if (Cobrand::show_watermark($cobrand) && mySociety::Config::get('TILES_TYPE') ne 'streetview') {
        $out .= '<div id="watermark"></div>';
    }
    $out .= compass($q, $x, $y);
    my $copyright;
    if (mySociety::Config::get('TILES_TYPE') eq 'streetview') {
        $copyright = _('Map contains Ordnance Survey data &copy; Crown copyright and database right 2010.');
    } else {
        $copyright = _('&copy; Crown copyright. All rights reserved. Ministry of Justice 100037819&nbsp;2008.');
    }
    $out .= <<EOF;
    </div>
    <p id="copyright">$copyright</p>
$params{post}
EOF
    $out .= '</div>';
    $out .= '<div id="side">';
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

sub map_features {
    my ($q, $easting, $northing, $interval) = @_;

    my $xx = FixMyStreet::Map::os_to_tile($easting);
    my $yy = FixMyStreet::Map::os_to_tile($northing);
    my $x = int($xx);
    my $y = int($yy);
    $x += 1 if ($xx - $x > 0.5);
    $y += 1 if ($yy - $y > 0.5);

    my $min_e = FixMyStreet::Map::tile_to_os($x-3); # Due to when the front-end AJAX look ups pins
    my $min_n = FixMyStreet::Map::tile_to_os($y-3);
    my $mid_e = FixMyStreet::Map::tile_to_os($x);
    my $mid_n = FixMyStreet::Map::tile_to_os($y);
    my $max_e = FixMyStreet::Map::tile_to_os($x+2);
    my $max_n = FixMyStreet::Map::tile_to_os($y+2);

    # list of problems aoround map can be limited, but should show all pins
    my ($around_map, $around_map_list);
    if (my $around_limit = Cobrand::on_map_list_limit(Page::get_cobrand($q))) {
        $around_map_list = Problems::around_map($min_e, $max_e, $min_n, $max_n, $interval, $around_limit);
        $around_map = Problems::around_map($min_e, $max_e, $min_n, $max_n, $interval, undef);
    } else {
        $around_map = $around_map_list = Problems::around_map($min_e, $max_e, $min_n, $max_n, $interval, undef);
    }

    my $dist;
    mySociety::Locale::in_gb_locale {
        my ($lat, $lon) = mySociety::GeoUtil::national_grid_to_wgs84($mid_e, $mid_n, 'G');
        $dist = mySociety::Gaze::get_radius_containing_population($lat, $lon, 200000);
    };
    $dist = int($dist*10+0.5)/10;

    my $limit = 20;
    my @ids = map { $_->{id} } @$around_map_list;
    my $nearby = Problems::nearby($dist, join(',', @ids), $limit, $mid_e, $mid_n, $interval);

    return ($around_map, $around_map_list, $nearby, $dist);
}

sub map_pins {
    my ($q, $x, $y, $sx, $sy, $interval) = @_;

    my $e = FixMyStreet::Map::tile_to_os($x);
    my $n = FixMyStreet::Map::tile_to_os($y);
    my ($around_map, $around_map_list, $nearby, $dist) = FixMyStreet::Map::map_features($q, $e, $n, $interval);

    my $pins = '';
    foreach (@$around_map) {
        my $px = FixMyStreet::Map::os_to_px($_->{easting}, $sx);
        my $py = FixMyStreet::Map::os_to_px($_->{northing}, $sy, 1);
        my $col = $_->{state} eq 'fixed' ? 'green' : 'red';
        $pins .= FixMyStreet::Map::display_pin($q, $px, $py, $col);
    }

    foreach (@$nearby) {
        my $px = FixMyStreet::Map::os_to_px($_->{easting}, $sx);
        my $py = FixMyStreet::Map::os_to_px($_->{northing}, $sy, 1);
        my $col = $_->{state} eq 'fixed' ? 'green' : 'red';
        $pins .= FixMyStreet::Map::display_pin($q, $px, $py, $col);
    }

    return ($pins, $around_map_list, $nearby, $dist);
}

sub compass ($$$) {
    my ($q, $x, $y) = @_;
    my @compass;
    for (my $i=$x-1; $i<=$x+1; $i++) {
        for (my $j=$y-1; $j<=$y+1; $j++) {
            $compass[$i][$j] = NewURL($q, x=>$i, y=>$j);
        }
    }
    my $recentre = NewURL($q);
    my $host = Page::base_url_with_lang($q, undef);
    return <<EOF;
<table cellpadding="0" cellspacing="0" border="0" id="compass">
<tr valign="bottom">
<td align="right"><a rel="nofollow" href="${compass[$x-1][$y+1]}"><img src="$host/i/arrow-northwest.gif" alt="NW" width=11 height=11></a></td>
<td align="center"><a rel="nofollow" href="${compass[$x][$y+1]}"><img src="$host/i/arrow-north.gif" vspace="3" alt="N" width=13 height=11></a></td>
<td><a rel="nofollow" href="${compass[$x+1][$y+1]}"><img src="$host/i/arrow-northeast.gif" alt="NE" width=11 height=11></a></td>
</tr>
<tr>
<td><a rel="nofollow" href="${compass[$x-1][$y]}"><img src="$host/i/arrow-west.gif" hspace="3" alt="W" width=11 height=13></a></td>
<td align="center"><a rel="nofollow" href="$recentre"><img src="$host/i/rose.gif" alt="Recentre" width=35 height=34></a></td>
<td><a rel="nofollow" href="${compass[$x+1][$y]}"><img src="$host/i/arrow-east.gif" hspace="3" alt="E" width=11 height=13></a></td>
</tr>
<tr valign="top">
<td align="right"><a rel="nofollow" href="${compass[$x-1][$y-1]}"><img src="$host/i/arrow-southwest.gif" alt="SW" width=11 height=11></a></td>
<td align="center"><a rel="nofollow" href="${compass[$x][$y-1]}"><img src="$host/i/arrow-south.gif" vspace="3" alt="S" width=13 height=11></a></td>
<td><a rel="nofollow" href="${compass[$x+1][$y-1]}"><img src="$host/i/arrow-southeast.gif" alt="SE" width=11 height=11></a></td>
</tr>
</table>
EOF
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
