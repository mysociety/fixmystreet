use strict;
use warnings;

use Test::More;

use FixMyStreet;

# check that we are running on staging

BAIL_OUT( "Test suite modifies databases so should not be run on live servers" )
    unless FixMyStreet->config('STAGING_SITE');

my $staging = FixMyStreet->config('STAGING_SITE');
ok $staging, 'staging server';

done_testing();
