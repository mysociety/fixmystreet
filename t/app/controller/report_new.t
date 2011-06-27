use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use Web::Scraper;

my $mech = FixMyStreet::TestMech->new;
$mech->get_ok('/report/new');

subtest "test that bare requests to /report/new get redirected" => sub {

    $mech->get_ok('/report/new');
    is $mech->uri->path, '/around', "went to /around";
    is_deeply { $mech->uri->query_form }, {}, "query empty";

    $mech->get_ok('/report/new?pc=SW1A%201AA');
    is $mech->uri->path, '/around', "went to /around";
    is_deeply { $mech->uri->query_form }, { pc => 'SW1A 1AA' },
      "pc correctly transferred";
};

my %contact_params = (
    confirmed => 1,
    deleted => 0,
    editor => 'Test',
    whenedited => \'current_timestamp',
    note => 'Created for test',
);
# Let's make some contacts to send things to!
my $contact1 = FixMyStreet::App->model('DB::Contact')->find_or_create( {
    %contact_params,
    area_id => 2651, # Edinburgh
    category => 'Street lighting',
    email => 'highways@example.com',
} );
my $contact2 = FixMyStreet::App->model('DB::Contact')->find_or_create( {
    %contact_params,
    area_id => 2226, # Gloucestershire
    category => 'Potholes',
    email => 'potholes@example.com',
} );
my $contact3 = FixMyStreet::App->model('DB::Contact')->find_or_create( {
    %contact_params,
    area_id => 2326, # Cheltenham
    category => 'Trees',
    email => 'trees@example.com',
} );
ok $contact1, "created test contact 1";
ok $contact2, "created test contact 2";
ok $contact3, "created test contact 3";

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
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
        },
        changes => {},
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'Please enter your email',
            'Please enter your name',
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
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
        },
        changes => { may_show_name => '1' },
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'Please enter your email',
            'Please enter your name',
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
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
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
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
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
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
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
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
        },
        changes => {},
        errors  => [
            'Please enter your email',
'Please enter your full name, councils need this information - if you do not wish your name to be shown on the site, untick the box',
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
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
        },
        changes => {},
        errors  => [
            'Please enter your email',
'Please enter your full name, councils need this information - if you do not wish your name to be shown on the site, untick the box',
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
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
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
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
        },
        changes => {
            title  => 'Test title',
            detail => "First line\n\nSecond line",
        },
        errors => [
            'Please enter your email',
            'Please enter your name',
        ],
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
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
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
        $mech->get_ok('/around');

        # submit initial pc form
        $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
            "submit location" );
        is_deeply $mech->form_errors, [], "no errors for pc '$test->{pc}'";

        # click through to the report page
        $mech->follow_link_ok( { text => 'skip this step', },
            "follow 'skip this step' link" );

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

foreach my $test (
    {
        desc => 'does not have an account',
        user => 0,
    },
    {
        desc => 'does have an account and is not signed in; does not sign in',
        user => 1,
    }
) {
  subtest "test report creation for a user who " . $test->{desc} => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;

    # check that the user does not exist
    my $test_email = 'test-1@example.com';
    if ($test->{user}) {
        my $user = FixMyStreet::App->model('DB::User')->find( { email => $test_email } );
        ok $user, "test user does exist";
        $user->problems->delete;
    } else {
        ok !FixMyStreet::App->model('DB::User')->find( { email => $test_email } ),
          "test user does not exist";
    }

    # submit initial pc form
    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
        "submit location" );

    # click through to the report page
    $mech->follow_link_ok( { text => 'skip this step', },
        "follow 'skip this step' link" );

    $mech->submit_form_ok(
        {
            button      => 'submit_register',
            with_fields => {
                title         => 'Test Report',
                detail        => 'Test report details.',
                photo         => '',
                name          => 'Joe Bloggs',
                may_show_name => '1',
                email         => 'test-1@example.com',
                phone         => '07903 123 456',
                category      => 'Street lighting',
                password_register => 'secret',
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
    ok $user->check_password('secret'), 'password set correctly';

    # find the report
    my $report = $user->problems->first;
    ok $report, "Found the report";

    # check that the report is not available yet.
    is $report->state, 'unconfirmed', "report not confirmed";
    is $mech->get( '/report/' . $report->id )->code, 404, "report not found";

    # Check the report has been assigned appropriately
    is $report->council, 2651;

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

    $mech->get_ok( '/report/' . $report->id );

    # check that the reporter has an alert
    my $alert = FixMyStreet::App->model('DB::Alert')->find( {
        user       => $report->user,
        alert_type => 'new_updates',
        parameter  => $report->id,
    } );
    ok $alert, "created new alert";

    # user is created and logged in
    $mech->logged_in_ok;

    # cleanup
    $mech->delete_user($user)
        if $test->{user};
  };
}

subtest "test report creation for a user who is signing in as they report" => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;

    # check that the user does not exist
    my $test_email = 'test-2@example.com';

    my $user = FixMyStreet::App->model('DB::User')->find_or_create( { email => $test_email } );
    ok $user, "test user does exist";

    # setup the user.
    ok $user->update( {
        name     => 'Joe Bloggs',
        phone    => '01234 567 890',
        password => 'secret2',
    } ), "set user details";

    # submit initial pc form
    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
        "submit location" );

    # click through to the report page
    $mech->follow_link_ok( { text => 'skip this step', },
        "follow 'skip this step' link" );

    $mech->submit_form_ok(
        {
            button      => 'submit_sign_in',
            with_fields => {
                title         => 'Test Report',
                detail        => 'Test report details.',
                photo         => '',
                email         => 'test-2@example.com',
                password_sign_in => 'secret2',
                category      => 'Street lighting',
            }
        },
        "submit good details"
    );

    # check that we got the errors expected
    is_deeply $mech->form_errors, [
        'You have successfully signed in; please check and confirm your details are accurate:',
    ], "check there were errors";

    # Now submit with a name
    $mech->submit_form_ok(
        {
            with_fields => {
                name => 'Joe Bloggs',
            }
        },
        "submit good details"
    );

    # find the report
    my $report = $user->problems->first;
    ok $report, "Found the report";

    # check that we got redirected to /report/
    is $mech->uri->path, "/report/" . $report->id, "redirected to report page";

    # Check the report has been assigned appropriately
    is $report->council, 2651;

    # check that no emails have been sent
    $mech->email_count_is(0);

    # check report is confirmed and available
    is $report->state, 'confirmed', "report is now confirmed";
    $mech->get_ok( '/report/' . $report->id );

    # check that the reporter has an alert
    my $alert = FixMyStreet::App->model('DB::Alert')->find( {
        user       => $report->user,
        alert_type => 'new_updates',
        parameter  => $report->id,
    } );
    ok $alert, "created new alert";

    # user is created and logged in
    $mech->logged_in_ok;

    # cleanup
    $mech->delete_user($user)
};

