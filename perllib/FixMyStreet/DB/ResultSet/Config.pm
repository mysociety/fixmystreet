package FixMyStreet::DB::ResultSet::Config;
use base 'FixMyStreet::DB::ResultSet';

use strict;
use warnings;

sub get {
    my ($rs, $key) = @_;
    my $v = $rs->find($key);
    return $v ? $v->value : undef;
}

sub set {
    my ($rs, $key, $value) = @_;
    my $v = $rs->find($key);
    if ($v) {
        $v->update({ value => $value });
    } else {
        $v = $rs->create({ name => $key, value => $value });
    }
    return $v->value;
}

1;
