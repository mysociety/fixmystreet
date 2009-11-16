#!/usr/bin/perl
#
# Problems.pm:
# Various problem report database fetching related functions for FixMyStreet.
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Problems.pm,v 1.25 2009-11-16 10:55:42 louise Exp $
#

package Problems;

use strict;
use Memcached;
use mySociety::DBHandle qw/dbh select_all/;
use mySociety::Locale;
use mySociety::Web qw/ent/;
use mySociety::MaPit;

my $site_restriction = '';
my $site_key = 0;

sub set_site_restriction {
    my $q = shift;
    my $site = $q->{site};
    if ($site ne 'fixmystreet'){
        ($site_restriction, $site_key) = Cobrand::set_site_restriction($q);
    } else {
        $site_restriction = '';
        $site_key = 0;
    }
}

# Front page statistics

sub recent_fixed {
    my $key = "recent_fixed:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = dbh()->selectrow_array("select count(*) from problem
            where state='fixed' and lastupdate>ms_current_timestamp()-'1 month'::interval
            $site_restriction");
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

sub number_comments {
    my $key = "number_comments:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        if ($site_restriction) {
            $result = dbh()->selectrow_array("select count(*) from comment, problem
                where comment.problem_id=problem.id and comment.state='confirmed'
                $site_restriction");
        } else {
            $result = dbh()->selectrow_array("select count(*) from comment
                where state='confirmed'");
        }
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

sub recent_new {
    my $interval = shift;
    (my $key = $interval) =~ s/\s+//g;
    $key = "recent_new:$site_key:$key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = dbh()->selectrow_array("select count(*) from problem
            where state in ('confirmed','fixed') and confirmed>ms_current_timestamp()-'$interval'::interval
            $site_restriction");
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

# Front page recent lists

sub recent_photos {
    my ($num, $e, $n, $dist) = @_;
    my $probs;
    if ($e) {
        my $key = "recent_photos:$site_key:$num:$e:$n:$dist";
        $probs = Memcached::get($key);
        unless ($probs) {
            $probs = select_all("select id, title
                from problem_find_nearby(?, ?, ?) as nearby, problem
                where nearby.problem_id = problem.id
                and state in ('confirmed', 'fixed') and photo is not null
                $site_restriction
                order by confirmed desc limit $num", $e, $n, $dist);
            Memcached::set($key, $probs, 3600);
        }
    } else {
        my $key = "recent_photos:$site_key:$num";
        $probs = Memcached::get($key);
        unless ($probs) {
            $probs = select_all("select id, title from problem
                where state in ('confirmed', 'fixed') and photo is not null
                $site_restriction
                order by confirmed desc limit $num");
            Memcached::set($key, $probs, 3600);
        }
    }
    my $out = '';
    foreach (@$probs) {
        my $title = ent($_->{title});
        $out .= '<a href="/report/' . $_->{id} .
            '"><img border="0" height="100" src="/photo?tn=1;id=' . $_->{id} .
            '" alt="' . $title . '" title="' . $title . '"></a>';
    }
    return $out;
}

sub recent {
    my $key = "recent:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = select_all("select id,title from problem
            where state in ('confirmed', 'fixed')
            $site_restriction
            order by confirmed desc limit 5");
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

sub front_stats {
    my ($q) = @_;
    my $fixed = Problems::recent_fixed();
    my $updates = Problems::number_comments();
    my $new = Problems::recent_new('1 week');
    (my $new_pretty = $new) =~ s/(?<=\d)(?=(?:\d\d\d)+$)/,/g;
    my $new_text = sprintf(mySociety::Locale::nget('<big>%s</big> report in past week',
        '<big>%s</big> reports in past week', $new), $new_pretty);
    if ($q->{site} ne 'emptyhomes' && $new > $fixed) {
        $new = Problems::recent_new('3 days');
        ($new_pretty = $new) =~ s/(?<=\d)(?=(?:\d\d\d)+$)/,/g;
        $new_text = sprintf(mySociety::Locale::nget('<big>%s</big> report recently', '<big>%s</big> reports recently', $new), $new_pretty);
    }
    (my $fixed_pretty = $fixed) =~ s/(?<=\d)(?=(?:\d\d\d)+$)/,/g;
    (my $updates_pretty = $updates) =~ s/(?<=\d)(?=(?:\d\d\d)+$)/,/g;

    my $out = '';
    $out .= $q->h2(_('FixMyStreet updates'));
    my $lastmo = '';
    if ($q->{site} ne 'emptyhomes'){
          $lastmo = $q->div(sprintf(mySociety::Locale::nget("<big>%s</big> fixed in past month", "<big>%s</big> fixed in past month", $fixed), $fixed), $fixed_pretty);
    }
    $out .= $q->div({-id => 'front_stats'},
                    $q->div($new_text),
                    ($q->{site} ne 'emptyhomes' ? $q->div(sprintf(mySociety::Locale::nget("<big>%s</big> fixed in past month", "<big>%s</big> fixed in past month", $fixed), $fixed_pretty)) : ''),
                    $q->div(sprintf(mySociety::Locale::nget("<big>%s</big> update on reports",
                    "<big>%s</big> updates on reports", $updates), $updates_pretty))
    );
    return $out;

}

# Problems around a location

sub around_map {
    my ($min_e, $max_e, $min_n, $max_n, $interval, $limit) = @_;
    my $limit_clause = '';
    if ($limit) {
        $limit_clause = " limit $limit";
    }
    mySociety::Locale::in_gb_locale { select_all(
        "select id,title,easting,northing,state from problem
        where state in ('confirmed', 'fixed')
            and easting>=? and easting<? and northing>=? and northing<? " .
        ($interval ? " and ms_current_timestamp()-lastupdate < '$interval'::interval" : '') .
        " $site_restriction
        order by created desc
        $limit_clause", $min_e, $max_e, $min_n, $max_n);
    };
}

sub nearby {
    my ($dist, $ids, $limit, $mid_e, $mid_n, $interval) = @_;
    mySociety::Locale::in_gb_locale { select_all(
        "select id, title, easting, northing, distance, state
        from problem_find_nearby(?, ?, $dist) as nearby, problem
        where nearby.problem_id = problem.id " .
        ($interval ? " and ms_current_timestamp()-lastupdate < '$interval'::interval" : '') .
        " and state in ('confirmed', 'fixed')" . ($ids ? ' and id not in (' . $ids . ')' : '') . "
        $site_restriction
        order by distance, created desc limit $limit", $mid_e, $mid_n);
    }
}

sub fixed_nearby {
    my ($dist, $mid_e, $mid_n) = @_;
    mySociety::Locale::in_gb_locale { select_all(
        "select id, title, easting, northing, distance
        from problem_find_nearby(?, ?, $dist) as nearby, problem
        where nearby.problem_id = problem.id and state='fixed'
        $site_restriction
        order by lastupdate desc", $mid_e, $mid_n);
    }
}

# Fetch an individual problem

sub fetch_problem {
    my $id = shift;
    dbh()->selectrow_hashref(
        "select id, easting, northing, council, category, title, detail, photo,
        used_map, name, anonymous, extract(epoch from confirmed) as time,
        state, extract(epoch from whensent-confirmed) as whensent,
        extract(epoch from ms_current_timestamp()-lastupdate) as duration, service
        from problem where id=? and state in ('confirmed','fixed', 'hidden')
        $site_restriction", {}, $id
    );
}

# API functions

sub problems_matching_criteria{
    my ($criteria) = @_;
    my $problems = select_all(
        "select id, title, council, category, detail, name, anonymous,
        confirmed, whensent, service
        from problem
        $criteria
	$site_restriction");

    my @councils;
    foreach my $problem (@$problems){
        if ($problem->{anonymous} == 1){
            $problem->{name} = '';
        }
	if ($problem->{service} eq ''){
            $problem->{service} = 'Web interface';
        }
        if ($problem->{council}) {
            $problem->{council} =~ s/\|.*//g;
	    my @council_ids = split /,/, $problem->{council};
            push(@councils, @council_ids);
	    $problem->{council} = \@council_ids;
	}
    }
    my $areas_info = mySociety::MaPit::get_voting_areas_info(\@councils);
    foreach my $problem (@$problems){
    	if ($problem->{council}) {
             my @council_names = map { $areas_info->{$_}->{name}} @{$problem->{council}} ;
	     $problem->{council} = join(' and ', @council_names);
    	}
    }
    return $problems;
}

sub fixed_in_interval {
    my ($start_date, $end_date) = @_; 
    my $criteria = "where state='fixed' and date_trunc('day',lastupdate)>='$start_date' and 
date_trunc('day',lastupdate)<='$end_date'";
    return problems_matching_criteria($criteria);
}

sub created_in_interval {
    my ($start_date, $end_date) = @_; 
    my $criteria = "where state='confirmed' and date_trunc('day',created)>='$start_date' and 
date_trunc('day',created)<='$end_date'";
    return problems_matching_criteria($criteria);
}

=item data_sharing_notification_start

Returns the unix datetime when the T&Cs that explicitly allow for users' data to be displayed
on other sites.

=cut

sub data_sharing_notification_start {
    return 1255392000;
}


# Admin view functions

=item problem_search SEARCH

Returns all problems containing the search term in their name, email, title, 
detail or council, or whose ID is the search term. Uses any site_restriction
defined by a cobrand. 

=cut
sub problem_search {
    my ($search) = @_;
    my $search_n = 0;
    $search_n = int($search) if $search =~ /^\d+$/;
    my $problems = select_all("select id, council, category, title, name,
                               email, anonymous, cobrand, cobrand_data, created, confirmed, state, service, lastupdate,
                               whensent, send_questionnaire from problem where (id=? or email ilike
                               '%'||?||'%' or name ilike '%'||?||'%' or title ilike '%'||?||'%' or
                               detail ilike '%'||?||'%' or council like '%'||?||'%')
                               $site_restriction 
                               order by created", $search_n,
                               $search, $search, $search, $search, $search);
    return $problems; 
}

=item update_search SEARCH 

Returns all updates containing the search term in their name, email or text, or whose ID 
is the search term. Uses any site_restriction defined by a cobrand. 

=cut
sub update_search { 
    my ($search) = @_;
    my $search_n = 0;
    $search_n = int($search) if $search =~ /^\d+$/;
    my $updates = select_all("select comment.* from comment, problem where problem.id = comment.problem_id
            and (comment.id=? or
            problem_id=? or comment.email ilike '%'||?||'%' or comment.name ilike '%'||?||'%' or
            comment.text ilike '%'||?||'%')
            $site_restriction
            order by created", $search_n, $search_n, $search, $search,
            $search);
}

=item update_counts

An array reference of updates grouped by state. Uses any site_restriction defined by a cobrand.

=cut 

sub update_counts {
    return dbh()->selectcol_arrayref("select comment.state, count(comment.*) as c from comment, problem 
                                      where problem.id = comment.problem_id 
                                      $site_restriction 
                                      group by comment.state", { Columns => [1,2] });
}

=item problem_counts

An array reference of problems grouped by state. Uses any site_restriction defined by a cobrand.

=cut

sub problem_counts {
    return dbh()->selectcol_arrayref("select state, count(*) as c from problem 
                                      where id=id $site_restriction
                                      group by state", { Columns => [1,2] });
}

=item 

An array reference of alerts grouped by state (specific to the cobrand if there is one).

=cut

sub alert_counts {
    my ($cobrand) = @_;
    my $cobrand_clause = '';
    if ($cobrand) {
         $cobrand_clause = " where cobrand = '$cobrand'";
    }
    return dbh()->selectcol_arrayref("select confirmed, count(*) as c 
                               from alert 
                               $cobrand_clause
                               group by confirmed", { Columns => [1,2] });
}

=item

An array reference of questionnaires. Restricted to questionnaires related to 
problems submitted through the cobrand if a cobrand is specified. 

=cut
sub questionnaire_counts {
    my ($cobrand) = @_;
    my $cobrand_clause = '';
    if ($cobrand) {
         $cobrand_clause = " and cobrand = '$cobrand'";
    }
    my $questionnaires = dbh()->selectcol_arrayref("select (whenanswered is not null), count(questionnaire.*) as c 
                                                    from questionnaire, problem
                                                    where problem.id = questionnaire.problem_id 
                                                    $cobrand_clause
                                                    group by (whenanswered is not null)", { Columns => [1,2] }); 
}

1;
