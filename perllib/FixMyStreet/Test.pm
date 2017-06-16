package FixMyStreet::Test;

use parent qw(Exporter);

use strict;
use warnings FATAL => 'all';
use utf8;
use Test::More;
use FixMyStreet::DB;

my $db = FixMyStreet::DB->storage;

sub import {
    strict->import;
    warnings->import(FATAL => 'all');
    utf8->import;
    Test::More->export_to_level(1);
    $db->txn_begin;
}

BEGIN {
    use FixMyStreet;
    FixMyStreet->test_mode(1);
}

END {
    $db->txn_rollback if $db;
}

1;
