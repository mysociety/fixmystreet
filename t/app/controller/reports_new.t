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
        pc     => 'glenthorpe',
        errors => [],
        pc_alternatives => [   # TODO - should filter out these non-UK addresses
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
    subtest "test bad pc value '$test->{pc}'" => sub {
        $mech->get_ok('/reports/new');
        $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
            "bad location" );
        is_deeply $mech->form_errors, $test->{errors},
          "expected errors for pc '$test->{pc}'";
        is_deeply $mech->pc_alternatives, $test->{pc_alternatives},
          "expected alternatives for pc '$test->{pc}'";
    };
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
    subtest "check lat/lng for '$test->{pc}'" => sub {
        $mech->get_ok('/reports/new');
        $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
            "good location" );
        is_deeply $mech->form_errors, [], "no errors for pc '$test->{pc}'";
        is_deeply $mech->extract_location, $test,
          "got expected location for pc '$test->{pc}'";
    };
}

# test that the various bit of form get filled in and errors correctly
# generated.
foreach my $test (
    {
        msg    => 'all fields empty',
        pc     => 'SW1A 1AA',
        fields => {
            title         => '',
            detail        => '',
            photo         => '',
            name          => '',
            may_show_name => '1',
            email         => '',
            phone         => '',
        },
        changes => {},
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'Please enter your name',
            'Please enter your email',
        ],
    },
    {
        msg    => 'may_show_name defaults to true',
        pc     => 'SW1A 1AA',
        fields => {
            title         => '',
            detail        => '',
            photo         => '',
            name          => '',
            may_show_name => undef,
            email         => '',
            phone         => '',
        },
        changes => { may_show_name => '1' },
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'Please enter your name',
            'Please enter your email',
        ],
    },
    {
        msg    => 'may_show_name unchanged if name is present (stays false)',
        pc     => 'SW1A 1AA',
        fields => {
            title         => '',
            detail        => '',
            photo         => '',
            name          => 'Bob Jones',
            may_show_name => undef,
            email         => '',
            phone         => '',
        },
        changes => {},
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'Please enter your email',
        ],
    },
    {
        msg    => 'may_show_name unchanged if name is present (stays true)',
        pc     => 'SW1A 1AA',
        fields => {
            title         => '',
            detail        => '',
            photo         => '',
            name          => 'Bob Jones',
            may_show_name => '1',
            email         => '',
            phone         => '',
        },
        changes => {},
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'Please enter your email',
        ],
    },
    {
        msg    => 'title and details tidied up',
        pc     => 'SW1A 1AA',
        fields => {
            title         => 'DOG SHIT ON WALLS',
            detail        => 'on this portakabin - more of a portaloo HEH!!',
            photo         => '',
            name          => 'Bob Jones',
            may_show_name => '1',
            email         => '',
            phone         => '',
        },
        changes => {
            title => 'Dog poo on walls',
            detail =>
              'On this [portable cabin] - more of a [portable loo] HEH!!',
        },
        errors => [ 'Please enter your email', ],
    },
    {
        msg    => 'name too short',
        pc     => 'SW1A 1AA',
        fields => {
            title         => 'Test title',
            detail        => 'Test detail',
            photo         => '',
            name          => 'DUDE',
            may_show_name => '1',
            email         => '',
            phone         => '',
        },
        changes => {},
        errors  => [
'Please enter your full name, councils need this information - if you do not wish your name to be shown on the site, untick the box',
            'Please enter your email',
        ],
    },
    {
        msg    => 'name is anonymous',
        pc     => 'SW1A 1AA',
        fields => {
            title         => 'Test title',
            detail        => 'Test detail',
            photo         => '',
            name          => 'anonymous',
            may_show_name => '1',
            email         => '',
            phone         => '',
        },
        changes => {},
        errors  => [
'Please enter your full name, councils need this information - if you do not wish your name to be shown on the site, untick the box',
            'Please enter your email',
        ],
    },
    {
        msg    => 'email invalid',
        pc     => 'SW1A 1AA',
        fields => {
            title         => 'Test title',
            detail        => 'Test detail',
            photo         => '',
            name          => 'Joe Smith',
            may_show_name => '1',
            email         => 'not an email',
            phone         => '',
        },
        changes => { email => 'notanemail', },
        errors  => [ 'Please enter a valid email', ],
    },
    {
        msg    => 'cleanup title and detail',
        pc     => 'SW1A 1AA',
        fields => {
            title         => "   Test   title   ",
            detail        => "   first line   \n\n second\nline\n\n   ",
            photo         => '',
            name          => '',
            may_show_name => '1',
            email         => '',
            phone         => '',
        },
        changes => {
            title  => 'Test title',
            detail => "First line\n\nSecond line",
        },
        errors => [ 'Please enter your name', 'Please enter your email', ],
    },
    {
        msg    => 'clean up name and email',
        pc     => 'SW1A 1AA',
        fields => {
            title         => '',
            detail        => '',
            photo         => '',
            name          => '  Bob    Jones   ',
            may_show_name => '1',
            email         => '   BOB @ExAmplE.COM   ',
            phone         => '',
        },
        changes => {
            name  => 'Bob Jones',
            email => 'bob@example.com',
        },
        errors => [ 'Please enter a subject', 'Please enter some details', ],
    },
  )
{
    subtest "check form errors where $test->{msg}" => sub {
        $mech->get_ok('/reports/new');

        # submit initial pc form
        $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
            "submit location" );
        is_deeply $mech->form_errors, [], "no errors for pc '$test->{pc}'";

        # submit the main form
        $mech->submit_form_ok( { with_fields => $test->{fields} },
            "submit form" );

        # check that we got the errors expected
        is_deeply $mech->form_errors, $test->{errors}, "check errors";

        # check that fields have changed as expected
        my $new_values = {
            %{ $test->{fields} },     # values added to form
            %{ $test->{changes} },    # changes we expect
        };
        is_deeply $mech->visible_form_values, $new_values,
          "values correctly changed";
    };
}

