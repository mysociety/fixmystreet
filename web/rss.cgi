#!/usr/bin/perl -w

# rss.cgi:
# RSS for FixMyStreet
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: rss.cgi,v 1.14 2007-06-18 20:11:44 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";
use URI::Escape;

use Page;
use mySociety::Config;
use mySociety::DBHandle qw(dbh);
use mySociety::Alert;
use mySociety::Web;
use mySociety::GeoUtil;
use mySociety::Gaze;

BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../conf/general");
    mySociety::DBHandle::configure(
        Name => mySociety::Config::get('BCI_DB_NAME'),
        User => mySociety::Config::get('BCI_DB_USER'),
        Password => mySociety::Config::get('BCI_DB_PASS'),
        Host => mySociety::Config::get('BCI_DB_HOST', undef),
        Port => mySociety::Config::get('BCI_DB_PORT', undef)
    );
}

sub main {
    my $q = shift;
    my $type = $q->param('type') || '';
    if ($type eq 'local_problems') {
        my $x = $q->param('x');
        my $y = $q->param('y');
        my $lat = $q->param('lat');
        my $lon = $q->param('lon');
        my ($e, $n);
        if ($lat && $lon) {
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
        my $qs = "x=$x;y=$y";

        my $d = $q->param('d');
        if ($d) {
            $qs .= ";d=$d";
            $d = 100 if $d > 100;
        } else {
            $d = mySociety::Gaze::get_radius_containing_population($lat, $lon, 200000);
            $d = int($d*10+0.5)/10;
        }

        mySociety::Alert::generate_rss($type, $qs, $e, $n, $d);
    } elsif ($type eq 'new_updates') {
        my $id = $q->param('id');
        my $qs = 'id='.$id;
        mySociety::Alert::generate_rss($type, $qs, $id);
    } elsif ($type eq 'new_problems') {
        mySociety::Alert::generate_rss($type, '');
    } elsif ($type eq 'council_problems') {
        my $id = $q->param('id');
        my $qs = 'council='.$id;
        mySociety::Alert::generate_rss($type, $qs, $id);
    } elsif ($type eq 'all_problems') {
        mySociety::Alert::generate_rss($type, '');
    } else {
        throw Error::Simple('Unknown alert type') unless $type;
    }
    dbh()->rollback();
}
Page::do_fastcgi(\&main);

