# Memcached.pm:
# Tiny FixMyStreet memcached wrapper

package Memcached;

use strict;
use warnings;
use Time::HiRes qw(usleep);
use Cache::Memcached;
use FixMyStreet;

my $memcache;
my $namespace = FixMyStreet->config('FMS_DB_NAME') . ":";
my $server    = FixMyStreet->config('MEMCACHED_HOST') || '127.0.0.1';

sub instance {
    return $memcache //= Cache::Memcached->new({
        'servers' => [ "${server}:11211" ],
        'namespace' => $namespace,
        'debug' => 0,
        'compress_threshold' => 10_000,
    });
}

sub get {
    instance->get(@_);
}

sub set {
    instance->set(@_);
}

sub delete {
    instance->delete(@_);
}

sub increment {
    my $key = shift;
    my $timeout = shift;
    my $count = instance->incr($key);
    if (!defined $count) {
        instance->add($key, 0, $timeout);
        $count = instance->incr($key);
    };
    return $count;
}

sub get_or_calculate {
    my ($key, $expiry, $callback) = @_;
    if (FixMyStreet->test_mode || !instance->get_sock) {
        return $callback->();
    }

    while (!instance->add($key . "_lock", 1, 10)) {
        usleep 100_000;
    }
    my $result = instance->get($key);
    if (!defined($result)) {
        $result = $callback->();
        instance->set($key, $result, $expiry);
    }
    instance->delete($key . "_lock");
    return $result;
}

1;
