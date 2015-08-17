use strict;
use warnings;
use Test::More;

use FixMyStreet;
use FixMyStreet::Cobrand;

my @cobrands = (
    [ hart => 2333 ],
    [ oxfordshire  => 2237 ],
    [ eastsussex   => 2224 ],
    [ stevenage    => 2347 ],
    [ warwickshire => 2243 ],
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ map $_->[0], @cobrands ],
}, sub {

    for my $c (@cobrands) {
        my ($m, $id) = @$c;
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($m);
        my $body_restriction = $cobrand->body_restriction;
        is $body_restriction, $id, "body_restriction for $m";
    }
};

done_testing;
