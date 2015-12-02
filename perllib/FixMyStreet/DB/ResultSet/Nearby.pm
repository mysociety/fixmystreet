package FixMyStreet::DB::ResultSet::Nearby;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub to_body {
    my ($rs, $bodies) = @_;
    return FixMyStreet::DB::ResultSet::Problem::to_body($rs, $bodies, 1);
}

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
    $params->{category} = $category if $category;

    $rs = $c->cobrand->problems_restriction($rs);

    my $attrs = {
        prefetch => 'problem',
        bind => [ $mid_lat, $mid_lon, $dist ],
        order_by => [ 'distance', { -desc => 'created' } ],
        rows => $limit,
    };

    my @problems = mySociety::Locale::in_gb_locale { $rs->search( $params, $attrs )->all };
    return \@problems;
}

1;
