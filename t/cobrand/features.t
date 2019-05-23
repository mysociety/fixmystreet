use FixMyStreet::Test;
use FixMyStreet::Cobrand;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['bromley'],
    COBRAND_FEATURES => {
        foo => { tester => 1 },
        bar => { default => 1 },
        suggest_duplicates => { bromley => 1 },
    }
}, sub {
    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('default')->new;
    my $bromley = FixMyStreet::Cobrand->get_class_for_moniker('bromley')->new;

    is $cobrand->feature('foo'), undef;
    is $cobrand->feature('bar'), 1;
    is $bromley->suggest_duplicates, 1;
};

done_testing();
