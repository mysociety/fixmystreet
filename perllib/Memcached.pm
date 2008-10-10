#
# Memcached.pm:
# Trying out memcached on FixMyStreet
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Memcached.pm,v 1.3 2008-10-10 15:57:28 matthew Exp $
#

package Memcached;

use strict;
use Cache::Memcached;

my ($memcache, $namespace);

sub set_namespace {
    $namespace = shift;
    $namespace = 'fms' if $namespace eq 'fixmystreet';
}

sub cache_connect {
    $memcache = new Cache::Memcached {
        'servers' => [ '127.0.0.1:11211' ],
        'namespace' => $namespace,
        'debug' => 0,
        'compress_threshold' => 10_000,
    };
}

sub get {
    cache_connect() unless $memcache;
    $memcache->get(@_);
}

sub set {
    cache_connect() unless $memcache;
    $memcache->set(@_);
}

1;
