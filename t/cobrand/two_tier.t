use strict;
use warnings;
use Test::More;

use FixMyStreet;
use FixMyStreet::Cobrand;

my @cobrands = (
    [ hart => '%2333%' ],
    [ oxfordshire  => '%2237%' ],
    [ eastsussex   => '%2224%' ],
    [ stevenage    => '%2347%' ],
    [ warwickshire => '%2243%' ],
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ map $_->[0], @cobrands ],
}, sub {

    for my $c (@cobrands) {
        my ($m, $like) = @$c;
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($m);
        my $problems_clause = $cobrand->problems_clause;
        is_deeply $problems_clause,
            { bodies_str => { like => $like } }, "problems_clause for $m";
    }
};

done_testing;
