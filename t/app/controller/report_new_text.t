use FixMyStreet::TestMech;
use t::Mock::Twilio;

my $twilio = t::Mock::Twilio->new;
LWP::Protocol::PSGI->register($twilio->to_psgi_app, host => 'api.twilio.com');

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2651, 'City of Edinburgh Council');
$mech->create_contact_ok( body_id => $body->id, category => 'Street lighting', email => 'highways@example.com' );
$mech->create_contact_ok( body_id => $body->id, category => 'Trees', email => 'trees@example.com' );

# test that phone number validation works okay
foreach my $test (
    {
        msg => 'invalid number',
        pc => 'EH1 1BB',
        fields => {
            username => '0121 4960000000', email => '', phone => '',
            title => 'Title', detail => 'Detail', name => 'Bob Jones',
            category => 'Street lighting',
            may_show_name => '1',
            photo1 => '', photo2 => '', photo3 => '',
            password_register => '', password_sign_in => '',
        },
        changes => {
            username => '01214960000000',
            phone => '01214960000000',
        },
        errors => [ 'Please check your phone number is correct' ],
    },
    {
        msg => 'landline number',
        pc => 'EH1 1BB',
        fields => {
            username => '0121 4960000', email => '', phone => '',
            title => 'Title', detail => 'Detail', name => 'Bob Jones',
            category => 'Street lighting',
            may_show_name => '1',
            photo1 => '', photo2 => '', photo3 => '',
            password_register => '', password_sign_in => '',
        },
        changes => {
            username => '0121 496 0000',
            phone => '0121 496 0000',
        },
        errors => [ 'Please enter a mobile number', ],
    },
  )
{
    subtest "check form errors where $test->{msg}" => sub {
        $mech->get_ok('/around');

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
            SMS_AUTHENTICATION => 1,
            PHONE_COUNTRY => 'GB',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
                "submit location" );
            is_deeply $mech->page_errors, [], "no errors for pc '$test->{pc}'";

            # click through to the report page
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link" );

            # submit the main form
            $mech->submit_form_ok( { with_fields => $test->{fields} }, "submit form" );
        };

        # check that we got the errors expected
        is_deeply [ sort @{$mech->page_errors} ], [ sort @{$test->{errors}} ], "check errors";

        # check that fields have changed as expected
        my $new_values = {
            %{ $test->{fields} },     # values added to form
            %{ $test->{changes} },    # changes we expect
        };
        is_deeply $mech->visible_form_values, $new_values,
          "values correctly changed";
    };
}

my $test_phone = '+61491570156';
my $first_user;
foreach my $test (
    {
        desc => 'does not have an account, does not set a password',
        user => 0, password => 0,
    },
    {
        desc => 'does not have an account, sets a password',
        user => 0, password => 1,
    },
    {
        desc => 'does have an account and is not signed in; does not sign in, does not set a password',
        user => 1, password => 0,
    },
    {
        desc => 'does have an account and is not signed in; does not sign in, sets a password',
        user => 1, password => 1,
    },
) {
  subtest "test report creation for a user who " . $test->{desc} => sub {
    $mech->log_out_ok;

    if ($test->{user}) {
        my $user = FixMyStreet::DB->resultset('User')->find( { phone => $test_phone } );
        ok $user, "test user does exist";
        $user->problems->delete;
        $user->name( 'Old Name' );
        $user->password( 'old_password' );
        $user->update;
    } elsif (!$first_user) {
        ok !FixMyStreet::DB->resultset('User')->find( { phone => $test_phone } ),
          "test user does not exist";
        $first_user = 1;
    } else {
        # Not first pass, so will exist, but want no user to start, so delete it.
        $mech->delete_user($test_phone);
    }

    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
        SMS_AUTHENTICATION => 1,
        PHONE_COUNTRY => 'GB',
        TWILIO_ACCOUNT_SID => 'AC123',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok(
            {
                button => 'submit_register',
                with_fields => {
                    title => 'Test Report', detail => 'Test report details.',
                    photo1 => '',
                    name => 'Joe Bloggs', may_show_name => '1',
                    username => $test_phone,
                    category => 'Street lighting',
                    password_register => $test->{password} ? 'secret' : '',
                }
            },
            "submit good details"
        );
    };

    is_deeply $mech->page_errors, [], "check there were no errors";

    my $user = FixMyStreet::DB->resultset('User')->find( { phone => $test_phone } );
    ok $user, "user found";
    if ($test->{user}) {
        is $user->name, 'Old Name', 'name unchanged';
        ok $user->check_password('old_password'), 'password unchanged';
    } else {
        is $user->name, undef, 'name not yet set';
        is $user->password, '', 'password not yet set for new user';
    }

    my $report = $user->problems->first;
    ok $report, "Found the report";
    is $report->state, 'unconfirmed', "report not confirmed";
    is $report->bodies_str, $body->id;

    $mech->submit_form_ok({ with_fields => { code => '00000' } });
    $mech->content_contains('Try again');

    my $code = $twilio->get_text_code;
    $mech->submit_form_ok({ with_fields => { code => $code } });

    $report->discard_changes;
    is $report->state, 'confirmed', "Report is now confirmed";

    $mech->get_ok( '/report/' . $report->id );

    is $report->name, 'Joe Bloggs', 'name updated correctly';
    if ($test->{password}) {
        ok $report->user->check_password('secret'), 'password updated correctly';
    } elsif ($test->{user}) {
        ok $report->user->check_password('old_password'), 'password unchanged, as no new one given';
    } else {
        is $report->user->password, '', 'password still not set, as none given';
    }

    # check that the reporter has an alert
    my $alert = FixMyStreet::DB->resultset('Alert')->find( {
        user => $report->user,
        alert_type => 'new_updates',
        parameter => $report->id,
    } );
    ok $alert, "created new alert";

    # user is created and logged in
    $mech->logged_in_ok;

    # cleanup
    $mech->delete_user($user)
        if $test->{user} && $test->{password};
  };
}

