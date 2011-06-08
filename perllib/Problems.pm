#!/usr/bin/perl
#
# Problems.pm:
# Various problem report database fetching related functions for FixMyStreet.
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Problems.pm,v 1.33 2010-01-20 11:09:45 matthew Exp $
#

package Problems;

use strict;
use Encode;
use Memcached;
use mySociety::DBHandle qw/dbh select_all/;
use mySociety::Locale;
use mySociety::Web qw/ent/;
use mySociety::MaPit;

my $site_restriction = '';
my $site_key = 0;

sub current_timestamp {
    my $current_timestamp = dbh()->selectrow_array('select ms_current_timestamp()');
    return "'$current_timestamp'::timestamp";
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

# Front page recent lists

sub recent_photos {
    my ($num, $lat, $lon, $dist) = @_;
    my $probs;
    if (defined $lat) {
        my $dist2 = $dist; # Create a copy of the variable to stop it being stringified into a locale in the next line!
        my $key = "recent_photos:$site_key:$num:$lat:$lon:$dist2";
        $probs = Memcached::get($key);
        unless ($probs) {
            $probs = mySociety::Locale::in_gb_locale {
                select_all("select id, title
                from problem_find_nearby(?, ?, ?) as nearby, problem
                where nearby.problem_id = problem.id
                and state in ('confirmed', 'fixed') and photo is not null
                $site_restriction
                order by confirmed desc limit $num", $lat, $lon, $dist);
            };
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

# Problems around a location

sub around_map {
    my ($min_lat, $max_lat, $min_lon, $max_lon, $interval, $limit) = @_;
    my $limit_clause = '';
    if ($limit) {
        $limit_clause = " limit $limit";
    }
    mySociety::Locale::in_gb_locale { select_all(
        "select id,title,latitude,longitude,state,
             extract(epoch from confirmed) as time
        from problem
        where state in ('confirmed', 'fixed')
            and latitude>=? and latitude<? and longitude>=? and longitude<? " .
        ($interval ? " and ms_current_timestamp()-lastupdate < '$interval'::interval" : '') .
        " $site_restriction
        order by created desc
        $limit_clause", $min_lat, $max_lat, $min_lon, $max_lon);
    };
}

sub nearby {
    my ($dist, $ids, $limit, $mid_lat, $mid_lon, $interval) = @_;
    mySociety::Locale::in_gb_locale { select_all(
        "select id, title, latitude, longitude, distance, state,
            extract(epoch from confirmed) as time
        from problem_find_nearby(?, ?, $dist) as nearby, problem
        where nearby.problem_id = problem.id " .
        ($interval ? " and ms_current_timestamp()-lastupdate < '$interval'::interval" : '') .
        " and state in ('confirmed', 'fixed')" . ($ids ? ' and id not in (' . $ids . ')' : '') . "
        $site_restriction
        order by distance, created desc limit $limit", $mid_lat, $mid_lon);
    }
}

sub fixed_nearby {
    my ($dist, $mid_lat, $mid_lon) = @_;
    mySociety::Locale::in_gb_locale { select_all(
        "select id, title, latitude, longitude, distance
        from problem_find_nearby(?, ?, $dist) as nearby, problem
        where nearby.problem_id = problem.id and state='fixed'
        $site_restriction
        order by lastupdate desc", $mid_lat, $mid_lon);
    }
}

# Fetch an individual problem

sub fetch_problem {
    my $id = shift;
    my $p = dbh()->selectrow_hashref(
        "select id, latitude, longitude, council, category, title, detail, photo,
        used_map, name, anonymous, extract(epoch from confirmed) as time,
        state, extract(epoch from whensent-confirmed) as whensent,
        extract(epoch from ms_current_timestamp()-lastupdate) as duration, 
        service, cobrand, cobrand_data, external_body
        from problem where id=? and state in ('confirmed','fixed', 'hidden')
        $site_restriction", {}, $id
    );
    $p->{service} =~ s/_/ /g if $p && $p->{service};
    return $p;
}

# Report functions

=item council_problems WARD COUNCIL

Returns a list of problems for a summary page. If WARD or COUNCIL area ids are given, 
will only return problems for that area. Uses any site restriction defined by the 
cobrand.

=cut

sub council_problems {
    my ($ward, $one_council) = @_;
    my @params;
    my $where_extra = '';
    if ($ward) {
        push @params, $ward;
        $where_extra = "and areas like '%,'||?||',%'";
    } elsif ($one_council) {
        push @params, $one_council;
        $where_extra = "and areas like '%,'||?||',%'";
    }
    my $current_timestamp = current_timestamp();
    my $problems = select_all(
        "select id, title, detail, council, state, areas,
        extract(epoch from $current_timestamp-lastupdate) as duration,
        extract(epoch from $current_timestamp-confirmed) as age
        from problem
        where state in ('confirmed', 'fixed')
        $where_extra
        $site_restriction
        order by id desc
    ", @params);
    return $problems;
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
    my $problems = select_all("select problem.id, council, category, title, problem.name,
                               email, anonymous, cobrand, cobrand_data, created, confirmed, state, service, lastupdate,
                               whensent, send_questionnaire from problem, users where problem.user_id = users.id
                               and (problem.id=? or email ilike '%'||?||'%' or problem.name ilike '%'||?||'%' or title ilike '%'||?||'%' or
                               detail ilike '%'||?||'%' or council like '%'||?||'%' or cobrand_data like '%'||?||'%')
                               $site_restriction 
                               order by (state='hidden'),created", $search_n,
                               $search, $search, $search, $search, $search, $search);
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
    my $updates = select_all("select comment.*, problem.council, problem.state as problem_state
        from comment, problem, users where problem.id = comment.problem_id and comment.user_id = users.id
            and (comment.id=? or
            problem_id=? or users.email ilike '%'||?||'%' or comment.name ilike '%'||?||'%' or
            comment.text ilike '%'||?||'%' or comment.cobrand_data ilike '%'||?||'%')
            $site_restriction
            order by (comment.state='hidden'),(problem.state='hidden'),created", $search_n, $search_n, $search, $search,
            $search, $search);
    return $updates;
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

=item questionnaire_counts

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
    return $questionnaires;
}

=item contact_counts COBRAND

An array reference of contacts. Restricted to contacts relevant to 
the cobrand if a cobrand is specified.

=cut 
sub contact_counts {
    my ( $c ) = @_;
    my $contact_restriction = $c->cobrand->contact_restriction;
    my $contacts = dbh()->selectcol_arrayref("select confirmed, count(*) as c from contacts $contact_restriction group by confirmed", { Columns => [1,2] });
    return $contacts; 
}

=item admin_fetch_problem ID

Return an array reference of data relating to a problem, to be used in the admin interface. 
Uses any site_restriction defined by a cobrand.

=cut

sub admin_fetch_problem {
    my ($id) = @_;
    my $problem = dbh()->selectall_arrayref("select problem.*, users.email from problem, users
                                             where problem.id=? and users.id = problem.user_id
                                             $site_restriction", { Slice=>{} }, $id);
    return $problem;
}

=item admin_fetch_update ID

Return an array reference of data relating to an update, to be used in the admin interface. 
Uses any site_restriction defined by a cobrand.

=cut
sub admin_fetch_update {
    my ($id) = @_;
    my $update = dbh()->selectall_arrayref("select comment.*, problem.council, users.email from comment, problem, users
                                            where comment.id=? 
                                            and problem.id = comment.problem_id 
                                            and users.id = comment.user_id
                                            $site_restriction", { Slice=>{} }, $id);
    return $update; 
}

=item timeline_problems

Return a reference to an array of problems suitable for display in the admin timeline.
Uses any site_restriction defined by a cobrand.
=cut
sub timeline_problems {
    my $current_timestamp = current_timestamp();
    my $problems = select_all("select state,problem.id,problem.name,users.email,title,council,category,service,cobrand,cobrand_data,
                               extract(epoch from created) as created,
                               extract(epoch from confirmed) as confirmed,
                               extract(epoch from whensent) as whensent
                               from problem, users
                               where problem.user_id = users.id
                               and (created>=$current_timestamp-'7 days'::interval
                               or confirmed>=$current_timestamp-'7 days'::interval
                               or whensent>=$current_timestamp-'7 days'::interval)
                               $site_restriction");
    return $problems;

}

=item timeline_updates

Return a reference to an array of updates suitable for display in the admin timeline.
Uses any site_restriction defined by a cobrand.

=cut

sub timeline_updates {
    my $updates = select_all("select comment.*,
                              extract(epoch from comment.created) as created, 
                              users.email,
                              problem.council
                              from comment, problem, users 
                              where comment.problem_id = problem.id 
                              and comment.user_id = users.id
                              and comment.state='confirmed' 
                              and comment.created>=" . current_timestamp() . "-'7 days'::interval
                              $site_restriction");
    return $updates;
}

=item timeline_alerts COBRAND

Return a reference to an array of alerts suitable for display in the admin timeline. Restricted to 
cobranded alerts if a cobrand is specified.

=cut
sub timeline_alerts {
    my ($cobrand) = @_;
    my $cobrand_clause = '';
    if ($cobrand) {
         $cobrand_clause = " and cobrand = '$cobrand'";
    }
    my $alerts = select_all("select alert.*, users.email, users.name,
                             extract(epoch from whensubscribed) as whensubscribed
                             from alert, users
                             where alert.user_id = users.id
                             and whensubscribed>=" . current_timestamp() . "-'7 days'::interval
                             and confirmed=1
                             $cobrand_clause");
    return $alerts; 

}

=item timeline_deleted_alerts COBRAND

Return a reference to an array of deleted alerts suitable for display in the admin timeline. Restricted to
cobranded alerts if a cobrand is specified.

=cut
sub timeline_deleted_alerts {
    my ($cobrand) = @_;
    my $cobrand_clause = '';
    if ($cobrand) {
         $cobrand_clause = " and cobrand = '$cobrand'";
    }

    my $alerts = select_all("select *,
                             extract(epoch from whensubscribed) as whensubscribed,
                             extract(epoch from whendisabled) as whendisabled
                             from alert where whendisabled>=" . current_timestamp() . "-'7 days'::interval
                             $cobrand_clause");
    return $alerts;

}

=item timeline_questionnaires

Return a reference to an array of questionnaires suitable for display in the admin timeline. Restricted to 
questionnaires for cobranded problems if a cobrand is specified.

=cut

sub timeline_questionnaires {
    my ($cobrand) = @_;
    my $cobrand_clause = '';
    if ($cobrand) {
         $cobrand_clause = " and cobrand = '$cobrand'";
    }
    my $current_timestamp = current_timestamp();
    my $questionnaire = select_all("select questionnaire.*,
                                    extract(epoch from questionnaire.whensent) as whensent,
                                    extract(epoch from questionnaire.whenanswered) as whenanswered
                                    from questionnaire, problem
                                    where questionnaire.problem_id = problem.id 
                                    and (questionnaire.whensent>=$current_timestamp-'7 days'::interval
                                    or questionnaire.whenanswered>=$current_timestamp-'7 days'::interval)
                                    $cobrand_clause");
}

1;
