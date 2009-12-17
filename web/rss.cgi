#!/usr/bin/perl -w -I../perllib

# rss.cgi:
# RSS for FixMyStreet
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: rss.cgi,v 1.38 2009-12-17 15:15:21 louise Exp $

use strict;
use Error qw(:try);
use Standard;
use URI::Escape;
use mySociety::Alert;
use mySociety::MaPit;
use mySociety::GeoUtil;
use mySociety::Gaze;

sub main {
    my $q = shift;
    my $type = $q->param('type') || '';
    my $cobrand = Page::get_cobrand($q);
    my $xsl = Cobrand::feed_xsl($cobrand);
    my $out;
    if ($type eq 'local_problems') {
        $out = rss_local_problems($q);
	return unless $out;
    } elsif ($type eq 'new_updates') {
        my $id = $q->param('id');
        my $problem = Problems::fetch_problem($id);
        if (!$problem) {
	   print $q->header(-status=>'404 Not Found',-type=>'text/html');
           return;
        }
        my $qs = 'report/' . $id;
        $out = mySociety::Alert::generate_rss($type, $xsl, $qs, [$id], undef, $cobrand, $q);
    } elsif ($type eq 'new_problems' || $type eq 'new_fixed_problems') {
        $out = mySociety::Alert::generate_rss($type, $xsl, '', undef, undef, $cobrand, $q);
    } elsif ($type eq 'council_problems') {
        my $id = $q->param('id');
        my $qs = '/'.$id;
        $out = mySociety::Alert::generate_rss($type, $xsl, $qs, [$id], undef, $cobrand. $q);
    } elsif ($type eq 'area_problems') {
        my $id = $q->param('id');
        my $va_info = mySociety::MaPit::get_voting_area_info($id);
        my $qs = '/'.$id;
        $out = mySociety::Alert::generate_rss($type, $xsl, $qs, [$id], { NAME => $va_info->{name} }, $cobrand, $q);
    } elsif ($type eq 'all_problems') {
        $out = mySociety::Alert::generate_rss($type, $xsl, '', undef, undef, $cobrand, $q);
    } else {
        my $base = mySociety::Config::get('BASE_URL');
        print $q->redirect($base . '/alert');
        return '';
    }
    print $q->header( -type => 'application/xml; charset=utf-8' );
    print $out;
}
Page::do_fastcgi(\&main);

sub rss_local_problems {
    my $q = shift;
    my $pc = $q->param('pc');
    my $x = $q->param('x');
    my $y = $q->param('y');
    my $lat = $q->param('lat');
    my $lon = $q->param('lon');
    my $cobrand = Page::get_cobrand($q);
    my $base = Cobrand::base_url($cobrand);
    my ($e, $n);
    if ($lat) { # In the UK, it'll never be 0 :)
        ($e, $n) = mySociety::GeoUtil::wgs84_to_national_grid($lat, $lon, 'G');
        $x = int(Page::os_to_tile($e));
        $y = int(Page::os_to_tile($n));
	print $q->redirect(-location => "$base/rss/$x/$y");
	return '';
    } elsif ($x && $y) {
        $e = Page::tile_to_os($x);
        $n = Page::tile_to_os($y);
        ($lat, $lon) = mySociety::GeoUtil::national_grid_to_wgs84($e, $n, 'G');
    } elsif ($pc) {
        my $error;
        try {
            ($x, $y, $e, $n, $error) = Page::geocode($pc, $q);
        } catch Error::Simple with {
            $error = shift;
        };
        unless ($error) {
            print $q->redirect(-location => "$base/rss/$x/$y");
        }
        return '';
    } else {
        die "Missing x/y, lat/lon, or postcode parameter in RSS feed";
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

    my $xsl = Cobrand::feed_xsl($cobrand);
    return mySociety::Alert::generate_rss('local_problems', $xsl, $qs, [$e, $n, $d], undef, $cobrand, $q);
}

