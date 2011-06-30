use strict;
use warnings;

use Test::More;

use FixMyStreet;

# check that all the fields listed in general-example are also present in
# general - helps prevent later test failures due to un-noticed additions to the
# config file.

# This code will bail_out to prevent the test suite proceeding to save time if
# issues are found.

# load the config file and store the contents in a readonly hash

mySociety::Config::set_file( FixMyStreet->path_to("conf/general") );

BAIL_OUT( "Test suite modifies databases so should not be run on live servers" )
    unless mySociety::Config::get('STAGING_SITE', undef);

ok mySociety::Config::get('STAGING_SITE', undef), 'staging server';

done_testing();
