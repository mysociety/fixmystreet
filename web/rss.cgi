#!/usr/bin/perl -w -I../perllib

# rss.cgi:
# RSS for FixMyStreet
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: rss.cgi,v 1.18 2007-08-29 23:03:16 matthew Exp $

use strict;
use Standard;
use URI::Escape;
use mySociety::Alert;
use mySociety::MaPit;
use mySociety::Web;
use mySociety::GeoUtil;
use mySociety::Gaze;

sub main {
    my $q = shift;
    my $type = $q->param('type') || '';
    if ($type eq 'local_problems') {
        rss_local_problems($q);
    } elsif ($type eq 'new_updates') {
        my $id = $q->param('id');
        my $qs = '?id='.$id;
        mySociety::Alert::generate_rss($type, $qs, [$id]);
    } elsif ($type eq 'new_problems') {
        mySociety::Alert::generate_rss($type, '');
    } elsif ($type eq 'council_problems') {
        my $id = $q->param('id');
        my $qs = '/'.$id;
        mySociety::Alert::generate_rss($type, $qs, [$id]);
    } elsif ($type eq 'area_problems') {
        my $id = $q->param('id');
        my $va_info = mySociety::MaPit::get_voting_area_info($id);
        my $qs = '/'.$id;
        mySociety::Alert::generate_rss($type, $qs, [$id], { NAME => $va_info->{name} });
    } elsif ($type eq 'all_problems') {
        mySociety::Alert::generate_rss($type, '');
    } else {
        throw Error::Simple('Unknown alert type') unless $type;
    }
}
Page::do_fastcgi(\&main);

sub rss_local_problems {
    my $q = shift;
    my $x = $q->param('x');
    my $y = $q->param('y');
    my $lat = $q->param('lat');
    my $lon = $q->param('lon');
    my ($e, $n);
    if ($lat) { # In the UK, it'll never be 0 :)
        ($e, $n) = mySociety::GeoUtil::wgs84_to_national_grid($lat, $lon, 'G');
        $x = Page::os_to_tile($e);
        $y = Page::os_to_tile($n);
    } elsif ($x && $y) {
        $e = Page::tile_to_os($x);
        $n = Page::tile_to_os($y);
        ($lat, $lon) = mySociety::GeoUtil::national_grid_to_wgs84($e, $n, 'G');
    } else {
        die "Missing x/y or lat/lon parameter in RSS feed";
    }
    my $qs = "?x=$x;y=$y";
    my $d = $q->param('d');
    if ($d) {
        $qs .= ";d=$d";
        $d = 100 if $d > 100;
    } else {
        $d = mySociety::Gaze::get_radius_containing_population($lat, $lon, 200000);
        $d = int($d*10+0.5)/10;
    }
    mySociety::Alert::generate_rss('local_problems', $qs, [$e, $n, $d]);
}

