use FixMyStreet::Test;
use FixMyStreet::Cobrand;

FixMyStreet::override_config {
    COBRAND_FEATURES => {
        foo => { tester => 1 },
        bar => { default => 1 }
    }
}, sub {
    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('default')->new;

    is $cobrand->feature('foo'), undef;
    is $cobrand->feature('bar'), 1;
};

done_testing();
