use strict;
use warnings;

use Test::More;

use FixMyStreet::App;

# check that all the fields listed in general-example are also present in
# general - helps prevent later test failures due to un-noticed additions to the
# config file.

# This code will bail_out to prevent the test suite proceeding to save time if
# issues are found.

# load the config file and store the contents in a readonly hash

my $staging = FixMyStreet::App->get_conf( 'STAGING_SITE' );

BAIL_OUT( "Test suite modifies databases so should not be run on live servers" )
    unless $staging;

ok $staging, 'staging server';

done_testing();
