use strict;
use warnings;
use Test::More;

use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';

my $mech = Test::WWW::Mechanize::Catalyst->new();
$mech->get_ok('/reports/new');

TODO: {
    local $TODO = "paths to '/reports/new' not handled by catalyst yet";
    fail "Test that clicking on map sends user here";
    fail "Test that clicking on 'skip map' link sends user here";
    fail "Test that partial token sends user here";
}

#### test report creation for a user who does not have an account
# come to site
# fill in report
# recieve token
# confirm token
# report is confirmed
# user is created and logged in


#### test report creation for a user who has account but is not logged in
# come to site
# fill in report
# recieve token
# confirm token
# report is confirmed


#### test report creation for user with account and logged in
# come to site
# fill in report
# report is confirmed


#### test uploading an image

#### test completing a partial report (eq flickr upload)

#### test error cases when filling in a report



done_testing();
