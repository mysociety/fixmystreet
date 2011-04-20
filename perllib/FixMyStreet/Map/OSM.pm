#!/usr/bin/perl
#
# FixMyStreet:Map::OSM
# OSM maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM;

use strict;
use Math::Trig;
use mySociety::Web qw(ent NewURL);
use Utils;
use LWP::Simple;
use XML::Simple;

sub header_js {
    return '
<script type="text/javascript" src="/jslib/OpenLayers-2.10/OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-OpenStreetMap.js"></script>
';
}

sub map_type {
    return 'OpenLayers.Layer.OSM.Mapnik';
}

# display_map Q PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# TYPE is 1 if the map is clickable, 2 if clickable and has a form upload,
#     0 if not clickable
# PINS is array of pins to show, location and colour
# PRE/POST are HTML to show above/below map
sub display_map {
    my ($self, $q, %params) = @_;
    $params{pre} ||= '';
    $params{post} ||= '';

    # Map centre may be overridden in the query string
    $params{latitude} = Utils::truncate_coordinate($q->param('lat')+0)
        if defined $q->param('lat');
    $params{longitude} = Utils::truncate_coordinate($q->param('lon')+0)
        if defined $q->param('lon');

    my $zoom = defined $q->param('zoom') ? $q->param('zoom') : 2;
    my $zoom_act = 14 + $zoom;
    my ($x_tile, $y_tile) = latlon_to_tile_with_adjust($params{latitude}, $params{longitude}, $zoom_act);

    my $tl = ($x_tile-1) . "/" . ($y_tile-1);
    my $tr = "$x_tile/" . ($y_tile-1);
    my $bl = ($x_tile-1) . "/$y_tile";
    my $br = "$x_tile/$y_tile";
    my $tl_src = "http://a.tile.openstreetmap.org/$zoom_act/$tl.png";
    my $tr_src = "http://b.tile.openstreetmap.org/$zoom_act/$tr.png";
    my $bl_src = "http://c.tile.openstreetmap.org/$zoom_act/$bl.png";
    my $br_src = "http://tile.openstreetmap.org/$zoom_act/$br.png";
    map { s{/}{.} } ($tl, $tr, $bl, $br);

    my @pins;
    my $pins = '';
    foreach my $pin (@{$params{pins}}) {
        $pin->[3] ||= '';
        push @pins, "[ $pin->[0], $pin->[1], '$pin->[2]', '$pin->[3]' ]";
        $pins .= display_pin($q, $pin, $x_tile, $y_tile, $zoom_act);
    }
    my $pins_js = join(",\n", @pins);

    my $img_type;
    if ($params{type}) {
        $img_type = '<input type="image"';
    } else {
        $img_type = '<img';
    }
    my $out = FixMyStreet::Map::header($q, $params{type});
    my $copyright = _('Map &copy; <a id="osm_link" href="http://www.openstreetmap.org/">OpenStreetMap</a> and contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>');
    my $compass = compass($q, $x_tile, $y_tile, $zoom);
    my $map_type = $self->map_type();
    $out .= <<EOF;
<input type="hidden" name="latitude" id="fixmystreet.latitude" value="$params{latitude}">
<input type="hidden" name="longitude" id="fixmystreet.longitude" value="$params{longitude}">
<input type="hidden" name="zoom" value="$zoom">
<script type="text/javascript">
var fixmystreet = {
    'latitude': $params{latitude},
    'longitude': $params{longitude},
    'pins': [ $pins_js ],
    'map_type': $map_type
}
</script>
<div id="map_box">
    $params{pre}
    <div id="map"><noscript>
        <div id="drag">$img_type alt="NW map tile" id="t2.2" name="tile_$tl" src="$tl_src" style="top:0; left:0;">$img_type alt="NE map tile" id="t2.3" name="tile_$tr" src="$tr_src" style="top:0px; left:256px;"><br>$img_type alt="SW map tile" id="t3.2" name="tile_$bl" src="$bl_src" style="top:256px; left:0;">$img_type alt="SE map tile" id="t3.3" name="tile_$br" src="$br_src" style="top:256px; left:256px;"></div>
        <div id="pins">$pins</div>
        $compass
    </noscript></div>
    <p id="copyright">$copyright</p>
    $params{post}
</div>
<div id="side">
EOF
    return $out;
}

