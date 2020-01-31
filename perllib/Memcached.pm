# Memcached.pm:
# Tiny FixMyStreet memcached wrapper

package Memcached;

use strict;
use warnings;
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

1;
