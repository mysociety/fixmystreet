package FixMyStreet::DB::ResultSet::Nearby;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub to_body {
    my ($rs, $bodies) = @_;
    return FixMyStreet::DB::ResultSet::Problem::to_body($rs, $bodies, 1);
}

sub nearby {
    my ( $rs, $c, $dist, $ids, $limit, $mid_lat, $mid_lon, $categories, $states, $extra_params ) = @_;

    unless ( $states ) {
        $states = FixMyStreet::DB::Result::Problem->visible_states();
    }

    my $params = {
        state => [ keys %$states ],
    };
    $params->{id} = { -not_in => $ids }
        if $ids;
    $params->{category} = $categories if $categories && @$categories;

    FixMyStreet::DB::ResultSet::Problem->non_public_if_possible($params, $c);

    $rs = $c->cobrand->problems_restriction($rs);

    # Add in any optional extra query parameters
    $params = { %$params, %$extra_params } if $extra_params;

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
