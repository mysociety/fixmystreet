package FixMyStreet::DB::ResultSet::Nearby;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub nearby {
    my ( $rs, $c, $dist, $ids, $limit, $mid_lat, $mid_lon, $interval, $category, $states ) = @_;

    unless ( $states ) {
        $states = FixMyStreet::DB::Result::Problem->visible_states();
    }

    my $params = {
        non_public => 0,
        state => [ keys %$states ],
    };
    $params->{'current_timestamp-lastupdate'} = { '<', \"'$interval'::interval" }
        if $interval;
    $params->{id} = { -not_in => $ids }
        if $ids;
    $params = {
        %{ $c->cobrand->problems_clause },
        %$params
    } if $c->cobrand->problems_clause;
    $params->{category} = $category if $category;

    my $attrs = {
        prefetch => 'problem',
        bind => [ $mid_lat, $mid_lon, $dist ],
        order_by => [ 'distance', { -desc => 'created' } ],
        rows => $limit,
    };

    my @problems = mySociety::Locale::in_gb_locale { $rs->search( $params, $attrs )->all };
    return \@problems;
}

# XXX Not currently used, so not migrating at present.
#sub fixed_nearby {
#    my ($dist, $mid_lat, $mid_lon) = @_;
#    mySociety::Locale::in_gb_locale { select_all(
#        "select id, title, latitude, longitude, distance
#        from problem_find_nearby(?, ?, $dist) as nearby, problem
#        where nearby.problem_id = problem.id and state='fixed'
#        site_restriction
#        order by lastupdate desc", $mid_lat, $mid_lon);
#    }
#}

1;