sub display_pin {
    my ($q, $pin, $x_tile, $y_tile, $zoom) = @_;

    my ($px, $py) = latlon_to_px($pin->[0], $pin->[1], $x_tile, $y_tile, $zoom);

    my $num = '';
    my $host = Page::base_url_with_lang($q, undef);
    my %cols = (red=>'R', green=>'G', blue=>'B', purple=>'P');
    my $out = '<img border="0" class="pin" src="' . $host . '/i/pin' . $cols{$pin->[2]}
        . $num . '.gif" alt="' . _('Problem') . '" style="top:' . ($py-59)
        . 'px; left:' . ($px) . 'px; position: absolute;">';
    return $out unless $pin->[3];
    my $cobrand = Page::get_cobrand($q);
    my $url = Cobrand::url($cobrand, NewURL($q, -url => '/report/' . $pin->[3]), $q);
    # XXX Would like to include title here in title=""
    $out = '<a href="' . $url . '">' . $out . '</a>';
    return $out;
}

# Given a lat/lon, convert it to OSM tile co-ordinates (precise).
sub latlon_to_tile($$$) {
    my ($lat, $lon, $zoom) = @_;
    my $x_tile = ($lon + 180) / 360 * 2**$zoom;
    my $y_tile = (1 - log(tan(deg2rad($lat)) + sec(deg2rad($lat))) / pi) / 2 * 2**$zoom;
    return ( $x_tile, $y_tile );
}

# Given a lat/lon, convert it to OSM tile co-ordinates (nearest actual tile,
# adjusted so the point will be near the centre of a 2x2 tiled map).
sub latlon_to_tile_with_adjust($$$) {
    my ($lat, $lon, $zoom) = @_;
    my ($x_tile, $y_tile) = latlon_to_tile($lat, $lon, $zoom);

    # Try and have point near centre of map
    if ($x_tile - int($x_tile) > 0.5) {
        $x_tile += 1;
    }
    if ($y_tile - int($y_tile) > 0.5) {
        $y_tile += 1;
    }

    return ( int($x_tile), int($y_tile) );
}

sub tile_to_latlon {
    my ($x, $y, $zoom) = @_;
    my $n = 2 ** $zoom;
    my $lon = $x / $n * 360 - 180;
    my $lat = rad2deg(atan(sinh(pi * (1 - 2 * $y / $n))));
    return ( $lat, $lon );
}

# Given a lat/lon, convert it to pixel co-ordinates from the top left of the map
sub latlon_to_px($$$$$) {
    my ($lat, $lon, $x_tile, $y_tile, $zoom) = @_;
    my ($pin_x_tile, $pin_y_tile) = latlon_to_tile($lat, $lon, $zoom);
    my $pin_x = tile_to_px($pin_x_tile, $x_tile);
    my $pin_y = tile_to_px($pin_y_tile, $y_tile);
    return ($pin_x, $pin_y);
}

# Convert tile co-ordinates to pixel co-ordinates from top left of map
# C is centre tile reference of displayed map
sub tile_to_px {
    my ($p, $c) = @_;
    $p = 256 * ($p - $c + 1);
    $p = int($p + .5 * ($p <=> 0));
    return $p;
}

sub click_to_tile {
    my ($pin_tile, $pin) = @_;
    $pin -= 256 while $pin > 256;
    $pin += 256 while $pin < 0;
    return $pin_tile + $pin / 256;
}

# Given some click co-ords (the tile they were on, and where in the
# tile they were), convert to WGS84 and return.
sub click_to_wgs84 {
    my ($self, $q, $pin_tile_x, $pin_x, $pin_tile_y, $pin_y) = @_;
    my $tile_x = click_to_tile($pin_tile_x, $pin_x);
    my $tile_y = click_to_tile($pin_tile_y, $pin_y);
    my $zoom = 14 + (defined $q->param('zoom') ? $q->param('zoom') : 2);
    my ($lat, $lon) = tile_to_latlon($tile_x, $tile_y, $zoom);
    return ( $lat, $lon );
}

