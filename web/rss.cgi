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
use Encode;
use URI::Escape;
use FixMyStreet::Alert;
use FixMyStreet::Geocode;
use mySociety::MaPit;
use mySociety::Gaze;
use Utils;

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
        $out = FixMyStreet::Alert::generate_rss($type, $xsl, $qs, [$id], undef, $cobrand, $q);
    } elsif ($type eq 'new_problems' || $type eq 'new_fixed_problems') {
        $out = FixMyStreet::Alert::generate_rss($type, $xsl, '', undef, undef, $cobrand, $q);
    } elsif ($type eq 'council_problems') {
        my $id = $q->param('id');
        my $qs = '/'.$id;
        $out = FixMyStreet::Alert::generate_rss($type, $xsl, $qs, [$id], undef, $cobrand. $q);
    } elsif ($type eq 'area_problems') {
        my $id = $q->param('id');
        my $va_info = mySociety::MaPit::call('area', $id);
        my $qs = '/'.$id;
        $out = FixMyStreet::Alert::generate_rss($type, $xsl, $qs, [$id], { NAME => encode_utf8($va_info->{name}) }, $cobrand, $q);
    } elsif ($type eq 'all_problems') {
        $out = FixMyStreet::Alert::generate_rss($type, $xsl, '', undef, undef, $cobrand, $q);
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

    # As a fallback if pc isn't a postcode, let's upper case it.
    my $pretty_pc = uc($pc);
    my $pretty_pc_spaceless;
    if (mySociety::PostcodeUtil::is_valid_postcode($pc)) {
        $pretty_pc = mySociety::PostcodeUtil::canonicalise_postcode($pc);
        $pretty_pc_spaceless = $pretty_pc;
	$pretty_pc_spaceless =~ s/ //g;
    } else {
        $pretty_pc_spaceless = $pretty_pc;
    }
    $pretty_pc_spaceless = URI::Escape::uri_escape_utf8($pretty_pc_spaceless);

    my $x = $q->param('x');
    my $y = $q->param('y');
    my $lat = $q->param('lat');
    my $lon = $q->param('lon');
    my $e = $q->param('e');
    my $n = $q->param('n');
    my $d = $q->param('d') || '';
    $d = '' unless $d =~ /^\d+$/;
    my $d_str = '';
    $d_str = "/$d" if $d;
    my $state = $q->param('state') || 'all';
    $state = 'all' unless $state =~ /^(all|open|fixed)$/;

    # state is getting lost in the redirects. Add it on to the end as a query
    my $state_qs = '';
    $state_qs = "?state=$state" unless $state eq 'all';

    $state = 'confirmed' if $state eq 'open';

    my $qs;
    my %title_params;
    my $alert_type;

    my $cobrand = Page::get_cobrand($q);
    my $base = Cobrand::base_url($cobrand);
    if ($x && $y) {
        # 5000/31 as initial scale factor for these RSS feeds, now variable so redirect.
        $e = int( ($x * 5000/31) + 0.5 );
        $n = int( ($y * 5000/31) + 0.5 );
        ($lat, $lon) = Utils::convert_en_to_latlon_truncated($e, $n);
        print $q->redirect(-location => "$base/rss/l/$lat,$lon$d_str$state_qs");
        return '';
    } elsif ($e && $n) {
        ($lat, $lon) = Utils::convert_en_to_latlon_truncated($e, $n);
        print $q->redirect(-location => "$base/rss/l/$lat,$lon$d_str$state_qs");
        return '';
    } elsif ($pc) {
        my $error;
        try {
            ($lat, $lon, $error) = FixMyStreet::Geocode::lookup($pc, $q);
        } catch Error::Simple with {
            $error = shift;
        };
	if ($error) {
	    return '';
	} else {
            ( $lat, $lon ) = map { Utils::truncate_coordinate($_) } ( $lat, $lon );             
	    $qs = "?pc=$pretty_pc_spaceless";

	    $title_params{'POSTCODE'} = encode_utf8($pretty_pc);
        }
	# pass through rather than redirecting.
    } elsif ( $lat || $lon ) { 
        # pass through
    } else {
        die "Missing E/N, x/y, lat/lon, or postcode parameter in RSS feed";
    }
    
    # truncate the lat,lon for nicer urls
    ( $lat, $lon ) = map { Utils::truncate_coordinate($_) } ( $lat, $lon );    
    
    if (!$qs) {
	$qs = "?lat=$lat;lon=$lon";
    }

    if ($d) {
        $qs .= ";d=$d";
        $d = 100 if $d > 100;
    } else {
        $d = mySociety::Gaze::get_radius_containing_population($lat, $lon, 200000);
        $d = int($d*10+0.5)/10;
    }

    my $xsl = Cobrand::feed_xsl($cobrand);

    if ($pc) {
	$alert_type = 'postcode_local_problems';
    } else {
	$alert_type = 'local_problems';
    }

    my @db_params = ($lat, $lon, $d);

    if ($state ne 'all') {
	$alert_type .= '_state';
	push @db_params, $state;
    }
    
    return FixMyStreet::Alert::generate_rss($alert_type, $xsl, $qs, \@db_params, \%title_params, $cobrand, $q);
}