subtest "test report creation for a user who does not have an account" => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;

    # check that the user does not exist
    my $test_email = 'test-1@example.com';
    ok !FixMyStreet::App->model('DB::User')->find( { email => $test_email } ),
      "test user does not exist";

    # submit initial pc form
    $mech->get_ok('/reports/new');
    $mech->submit_form_ok( { with_fields => { pc => 'SW1A 1AA', } },
        "submit location" );
    $mech->submit_form_ok(
        {
            with_fields => {
                title         => 'Test Report',
                detail        => 'Test report details.',
                photo         => '',
                name          => 'Joe Bloggs',
                may_show_name => '1',
                email         => 'test-1@example.com',
                phone         => '07903 123 456',
            }
        },
        "submit good details"
    );

    # check that we got the errors expected
    is_deeply $mech->form_errors, [], "check there were no errors";

    # check that the user has been created
    my $user =
      FixMyStreet::App->model('DB::User')->find( { email => $test_email } );
    ok $user, "created new user";

    # find the report
    my $report = $user->problems->first;
    ok $report, "Found the report";

    # check that the report is not available yet.
    is $report->state, 'unconfirmed', "report not confirmed";
    is $mech->get( '/reports/' . $report->id )->code, 404, "report not found";

    # receive token
    my $email = $mech->get_email;
    ok $email, "got an email";
    like $email->body, qr/confirm the problem/i, "confirm the problem";

    my ($url) = $email->body =~ m{(http://\S+)};
    ok $url, "extracted confirm url '$url'";

    # confirm token
    $mech->get_ok($url);
    $report->discard_changes;
    is $report->state, 'confirmed', "Report is now confirmed";
    is $report->state, 'confirmed', "report is now confirmed";

  TODO: {
        local $TODO = "'/reports/<<id>>' not handled by catalyst yet";
        $mech->get_ok( '/reports/' . $report->id );
    }

    # user is created and logged in
    $mech->logged_in_ok;

    # cleanup
    $mech->log_out_ok;
    ok $_->delete, "delete problem" for $user->problems;
    ok $user->delete, "delete test user";
};

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

#### possibly manual testing
# create report without using map
# create report by clicking on may with javascript off
# create report with images off

done_testing();
