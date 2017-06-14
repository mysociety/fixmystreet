use FixMyStreet::Test;
use FixMyStreet::Cobrand;

my @cobrands = (
    [ hart => 2333 ],
    [ oxfordshire  => 2237 ],
    [ stevenage    => 2347 ],
    [ warwickshire => 2243 ],
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ map $_->[0], @cobrands ],
}, sub {

    for my $c (@cobrands) {
        my ($m, $id) = @$c;
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($m);
        my $council_area_id = $cobrand->council_area_id;
        is $council_area_id, $id, "council_area_id for $m";
    }
};

done_testing;