sub compass ($$$$) {
    my ( $q, $x, $y, $zoom ) = @_;

    my ($lat, $lon) = map { Utils::truncate_coordinate($_) } tile_to_latlon($x, $y-1, $zoom+14);
    my $north = NewURL( $q, lat => $lat, lon => $lon, zoom => $zoom );
    ($lat, $lon) = map { Utils::truncate_coordinate($_) } tile_to_latlon($x, $y+1, $zoom+14);
    my $south = NewURL( $q, lat => $lat, lon => $lon, zoom => $zoom );
    ($lat, $lon) = map { Utils::truncate_coordinate($_) } tile_to_latlon($x-1, $y, $zoom+14);
    my $west = NewURL( $q, lat => $lat, lon => $lon, zoom => $zoom );
    ($lat, $lon) = map { Utils::truncate_coordinate($_) } tile_to_latlon($x+1, $y, $zoom+14);
    my $east = NewURL( $q, lat => $lat, lon => $lon, zoom => $zoom );
    ($lat, $lon) = map { Utils::truncate_coordinate($_) } tile_to_latlon($x, $y, $zoom+14);
    my $zoom_in = $zoom < 3 ? NewURL( $q, lat => $lat, lon => $lon, zoom => $zoom+1 ) : '#';
    my $zoom_out = $zoom > 0 ? NewURL( $q, lat => $lat, lon => $lon, zoom => $zoom-1 ) : '#';
    my $world = NewURL( $q, lat => $lat, lon => $lon, zoom => 0 );

    #my $host = Page::base_url_with_lang( $q, undef );
    my $dir = "/jslib/OpenLayers-2.10/img";
    return <<EOF;
<div style="position: absolute; left: 4px; top: 4px; z-index: 1007;" class="olControlPanZoom olControlNoSelect" unselectable="on">
    <div style="position: absolute; left: 13px; top: 4px; width: 18px; height: 18px;"><a href="$north"><img style="position: relative; width: 18px; height: 18px;" src="$dir/north-mini.png" border="0"></a></div>
    <div style="position: absolute; left: 4px; top: 22px; width: 18px; height: 18px;"><a href="$west"><img style="position: relative; width: 18px; height: 18px;" src="$dir/west-mini.png" border="0"></a></div>
    <div style="position: absolute; left: 22px; top: 22px; width: 18px; height: 18px;"><a href="$east"><img style="position: relative; width: 18px; height: 18px;" src="$dir/east-mini.png" border="0"></a></div>
    <div style="position: absolute; left: 13px; top: 40px; width: 18px; height: 18px;"><a href="$south"><img style="position: relative; width: 18px; height: 18px;" src="$dir/south-mini.png" border="0"></a></div>
    <div style="position: absolute; left: 13px; top: 63px; width: 18px; height: 18px;"><a href="$zoom_in"><img style="position: relative; width: 18px; height: 18px;" src="$dir/zoom-plus-mini.png" border="0"></a></div>
    <div style="position: absolute; left: 13px; top: 81px; width: 18px; height: 18px;"><a href="$world"><img style="position: relative; width: 18px; height: 18px;" src="$dir/zoom-world-mini.png" border="0"></a></div>
    <div style="position: absolute; left: 13px; top: 99px; width: 18px; height: 18px;"><a href="$zoom_out"><img style="position: relative; width: 18px; height: 18px;" src="$dir/zoom-minus-mini.png" border="0"></a></div>
</div>
EOF
}

sub get_object_tags {
    my ($type, $id) = @_;
    my $url = "${osmbase}0.6/$type/$id";
    my $j = LWP::Simple::get($url);
    if ($j) {
        my $ref = XMLin($j);
        my %tags;
        map { $tags{$_->{'k'}} = $_->{'v'} } @{$ref->{$type}->{tag}};
        return \%tags;
    } else {
        print STDERR "No reply from $url\n";
    }
    return undef;
}

1;
