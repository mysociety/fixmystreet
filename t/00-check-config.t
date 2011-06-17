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

mySociety::Config::set_file( FixMyStreet->path_to("conf/general-example") );
my $example_config = mySociety::Config::get_list();
mySociety::Config::set_file( FixMyStreet->path_to("conf/general") );
my $local_config = mySociety::Config::get_list();

# find all keys missing from each config
my @missing_from_example = find_missing( $example_config, $local_config );
my @missing_from_local   = find_missing( $local_config,   $example_config );

if ( @missing_from_example || @missing_from_local ) {

    fail "Missing from 'general': $_"         for @missing_from_local;
    fail "Missing from 'general-example': $_" for @missing_from_example;

    # bail out to prevent other tests failing due to config issues
    BAIL_OUT( "Config has changed"
          . " - update your 'general' and add/remove the keys listed above" );
}
else {
    pass "configs contain the same keys";
}

done_testing();

sub find_missing {
    my $reference = shift;
    my $config    = shift;
    my @missing   = ();

    foreach my $key ( sort keys %$config ) {
        push @missing, $key unless exists $reference->{$key};
    }

    return @missing;
}