# this test to make sure that we don't see spurious error messages about
# the name being blank when there is a sign in error
subtest "test password errors for a user who is signing in as they report" => sub {
    $mech->log_out_ok;

    my $user = $mech->create_user_ok($test_phone);
    ok $user->update( {
        name => 'Joe Bloggs',
        email => 'joe@example.net',
        password => 'secret2',
    } ), "set user details";

    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
        SMS_AUTHENTICATION => 1,
        phone_verified => 1,
        email_verified => 1,
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok(
            {
                button => 'submit_sign_in',
                with_fields => {
                    title => 'Test Report',
                    detail => 'Test report details.',
                    photo1 => '',
                    username => $test_phone,
                    password_sign_in => 'secret1',
                    category => 'Street lighting',
                }
            },
            "submit with wrong password"
        );
    };

    # check that we got the errors expected
    is_deeply $mech->page_errors, [
        "There was a problem with your login information. If you cannot remember your password, or do not have one, please fill in the \x{2018}No\x{2019} section of the form.",
    ], "check there were errors";

    $mech->content_lacks($user->email, 'email not displayed');
};

subtest "test report creation for a user who is signing in as they report" => sub {
    $mech->log_out_ok;
    $mech->cookie_jar({});

    my $user = $mech->create_user_ok($test_phone);

    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
        SMS_AUTHENTICATION => 1,
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok(
            {
                button => 'submit_sign_in',
                with_fields => {
                    title => 'Test Report',
                    detail => 'Test report details.',
                    photo1 => '',
                    username => $test_phone,
                    password_sign_in => 'secret2',
                    category => 'Street lighting',
                }
            },
            "submit good details"
        );

        # check that we got the message expected
        $mech->content_contains( 'You have successfully signed in; please check and confirm your details are accurate:' );

        # Now submit with a name
        $mech->submit_form_ok(
            {
                with_fields => {
                    name => 'Joe Bloggs',
                }
            },
            "submit good details"
        );
    };

    my $report = $user->problems->first;
    ok $report, "Found the report";
    $mech->content_contains('Thank you for reporting this issue');
    is $report->bodies_str, $body->id;
    is $report->state, 'confirmed', "report is now confirmed";
    $mech->get_ok( '/report/' . $report->id );
    my $alert = FixMyStreet::DB->resultset('Alert')->find( {
        user => $report->user,
        alert_type => 'new_updates',
        parameter => $report->id,
    } );
    ok $alert, "created new alert";

    $mech->logged_in_ok;
};

subtest "test report creation for a user who is logged in" => sub {
    my $user = $mech->create_user_ok($test_phone);
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        is_deeply(
            $mech->visible_form_values,
            {
                title => '',
                detail => '',
                may_show_name => undef,
                name => 'Joe Bloggs',
                email => 'joe@example.net',
                photo1 => '',
                photo2 => '',
                photo3 => '',
                category => '-- Pick a category --',
            },
            "user's details prefilled"
        );

        $mech->submit_form_ok(
            {
                with_fields => {
                    title => "Test Report at café",
                    detail => 'Test report details.',
                    photo1 => '',
                    name => 'Joe Bloggs',
                    may_show_name => '1',
                    category => 'Street lighting',
                }
            },
            "submit good details"
        );
    };

    my $report = $user->problems->first;
    ok $report, "Found the report";
    is $report->bodies_str, $body->id;
    $mech->content_contains('Thank you for reporting this issue');
    is $report->state, 'confirmed', "report is now confirmed";
    $mech->get_ok( '/report/' . $report->id );
    my $alert = FixMyStreet::DB->resultset('Alert')->find( {
        user => $report->user,
        alert_type => 'new_updates',
        parameter => $report->id,
    } );
    ok $alert, "created new alert";

    $mech->logged_in_ok;

    $mech->get_ok(
        '/around?ajax=1&bbox=' . ($report->longitude - 0.01) . ',' .  ($report->latitude - 0.01)
        . ',' . ($report->longitude + 0.01) . ',' .  ($report->latitude + 0.01)
    );
    $mech->content_contains( "Test Report at caf\xc3\xa9" );
};

done_testing();
