use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use Web::Scraper;

my $mech = FixMyStreet::TestMech->new;
$mech->get_ok('/reports/new');

# TODO: {
#     local $TODO = "paths to '/reports/new' not handled by catalyst yet";
#     fail "Test that clicking on map sends user here";
#     fail "Test that clicking on 'skip map' link sends user here";
#     fail
#       "Test that clicking on 'Report a Problem' in header link sends user here";
#     fail "Test that partial token sends user here";
# }

# test various locations on inital search box
foreach my $test (
    {
        pc              => '',    #
        errors          => [],
        pc_alternatives => [],
    },
    {
        pc              => 'xxxxxxxxxxxxxxxxxxxxxxxxxxx',
        errors          => ['Sorry, we could not find that location.'],
        pc_alternatives => [],
    },
    {
        pc => 'ZZ9 9ZZ',
        errors =>
          ['We had a problem with the supplied co-ordinates - outside the UK?'],
        pc_alternatives => [],
    },
    {
        pc              => 'glenthorpe',
        errors          => [],
        pc_alternatives => [
            'Glenthorpe Crescent, Leeds LS9 7, UK',
            'Glenthorpe Rd, Merton, Greater London SM4 4, UK',
            'Glenthorpe Ln, Katy, TX 77494, USA',
            'Glenthorpe Dr, Walnut, CA 91789, USA',
            'Glenthorpe Ave, Leeds LS9 7, UK',
            'Glenthorpe Ct, Katy, TX 77494, USA',
        ],
    },
    {
        pc => 'Glenthorpe Ct, Katy, TX 77494, USA',
        errors =>
          ['We had a problem with the supplied co-ordinates - outside the UK?'],
        pc_alternatives => [],
    },
  )
{
    $mech->get_ok('/reports/new');
    $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
        "bad location" );
    is_deeply $mech->form_errors, $test->{errors},
      "expected errors for pc '$test->{pc}'";
    is_deeply $mech->pc_alternatives, $test->{pc_alternatives},
      "expected alternatives for pc '$test->{pc}'";
}

# check that exact queries result in the correct lat,lng
foreach my $test (
    {
        pc        => 'SW1A 1AA',
        latitude  => '51.5010096115539',
        longitude => '-0.141587067110009',
    },
    {
        pc        => 'Manchester',
        latitude  => '53.4807125',
        longitude => '-2.2343765',
    },
    {
        pc        => 'Glenthorpe Rd, Merton, Greater London SM4 4, UK',
        latitude  => '51.3937997',
        longitude => '-0.2209596',
    },
  )
{
    $mech->get_ok('/reports/new');
    $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
        "good location" );
    is_deeply $mech->form_errors, [], "no errors for pc '$test->{pc}'";
    is_deeply $mech->extract_location, $test,
      "got expected location for pc '$test->{pc}'";

}

#### test report creation for a user who does not have an account
# come to site
# fill in report
# receive token
# confirm token
# report is confirmed
# user is created and logged in

#### test report creation for a user who has account but is not logged in
# come to site
# fill in report
# receive token
# confirm token
# report is confirmed

#### test report creation for user with account and logged in
# come to site
# fill in report
# report is confirmed

#### test uploading an image

#### test completing a partial report (eq flickr upload)

#### test error cases when filling in a report

#### possibly manual testing
# create report without using map
# create report by clicking on may with javascript off
# create report with images off

done_testing();