#### test report creation for user with account and logged in
foreach my $test (
    { category => 'Trees', council => 2326 },
    { category => 'Potholes', council => 2226 },
) {
    subtest "test report creation for a user who is logged in" => sub {

        # check that the user does not exist
        my $test_email = 'test-2@example.com';

        $mech->clear_emails_ok;
        my $user = $mech->log_in_ok($test_email);

        # setup the user.
        ok $user->update(
            {
                name  => 'Test User',
                phone => '01234 567 890',
            }
          ),
          "set users details";

        # submit initial pc form
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text => 'skip this step', },
            "follow 'skip this step' link" );

        # check that the fields are correctly prefilled
        is_deeply(
            $mech->visible_form_values,
            {
                title         => '',
                detail        => '',
                may_show_name => '1',
                name          => 'Test User',
                phone         => '01234 567 890',
                photo         => '',
                category      => '-- Pick a category --',
            },
            "user's details prefilled"
        );

        $mech->submit_form_ok(
            {
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo         => '',
                    name          => 'Joe Bloggs',
                    may_show_name => '1',
                    phone         => '07903 123 456',
                    category      => $test->{category},
                }
            },
            "submit good details"
        );

        # find the report
        my $report = $user->problems->first;
        ok $report, "Found the report";

        # Check the report has been assigned appropriately
        is $report->council, $test->{council};

        # check that we got redirected to /report/
        is $mech->uri->path, "/report/" . $report->id, "redirected to report page";

        # check that no emails have been sent
        $mech->email_count_is(0);

        # check report is confirmed and available
        is $report->state, 'confirmed', "report is now confirmed";
        $mech->get_ok( '/report/' . $report->id );

        # check that the reporter has an alert
        my $alert = FixMyStreet::App->model('DB::Alert')->find( {
            user       => $report->user,
            alert_type => 'new_updates',
            parameter  => $report->id,
        } );
        ok $alert, "created new alert";

        # user is still logged in
        $mech->logged_in_ok;

        # cleanup
        $mech->delete_user($user);
    };

}

#### test uploading an image

#### test completing a partial report (eq flickr upload)

#### possibly manual testing
# create report without using map
# create report by clicking on may with javascript off
# create report with images off

subtest "check that a lat/lon off coast leads to /around" => sub {
    my $off_coast_latitude  = 50.78301;
    my $off_coast_longitude = -0.646929;

    $mech->get_ok(    #
        "/report/new"
          . "?latitude=$off_coast_latitude"
          . "&longitude=$off_coast_longitude"
    );

    is $mech->uri->path, '/around', "redirected to '/around'";

    is_deeply         #
      $mech->page_errors,
      [     'That spot does not appear to be covered by a council. If you have'
          . ' tried to report an issue past the shoreline, for example, please'
          . ' specify the closest point on land.' ],    #
      "Found location error";

};

$contact1->delete;
$contact2->delete;
$contact3->delete;

done_testing();
