#
# Memcached.pm:
# Trying out memcached on FixMyStreet
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Memcached.pm,v 1.1 2008-09-16 15:45:09 matthew Exp $
#

package Memcached;

use strict;
use Cache::Memcached;

my $memcache = new Cache::Memcached {
    'servers' => [ '127.0.0.1:11211' ],
    'namespace' => 'fms',
    'debug' => 0,
    'compress_threshold' => 10_000,
};

sub get {
    $memcache->get(@_);
}

sub set {
    $memcache->set(@_);
}

1;
