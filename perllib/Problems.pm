#!/usr/bin/perl
#
# Problems.pm:
# Various problem report database fetching related functions for FixMyStreet.
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Problems.pm,v 1.3 2008-05-23 09:53:10 matthew Exp $
#

package Problems;

use strict;
use mySociety::DBHandle qw/dbh select_all/;
use mySociety::Web qw/ent/;

my $site_restriction = '';
sub set_site_restriction {
    my $site = shift;
    my @cats = Page::scambs_categories();
    my $cats = join("','", @cats);
    $site_restriction = " and council=2260 and category in
	('$cats') "
        if $site eq 'scambs';
}

# Front page statistics

sub recent_fixed {
    dbh()->selectrow_array("select count(*) from problem
        where state='fixed' and lastupdate>ms_current_timestamp()-'1 month'::interval
        $site_restriction");
}

sub number_comments {
    if ($site_restriction) {
        dbh()->selectrow_array("select count(*) from comment, problem
            where comment.problem_id=problem.id and comment.state='confirmed'
            $site_restriction");
    } else {
        dbh()->selectrow_array("select count(*) from comment
            where state='confirmed'");
    }
}

sub recent_new {
    my $interval = shift;
    dbh()->selectrow_array("select count(*) from problem
        where state in ('confirmed','fixed') and confirmed>ms_current_timestamp()-'$interval'::interval
        $site_restriction");
}

# Front page recent lists

sub recent_photos {
    my ($num, $e, $n, $dist) = @_;
    my $probs;
    if ($e) {
        $probs = select_all("select id, title
            from problem_find_nearby(?, ?, ?) as nearby, problem
            where nearby.problem_id = problem.id
            and state in ('confirmed', 'fixed') and photo is not null
            $site_restriction
            order by confirmed desc limit $num", $e, $n, $dist);
    } else {
        $probs = select_all("select id, title from problem
            where state in ('confirmed', 'fixed') and photo is not null
            $site_restriction
            order by confirmed desc limit $num");
    }
    my $out = '';
    foreach (@$probs) {
        my $title = ent($_->{title});
        $out .= '<a href="/?id=' . $_->{id} .
            '"><img border="0" src="/photo?tn=1;id=' . $_->{id} .
            '" alt="' . $title . '" title="' . $title . '"></a>';
    }
    return $out;
}

sub recent {
    select_all("select id,title from problem
        where state in ('confirmed', 'fixed')
        $site_restriction
        order by confirmed desc limit 5");
}

# Problems around a location

sub current_on_map {
    my ($min_e, $max_e, $min_n, $max_n) = @_;
    select_all(
        "select id,title,easting,northing from problem where state='confirmed'
        and easting>=? and easting<? and northing>=? and northing<?
        $site_restriction
        order by created desc limit 9", $min_e, $max_e, $min_n, $max_n);
}

sub current_nearby {
    my ($dist, $ids, $limit, $mid_e, $mid_n) = @_;
    select_all(
        "select id, title, easting, northing, distance
        from problem_find_nearby(?, ?, $dist) as nearby, problem
        where nearby.problem_id = problem.id
        and state = 'confirmed'" . ($ids ? ' and id not in (' . $ids . ')' : '') . "
        $site_restriction
        order by distance, created desc limit $limit", $mid_e, $mid_n);
}

sub fixed_nearby {
    my ($dist, $mid_e, $mid_n) = @_;
    select_all(
        "select id, title, easting, northing, distance
        from problem_find_nearby(?, ?, $dist) as nearby, problem
        where nearby.problem_id = problem.id and state='fixed'
        $site_restriction
        order by created desc limit 9", $mid_e, $mid_n);
}

# Fetch an individual problem

sub fetch_problem {
    my $id = shift;
    dbh()->selectrow_hashref(
        "select id, easting, northing, council, category, title, detail, (photo is not null) as photo,
        used_map, name, anonymous, extract(epoch from confirmed) as time,
        state, extract(epoch from whensent-confirmed) as whensent,
        extract(epoch from ms_current_timestamp()-lastupdate) as duration
        from problem where id=? and state in ('confirmed','fixed', 'hidden')
        $site_restriction", {}, $id
    );
}

1;
