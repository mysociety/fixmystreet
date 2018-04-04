#
# Memcached.pm:
# Trying out memcached on FixMyStreet
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package Memcached;

use strict;
use warnings;
use Cache::Memcached;

my ($memcache, $namespace);

sub set_namespace {
    $namespace = shift;
}

sub instance {
    return $memcache //= Cache::Memcached->new({
        'servers' => [ '127.0.0.1:11211' ],
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

1;
