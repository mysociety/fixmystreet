package FixMyStreet::DB::ResultSet::Config;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub get_value {
    my $rs = shift;
    my $key = shift;
    my $mc_key = "$key";

    my $result = Memcached::get($mc_key);
    unless ( $result ) {
        my $r = $rs->find( { key => $key } );
        if ( $r ) {
            $result = $r->value;
            Memcached::set($mc_key, $result, 3600);
            return $result;
        }
    }
    return undef;
}

1;
