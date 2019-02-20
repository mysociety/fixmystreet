package FixMyStreet::DB::ResultSet::Nearby;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub to_body {
    my ($rs, $bodies) = @_;
    return FixMyStreet::DB::ResultSet::Problem::to_body($rs, $bodies, 1);
}

sub nearby {
    my ( $rs, $c, %args ) = @_;

    unless ( $args{states} ) {
        $args{states} = FixMyStreet::DB::Result::Problem->visible_states();
    }

    my $params = {
        state => [ keys %{$args{states}} ],
    };
    $params->{id} = { -not_in => $args{ids} }
        if $args{ids};
    $params->{category} = $args{categories} if $args{categories} && @{$args{categories}};

    $params->{$c->stash->{report_age_field}} = { '>=', \"current_timestamp-'$args{report_age}'::interval" }
        if $args{report_age};

    FixMyStreet::DB::ResultSet::Problem->non_public_if_possible($params, $c);

    $rs = $c->cobrand->problems_restriction($rs);

    # Add in any optional extra query parameters
    $params = { %$params, %{$args{extra}} } if $args{extra};

    my $attrs = {
        prefetch => 'problem',
        bind => [ $args{latitude}, $args{longitude}, $args{distance} ],
        order_by => [ 'distance', { -desc => 'created' } ],
        rows => $args{limit},
    };

    my @problems = mySociety::Locale::in_gb_locale { $rs->search( $params, $attrs )->all };
    return \@problems;
}

1;
