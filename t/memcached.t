use strict;
use warnings;
use Test::More;

use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

use Memcached;

my $call_count = 0;
my $callback = sub {
    $call_count++;
    return "test_value_$call_count";
};

# Test that get_or_calculate always runs the callback in test mode
my $result1 = Memcached::get_or_calculate('test_key', 3600, $callback);
is($result1, 'test_value_1', 'callback was called and returned expected value');
is($call_count, 1, 'callback was called once');

# In test mode, calling again with the same key should run the callback again
# (not use cached value), ensuring fresh data in tests
my $result2 = Memcached::get_or_calculate('test_key', 3600, $callback);
is($result2, 'test_value_2', 'callback was called again with same key');
is($call_count, 2, 'callback was called twice - cache bypassed in test mode');

done_testing();
