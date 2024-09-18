use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

package FixMyStreet::Cobrand::HounslowNoName;
use base 'FixMyStreet::Cobrand::UK';

sub council_area_id { 2483 };

package FixMyStreet::Cobrand::Overrides;
use base 'FixMyStreet::Cobrand::UK';

sub new_report_title_field_label { "cobrand title label" }

sub new_report_title_field_hint { "cobrand title hint" }

sub new_report_detail_field_label { "cobrand detail label" }

sub new_report_detail_field_hint { "cobrand detail hint" }

package main;

use Test::Deep;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my %body_ids;
for my $body (
    { area_id => 2651, name => 'City of Edinburgh Council' },
    { area_id => 2226, name => 'Gloucestershire County Council' },
    { area_id => 2326, name => 'Cheltenham Borough Council' },
    { area_id => 2482, name => 'Bromley Council', cobrand => 'bromley' },
    { area_id => 2227, name => 'Hampshire County Council', cobrand => 'hampshire' },
    { area_id => 2333, name => 'Hart Council', cobrand => 'hart' },
    { area_id => 2535, name => 'Sandwell Borough Council' },
    { area_id => 1000, name => 'National Highways', cobrand => 'highwaysengland' },
    { area_id => 2483, name => 'Hounslow Borough Council', cobrand => 'hounslow' },
) {
    my $extra = { cobrand => $body->{cobrand} } if $body->{cobrand};
    my $body_obj = $mech->create_body_ok($body->{area_id}, $body->{name}, {}, $extra);
    $body_ids{$body->{area_id}} = $body_obj->id;
}

# Let's make some contacts to send things to!
my $contact1 = $mech->create_contact_ok(
    body_id => $body_ids{2651}, # Edinburgh
    category => 'Street lighting',
    email => 'highways@example.com',
);
my $contact2 = $mech->create_contact_ok(
    body_id => $body_ids{2226}, # Gloucestershire
    category => 'Potholes',
    email => 'potholes@example.com',
);
my $contact3 = $mech->create_contact_ok(
    body_id => $body_ids{2326}, # Cheltenham
    category => 'Trees',
    email => 'trees@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2482}, # Bromley
    category => 'Trees',
    email => 'trees@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2651}, # Edinburgh
    category => 'Trees',
    email => 'trees@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2333}, # Hart
    category => 'Trees',
    email => 'trees@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2227}, # Hampshire
    category => 'Street Lighting',
    email => 'highways@example.com',
);
my $contact9 = $mech->create_contact_ok(
    body_id => $body_ids{2226}, # Gloucestershire
    category => 'Street lighting',
    email => 'streetlights-2226@example.com',
);
my $contact10 = $mech->create_contact_ok(
    body_id => $body_ids{2326}, # Cheltenham
    category => 'Street lighting',
    email => 'streetlights-2326@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{1000}, # Highways
    category => 'Pothole',
    email => 'pothole-1000@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2483}, # Hounslow
    category => 'Trees',
    email => 'trees-2483@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2483}, # Hounslow
    category => 'General Enquiry',
    email => 'general-enquiry-2483@example.com',
    non_public => 1,
);

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
    $mech->clear_emails_ok;

    # check that the user does not exist
    my $test_email = 'test-1@example.com';
    if ($test->{user}) {
        my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
        ok $user, "test user does exist";
        $user->problems->delete;
        $user->name( 'Old Name' );
        $user->password( 'old_password' );
        $user->update;
    } elsif (!$first_user) {
        ok !FixMyStreet::DB->resultset('User')->find( { email => $test_email } ),
          "test user does not exist";
        $first_user = 1;
    } else {
        # Not first pass, so will exist, but want no user to start, so delete it.
        $mech->delete_user($test_email);
    }

    # submit initial pc form
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_register_mobile',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    name          => 'Joe Bloggs',
                    may_show_name => '1',
                    username_register => 'test-1@example.com',
                    phone         => '07903 123 456',
                    category      => 'Street lighting',
                    password_register => $test->{password} ? 'secretsecret' : '',
                }
            },
            "submit good details"
        );
    };

    # check that we got the errors expected
    is_deeply $mech->page_errors, [], "check there were no errors";

    # check that the user has been created/ not changed
    my $user =
      FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
    ok $user, "user found";
    if ($test->{user}) {
        is $user->name, 'Old Name', 'name unchanged';
        ok $user->check_password('old_password'), 'password unchanged';
    } else {
        is $user->name, undef, 'name not yet set';
        is $user->password, '', 'password not yet set for new user';
    }

    # find the report
    my $report = $user->problems->first;
    ok $report, "Found the report";

    # check that the report is not available yet.
    is $report->state, 'unconfirmed', "report not confirmed";
    is $mech->get( '/report/' . $report->id )->code, 404, "report not found";

    # Check the report has been assigned appropriately
    is $report->bodies_str, $body_ids{2651};

    # receive token
    my $email = $mech->get_email;
    ok $email, "got an email";
    like $mech->get_text_body_from_email($email), qr/confirm that you want to send your\s+report/i, "confirm the problem";

    my $url = $mech->get_link_from_email($email);

    # confirm token
    $mech->get_ok($url);
    $report->discard_changes;
    is $report->state, 'confirmed', "Report is now confirmed";

    $mech->get_ok( '/report/' . $report->id );

    is $report->name, 'Joe Bloggs', 'name updated correctly';
    if ($test->{password}) {
        ok $report->user->check_password('secretsecret'), 'password updated correctly';
    } elsif ($test->{user}) {
        ok $report->user->check_password('old_password'), 'password unchanged, as no new one given';
    } else {
        is $report->user->password, '', 'password still not set, as none given';
    }

    # check that the reporter has an alert
    my $alert = FixMyStreet::DB->resultset('Alert')->find( {
        user       => $report->user,
        alert_type => 'new_updates',
        parameter  => $report->id,
    } );
    ok $alert, "created new alert";

    # user is created and logged in
    $mech->logged_in_ok;

    # cleanup
    $mech->delete_user($user)
        if $test->{user} && $test->{password};
  };
}

foreach my $test (
  { two_factor => '', desc => '', },
  { two_factor => 'yes', desc => ' with two-factor', },
  { two_factor => 'new', desc => ' with mandated two-factor, not yet set up', },
) {
  subtest "test report creation for a user who is signing in as they report$test->{desc}" => sub {
    $mech->log_out_ok;
    $mech->cookie_jar({});
    $mech->clear_emails_ok;

    # check that the user does not exist
    my $test_email = 'test-2@example.com';

    my $user = $mech->create_user_ok($test_email);

    # setup the user.
    ok $user->update( {
        name     => 'Joe Bloggs',
        phone    => '01234 567 890',
        password => 'secret2',
        $test->{two_factor} ? (is_superuser => 1) : (),
    } ), "set user details";

    my $auth;
    my $mock;
    if ($test->{two_factor} eq 'yes') {
        use Auth::GoogleAuth;
        $auth = Auth::GoogleAuth->new;
        $user->set_extra_metadata('2fa_secret', $auth->generate_secret32);
        $user->update;
    } elsif ($test->{two_factor} eq 'new') {
        $mock = Test::MockModule->new('FixMyStreet::Cobrand::FixMyStreet');
        $mock->mock(must_have_2fa => sub { 1 });
    }

    # submit initial pc form
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_sign_in',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    username      => $user->email,
                    password_sign_in => 'secret2',
                    category      => 'Street lighting',
                }
            },
            "submit good details"
        );

        if ($test->{two_factor} eq 'yes') {
            my $code = $auth->code;
            my $wrong_code = $auth->code(undef, time() - 120);
            $mech->content_contains('Please generate a two-factor code');
            $mech->submit_form_ok({ with_fields => { '2fa_code' => $wrong_code } }, "provide wrong 2FA code" );
            $mech->content_contains('Try again');
            $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );
        } elsif ($test->{two_factor} eq 'new') {
            $mech->content_contains('requires two-factor');
            $mech->submit_form_ok({ with_fields => { '2fa_action' => 'activate' } }, "submit 2FA activation");
            my ($token) = $mech->content =~ /name="secret32" value="([^"]*)">/;

            use Auth::GoogleAuth;
            my $auth = Auth::GoogleAuth->new({ secret32 => $token });
            my $code = $auth->code;
            $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );
        }

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

    # find the report
    my $report = $user->problems->first;
    ok $report, "Found the report";

    if ($test->{two_factor} eq '') {
        # The superuser account will be immediately redirected
        $mech->content_contains('Thank you for reporting this issue');
    }

    # Check the report has been assigned appropriately
    is $report->bodies_str, $body_ids{2651};

    # check that no emails have been sent
    $mech->email_count_is(0);

    # check report is confirmed and available
    is $report->state, 'confirmed', "report is now confirmed";
    $mech->get_ok( '/report/' . $report->id );

    # check that the reporter has an alert
    my $alert = FixMyStreet::DB->resultset('Alert')->find( {
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
}

#### test report creation for user with account and logged in
my ($saved_lat, $saved_lon);
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
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR', } },
                "submit location" );

            # click through to the report page
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
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
                    photo1        => '',
                    photo2        => '',
                    photo3        => '',
                    category      => undef,
                },
                "user's details prefilled"
            );

            $mech->submit_form_ok(
                {
                    with_fields => {
                        title         => "Test Report at café",
                        detail        => 'Test report details.',
                        photo1        => '',
                        name          => 'Joe Bloggs',
                        may_show_name => '1',
                        phone         => '07903 123 456',
                        category      => $test->{category},
                    }
                },
                "submit good details"
            );
        };

        # find the report
        my $report = $user->problems->first;
        ok $report, "Found the report";

        # Check the report has been assigned appropriately
        is $report->bodies_str, $body_ids{$test->{council}};

        $mech->content_contains('Thank you for reporting this issue');

        # check that no emails have been sent
        $mech->email_count_is(0);

        # check report is confirmed and available
        is $report->state, 'confirmed', "report is now confirmed";
        $mech->get_ok( '/report/' . $report->id );

        # check that the reporter has an alert
        my $alert = FixMyStreet::DB->resultset('Alert')->find( {
            user       => $report->user,
            alert_type => 'new_updates',
            parameter  => $report->id,
        } );
        ok $alert, "created new alert";

        # user is still logged in
        $mech->logged_in_ok;

        # Test that AJAX pages return the right data
        $mech->get_ok(
            '/around?ajax=1&bbox=' . ($report->longitude - 0.01) . ',' .  ($report->latitude - 0.01)
            . ',' . ($report->longitude + 0.01) . ',' .  ($report->latitude + 0.01)
        );
        $mech->content_contains( "Test Report at caf\xc3\xa9" );
        $saved_lat = $report->latitude;
        $saved_lon = $report->longitude;

        # cleanup
        $mech->delete_user($user);
    };

}

# XXX add test for category with multiple bodies
foreach my $test (
    {
        desc => "test report creation for multiple bodies",
        category => 'Street lighting',
        councils => [ 2226, 2326 ],
        extra_fields => {},
        email_count => 2,
    },
    {
        desc => "test single_body_only means only one report body",
        category => 'Street lighting',
        councils => [ 2326 ],
        extra_fields => { single_body_only => 'Cheltenham Borough Council' },
        email_count => 1,
    },
    {
        desc => "test invalid single_body_only means no report bodies",
        category => 'Street lighting',
        councils => [],
        extra_fields => { single_body_only => 'Invalid council' },
        email_count => 1,
    },
    {
        desc => "test do_not_send means body is ignored",
        category => 'Street lighting',
        councils => [ 2326 ],
        extra_fields => { do_not_send => 'Gloucestershire County Council' },
        email_count => 1,
    },
    {
        desc => "test single_body_only with National Highways",
        category => 'Street lighting',
        councils => [ 1000 ],
        extra_fields => { single_body_only => 'National Highways' },
        email_count => 1,
    },
    {
        desc => "test prefer_if_multiple only sends to one body",
        category => 'Street lighting',
        councils => [ 2326 ],
        extra_fields => {},
        email_count => 1,
        setup => sub {
            # $contact10 is Cheltenham Borough Council (2326)
            $contact10->set_extra_metadata(prefer_if_multiple => 1);
            $contact10->update;
        },
    },
) {
    subtest $test->{desc} => sub {
        if ($test->{setup}) {
            $test->{setup}->();
        }

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
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR', } },
                "submit location" );

            # click through to the report page
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
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
                    photo1        => '',
                    photo2        => '',
                    photo3        => '',
                    category      => undef,
                },
                "user's details prefilled"
            );

            $mech->submit_form_ok(
                {
                    with_fields => {
                        title         => "Test Report at café",
                        detail        => 'Test report details.',
                        photo1        => '',
                        name          => 'Joe Bloggs',
                        may_show_name => '1',
                        phone         => '07903 123 456',
                        category      => $test->{category},
                        %{$test->{extra_fields}}
                    }
                },
                "submit good details"
            );
        };

        # find the report
        my $report = $user->problems->first;
        ok $report, "Found the report";

        # Check the report has been assigned appropriately
        cmp_bag([ split ',', ($report->bodies_str || '') ], [ @body_ids{@{$test->{councils}}} ]);

        $mech->content_contains('Thank you for reporting this issue');

        # check that no emails have been sent
        $mech->email_count_is(0);

        # check report is confirmed and available
        is $report->state, 'confirmed', "report is now confirmed";
        $mech->get_ok( '/report/' . $report->id );

        # Test that AJAX pages return the right data
        $mech->get_ok(
            '/around?ajax=1&bbox=' . ($report->longitude - 0.01) . ',' .  ($report->latitude - 0.01)
            . ',' . ($report->longitude + 0.01) . ',' .  ($report->latitude + 0.01)
        );
        $mech->content_contains( "Test Report at caf\xc3\xa9" );
        $saved_lat = $report->latitude;
        $saved_lon = $report->longitude;

        # cleanup
        $mech->delete_user($user);
    };

}

subtest "Test inactive categories" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        BASE_URL => 'https://www.fixmystreet.com',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        # Around and New report have both categories
        $mech->get_ok('/around?pc=GL50+2PR');
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees');
        $mech->get_ok("/report/new?lat=$saved_lat&lon=$saved_lon");
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees');
        $contact2->update( { state => 'inactive' } ); # Potholes
        # But when Potholes is inactive, it's not on New report
        $mech->get_ok('/around?pc=GL50+2PR');
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees');
        $mech->get_ok("/report/new?lat=$saved_lat&lon=$saved_lon");
        $mech->content_lacks('Potholes');
        $mech->content_contains('Trees');
        # Change back
        $contact2->update( { state => 'confirmed' } );
    };
};

subtest "category groups" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            category_groups => { fixmystreet => 1 }
        }
    }, sub {
        $contact2->update( { extra => { group => ['Roads','Pavements'] } } );
        $contact9->update( { extra => { group => 'Pavements' } } );
        $contact10->update( { extra => { group => 'Roads' } } );
        $mech->get_ok("/report/new?lat=$saved_lat&lon=$saved_lon");

        my $div = '<div[^>]*>\s*';
        my $div_end = '</div>\s*';
        my $pavements_label = '<label[^>]* for="category_Pavements">Pavements</label>\s*' . $div_end;
        my $pavements_input = '<input[^>]* value="G|Pavements"\s+data-subcategory="Pavements">\s*';
        my $pavements_input_checked = '<input[^>]* value="G|Pavements"\s+data-subcategory="Pavements" checked>\s*';
        my $roads = $div . '<input[^>]* value="G|Roads"\s+data-subcategory="Roads">\s*<label[^>]* for="category_Roads">Roads</label>\s*' . $div_end;
        my $trees_label = '<label [^>]* for="category_\d+">Trees</label>\s*' . $div_end;
        my $trees_input = $div . '<input[^>]* value=\'Trees\'>\s*';
        my $trees_input_checked = $div . '<input[^>]* value=\'Trees\' checked>\s*';
        $mech->content_like(qr{$pavements_input$pavements_label$roads$trees_input$trees_label</fieldset>});
        my $streetlighting = $div . '<input[^>]*value=\'Street lighting\'>\s*<label[^>]* for="subcategory_(Roads|Pavements)_\d+">Street lighting</label>\s*' . $div_end;
        my $potholes_label = '<label[^>]* for="subcategory_(Roads|Pavements)_\d+">Potholes</label>\s*' . $div_end;
        my $potholes_input = $div . '<input[^>]* value=\'Potholes\'>\s*';
        my $potholes_input_checked = $div . '<input[^>]* value=\'Potholes\' checked>\s*';
        my $options = "$potholes_input$potholes_label$streetlighting</fieldset>";
        my $optionsS = "$potholes_input_checked$potholes_label$streetlighting</fieldset>";
        my $fieldset_pavements = '<fieldset[^>]*id="subcategory_Pavements">\s*<legend>Pavements: Subcategory</legend>\s*';
        my $fieldset_roads = '<fieldset[^>]*id="subcategory_Roads">\s*<legend>Roads: Subcategory</legend>\s*';
        $mech->content_like(qr{$fieldset_pavements$options});
        $mech->content_like(qr{$fieldset_roads$options});
        foreach my $key ('category', 'filter_group') { # Server-submission of top-level, or clicking on map with hidden field
            $mech->get_ok("/report/new?lat=$saved_lat&lon=$saved_lon&$key=Pavements");
            $mech->content_like(qr{$pavements_input_checked$pavements_label$roads$trees_input$trees_label</fieldset>});
            $mech->content_like(qr{$fieldset_pavements$options});
            $mech->content_like(qr{$fieldset_roads$options});
        }
        $mech->get_ok("/report/new?lat=$saved_lat&lon=$saved_lon&category=Trees");
        $mech->content_like(qr{$pavements_input$pavements_label$roads$trees_input_checked$trees_label</fieldset>});
        $mech->content_like(qr{$fieldset_pavements$options});
        $mech->content_like(qr{$fieldset_roads$options});
        # Server submission of pavement subcategory
        $mech->get_ok("/report/new?lat=$saved_lat&lon=$saved_lon&category=G|Pavements&category.Pavements=Potholes");
        $mech->content_like(qr{$pavements_input_checked$pavements_label$roads$trees_input$trees_label</fieldset>});
        $mech->content_like(qr{$fieldset_pavements$optionsS});
        $mech->content_like(qr{$fieldset_roads$options});

        $contact9->update( { extra => { group => 'Lights' } } );
        $mech->get_ok("/report/new?lat=$saved_lat&lon=$saved_lon");
        $streetlighting = $div . '<input[^>]*value=\'H|Lights\|Street lighting\'>\s*<label[^>]* for="category_\d+">Street lighting</label>\s*' . $div_end;
        $potholes_input = $div . '<input[^>]* value=\'H|Pavements\|Potholes\'>\s*';
        $potholes_label = '<label[^>]* for="category_\d+">Potholes</label>\s*' . $div_end;
        $mech->content_like(qr{$potholes_input$potholes_label$roads$streetlighting$trees_input$trees_label</fieldset>});
        $mech->content_unlike(qr{$fieldset_pavements});
        $mech->content_like(qr{$fieldset_roads$options});

        $mech->submit_form_ok({ with_fields => {
            category => 'H|Lights|Street lighting',
            title => 'Test Report',
            detail => 'Test report details',
            username_register => 'jo@example.org',
            name => 'Jo Bloggs',
        } });
        $mech->content_contains('Now check your email');
    };
};

subtest "category hints" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $contact2->update( { extra => { title_hint => 'Example summary', detail_hint => 'Example detail' } } );
        $mech->get_ok("/report/new?lat=$saved_lat&lon=$saved_lon");
        $mech->submit_form_ok( { with_fields => { category => 'Potholes' } } );
        $mech->content_contains('Example summary');
        $mech->content_contains('Example detail');
    };
};

subtest "test report creation for a category that is non public" => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;

    # check that the user does not exist
    my $test_email = 'test-2@example.com';

    my $user = $mech->create_user_ok($test_email);

    $contact1->update( { non_public => 1 } );

    # submit initial pc form
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_register',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    username_register => $user->email,
                    name          => 'Joe Bloggs',
                    category      => 'Street lighting',
                }
            },
            "submit good details"
        );
    };

    # find the report
    my $report = $user->problems->first;
    ok $report, "Found the report";

    # Check the report is not public
    ok $report->non_public, 'report is not public';

    my $email = $mech->get_email;
    ok $email, "got an email";
    like $mech->get_text_body_from_email($email), qr/confirm that you want to send your\s+report/i, "confirm the problem";

    my $url = $mech->get_link_from_email($email);

    # confirm token
    $mech->get_ok($url);
    $report->discard_changes;

    is $report->state, 'confirmed', "Report is now confirmed";

    $mech->logged_in_ok;
    $mech->get_ok( '/report/' . $report->id, 'user can see own report' );

    $mech->log_out_ok;
    ok $mech->get("/report/" . $report->id), "fetched report";
    is $mech->res->code, 403, "access denied to report";

    # cleanup
    $mech->delete_user($user);
    $contact1->update( { non_public => 0 } );
};

$contact2->category( "Pothol\x{00E9}s" );
$contact2->update;

subtest "check map click ajax response" => sub {
    my $extra_details;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?w=1&latitude=' . $saved_lat . '&longitude=' . $saved_lon );
    };
    # this order seems to be random so check individually/sort
    like $extra_details->{councils_text}, qr/Cheltenham Borough Council/, 'correct council text for two tier';
    like $extra_details->{councils_text}, qr/Gloucestershire County Council/, 'correct council text for two tier';
    like $extra_details->{category}, qr/Pothol\x{00E9}s.*Trees/s, 'category looks correct for two tier council';
    my @sorted_bodies = sort @{ $extra_details->{bodies} };
    is_deeply \@sorted_bodies, [ "Cheltenham Borough Council", "Gloucestershire County Council" ], 'correct bodies for two tier';
    ok !$extra_details->{titles_list}, 'Non Bromley does not send back list of titles';

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=51.4021&longitude=0.01578');
    };
    ok $extra_details->{titles_list}, 'Bromley sends back list of titles';
    like $extra_details->{councils_text}, qr/Bromley Council/, 'correct council text';
    like $extra_details->{councils_text_private}, qr/^These details will be sent to the council, but will never be shown online/, 'correct private council text';
    like $extra_details->{category}, qr/Trees/, 'category looks correct';
    is_deeply $extra_details->{bodies}, [ "Bromley Council" ], 'correct bodies';
    ok !$extra_details->{contribute_as}, 'no contribute as section';
    ok !$extra_details->{top_message}, 'no top message';
    ok $extra_details->{extra_name_info}, 'extra name info';

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=52.563074&longitude=-1.991032' );
    };
    like $extra_details->{councils_text}, qr/^These will be published online for others to see/, 'correct council text for council with no contacts';
    is $extra_details->{category}, '', 'category is empty for council with no contacts';
    is_deeply $extra_details->{bodies}, [ "Sandwell Borough Council" ], 'correct bodies for council with no contacts';
    ok !$extra_details->{extra_name_info}, 'no extra name info';

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'hounslow',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=51.482286&longitude=-0.328163' );
    };
    is_deeply $extra_details->{display_names}, { 'Hounslow Borough Council' => 'Hounslow Highways' }, 'council display name mapping correct';

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'hounslownoname',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=51.482286&longitude=-0.328163' );
    };
    isnt defined $extra_details->{display_names}, 'no council display names if none defined';

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'hounslow',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=51.482286&longitude=-0.328163' );
    };
    ok $extra_details->{by_category}->{'General Enquiry'}->{non_public}, 'non_public set correctly for private category';
    isnt defined $extra_details->{by_category}->{Tree}->{non_public}, 'non_public omitted for public category';
};

#### test uploading an image

#### test completing a partial report (eq flickr upload)

#### possibly manual testing
# create report without using map
# create report by clicking on map with javascript off
# create report with images off

subtest "check we load a partial report correctly" => sub {
    my $user = FixMyStreet::DB->resultset('User')->find_or_create(
        {
            email => 'test-partial@example.com'
        }
    );

    my $report = FixMyStreet::DB->resultset('Problem')->create( {
        name               => '',
        postcode           => '',
        category           => 'Street lighting',
        title              => 'Testing',
        detail             => "Testing Detail",
        anonymous          => 0,
        state              => 'partial',
        lang               => 'en-gb',
        service            => '',
        areas              => '',
        used_map           => 1,
        latitude           => '51.754926',
        longitude          => '-1.256179',
        user_id            => $user->id,
    } );

    my $report_id = $report->id;

    my $token = FixMyStreet::DB->resultset("Token")
        ->create( { scope => 'partial', data => $report->id } );

    my $token_code = $token->token;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    },
    sub {
        $mech->get("/L/$token_code");
        is $mech->res->previous->code, 302, 'partial token page redirects';
        is $mech->uri->path, "/report/new", "partial redirects to report page";
        $mech->content_contains('Testing Detail');
    };

    $mech->delete_user($user);
};

for my $test (
    {
        desc  => 'user title not set if not bromley problem',
        host  => 'www.fixmystreet.com',
        postcode => 'EH1 1BB',
        fms_extra_title => '',
        extra => [],
        user_title => undef,
    },
    {
        desc  => 'title shown for bromley problem on main site',
        host  => 'www.fixmystreet.com',
        postcode => 'BR1 3UH',
        fms_extra_title => 'MR',
        extra => [
            {
                name        => 'fms_extra_title',
                value       => 'MR',
                description => 'FMS_EXTRA_TITLE',
            },
        ],
        user_title => 'MR',
    },
    {
        desc  => 'PCSO title shown for bromley problem on main site',
        host  => 'www.fixmystreet.com',
        postcode => 'BR1 3UH',
        fms_extra_title => 'PCSO',
        extra => [
            {
                name        => 'fms_extra_title',
                value       => 'PCSO',
                description => 'FMS_EXTRA_TITLE',
            },
        ],
        user_title => 'PCSO',
    },
    {
        desc =>
          'title, first and last name shown for bromley problem on cobrand',
        host       => 'bromley.fixmystreet.com',
        postcode => 'BR1 3UH',
        first_name => 'Test',
        last_name  => 'User',
        fms_extra_title => 'MR',
        extra      => [
            {
                name        => 'fms_extra_title',
                value       => 'MR',
                description => 'FMS_EXTRA_TITLE',
            },
            {
                name        => 'first_name',
                value       => 'Test',
                description => 'FIRST_NAME',
            },
            {
                name        => 'last_name',
                value       => 'User',
                description => 'LAST_NAME',
            },
        ],
        user_title => 'MR',
    },
  )
{
    subtest $test->{desc} => sub {
        my $override = {
            ALLOWED_COBRANDS => [ $test->{host} =~ /bromley/ ? 'bromley' : 'fixmystreet' ],
            MAPIT_URL => 'http://mapit.uk/',
        };

        $mech->host( $test->{host} );

        $mech->log_out_ok;
        $mech->clear_emails_ok;

        $mech->get_ok('/');
        FixMyStreet::override_config $override, sub {
            $mech->submit_form_ok( { with_fields => { pc => $test->{postcode}, } },
                "submit location" );
            $mech->follow_link_ok(
                { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link"
            );
        };

        my $fields = $mech->visible_form_values('mapSkippedForm');
        if ( $test->{fms_extra_title} ) {
            ok exists( $fields->{fms_extra_title} ), 'user title field displayed';
        } else {
            ok !exists( $fields->{fms_extra_title} ), 'user title field not displayed';
        }
        if ( $test->{first_name} ) {
            ok exists( $fields->{first_name} ), 'first name field displayed';
            ok exists( $fields->{last_name} ),  'last name field displayed';
            ok !exists( $fields->{name} ), 'no name field displayed';
        }
        else {
            ok !exists( $fields->{first_name} ),
              'first name field not displayed';
            ok !exists( $fields->{last_name} ), 'last name field not displayed';
            ok exists( $fields->{name} ), 'name field displayed';
        }

        my $submission_fields = {
            title             => "Test Report",
            detail            => 'Test report details.',
            photo1            => '',
            username_register => 'firstlast@example.com',
            may_show_name     => '1',
            phone             => '07903 123 456',
            category          => 'Trees',
            password_register => '',
        };

        $submission_fields->{fms_extra_title} = $test->{fms_extra_title}
            if $test->{fms_extra_title};

        if ( $test->{first_name} ) {
            $submission_fields->{first_name} = $test->{first_name};
            $submission_fields->{last_name}  = $test->{last_name};
        }
        else {
            $submission_fields->{name} = 'Test User';
        }

        FixMyStreet::override_config $override, sub {
            $mech->submit_form_ok( { with_fields => $submission_fields },
                "submit good details" );
        };

        my $email = $mech->get_email;
        ok $email, "got an email";
        like $mech->get_text_body_from_email($email), qr/confirm that you want to send your\s+report/i, "confirm the problem";

        my $url = $mech->get_link_from_email($email);

        # confirm token in order to update the user details
        $mech->get_ok($url);

        my $user = FixMyStreet::DB->resultset('User')->find( { email => 'firstlast@example.com' } );

        my $report = $user->problems->first;
        ok $report, "Found the report";
        my $extras = $report->get_extra_fields;
        is $user->title, $test->{'user_title'}, 'user title correct';
        is_deeply $extras, $test->{extra}, 'extra contains correct values';

        $mech->delete_user($user);
    };
}

subtest 'user title not reset if no user title in submission' => sub {
        $mech->log_out_ok;
        $mech->host( 'www.fixmystreet.com' );

        my $user = $mech->log_in_ok( 'userwithtitle@example.com' );

        ok $user->update(
            {
                name => 'Has Title',
                phone => '0789 654321',
                title => 'MR',
            }
        ),
        "set users details";


        my $submission_fields = {
            title             => "Test Report",
            detail            => 'Test report details.',
            photo1            => '',
            name              => 'Has Title',
            may_show_name     => '1',
            phone             => '07903 123 456',
            category          => 'Trees',
        };

        $mech->get_ok('/');
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
                "submit location" );
            $mech->follow_link_ok(
                { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link"
            );

            my $fields = $mech->visible_form_values('mapSkippedForm');
            ok !exists( $fields->{fms_extra_title} ), 'user title field not displayed';

            $mech->submit_form_ok( { with_fields => $submission_fields },
                "submit good details" );
        };

        $user->discard_changes;
        my $report = $user->problems->first;
        ok $report, "Found report";
        is $report->title, "Test Report", "Report title correct";
        is $user->title, 'MR', 'User title unchanged';
};

subtest "test Hart" => sub {
    for my $test (
        {
            desc      => 'confirm link for cobrand council in two tier cobrand links to cobrand site',
            category  => 'Trees',
            council   => 2333,
            national  => 0,
            button    => 'submit_register',
        },
          {
            desc      => 'confirm link for non cobrand council in two tier cobrand links to national site',
            category  => 'Street Lighting',
            council   => 2227,
            national  => 1,
            button    => 'submit_register',
          },
          {
            desc      => 'confirmation page for cobrand council in two tier cobrand links to cobrand site',
            category  => 'Trees',
            council   => 2333,
            national  => 0,
            confirm  => 1,
          },
          {
            desc      => 'confirmation page for non cobrand council in two tier cobrand links to national site',
            category  => 'Street Lighting',
            council   => 2227,
            national  => 1,
            confirm  => 1,
          },
    ) {
        subtest $test->{ desc } => sub {
            my $test_email = 'test-22@example.com';
            $mech->host( 'hart.fixmystreet.com' );
            $mech->clear_emails_ok;
            $mech->log_out_ok;

            my $user = $mech->log_in_ok($test_email) if $test->{confirm};

            FixMyStreet::override_config {
                ALLOWED_COBRANDS => [ 'hart', 'fixmystreet' ],
                BASE_URL => 'http://www.fixmystreet.com',
                MAPIT_URL => 'http://mapit.uk/',
            }, sub {
                $mech->get_ok('/around');
                $mech->content_contains( "Hart District Council" );
                $mech->submit_form_ok( { with_fields => { pc => 'GU51 4AE' } }, "submit location" );
                $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
                my %optional_fields = $test->{confirm} ?  () :
                    ( username_register => $test_email, phone => '07903 123 456' );

                # we do this as otherwise test::www::mechanize::catalyst
                # goes to the value set in ->host above irregardless and
                # that is a 404. It works but it is not pleasant.
                $mech->clear_host if $test->{confirm} && $test->{national};
                $mech->submit_form_ok(
                    {
                        button      => $test->{button},
                        with_fields => {
                            title         => 'Test Report',
                            detail        => 'Test report details.',
                            photo1        => '',
                            name          => 'Joe Bloggs',
                            may_show_name => '1',
                            category      => $test->{category},
                            %optional_fields
                        }
                    },
                    "submit good details"
                );
            };
            is_deeply $mech->page_errors, [], "check there were no errors";

            # check that the user has been created/ not changed
            $user =
              FixMyStreet::DB->resultset('User')->find( { email => $user ? $user->email : $test_email } );
            ok $user, "user found";

            # find the report
            my $report = $user->problems->first;
            ok $report, "Found the report";

            # Check the report has been assigned appropriately
            is $report->bodies_str, $body_ids{$test->{council}};

            if ( $test->{confirm} ) {
                is $mech->uri->path, "/report/confirmation/" . $report->id;
                my $base = 'www.fixmystreet.com';
                $base = '"' unless $test->{national};
                $mech->content_contains("$base/report/" . $report->id, "links to correct site");
            } else {
                # receive token
                my $email = $mech->get_email;
                ok $email, "got an email";
                my $body = $mech->get_text_body_from_email($email);
                like $body, qr/to confirm that you want to send your/i, "confirm the problem";

                # does it reference the fact that this report hasn't been sent to Hart?
                if ( $test->{national} ) {
                    like $body, qr/Hart District Council is not responsible for this type/i, "mentions report hasn't gone to Hart";
                } else {
                    unlike $body, qr/Hart District Council is not responsible for this type/i, "doesn't mention report hasn't gone to Hart";
                }

                my $url = $mech->get_link_from_email($email);

                # confirm token
                FixMyStreet::override_config {
                    ALLOWED_COBRANDS => [ 'hart', 'fixmystreet' ],
                    BASE_URL => 'http://www.fixmystreet.com',
                }, sub {
                    $mech->get_ok($url);
                };

                my $base = 'www.fixmystreet.com';
                $base = '"' unless $test->{national};
                $mech->content_contains( $base . '/report/' .
                    $report->id, 'confirm page links to correct site' );

                if ( $test->{national} ) {
                    # Shouldn't be found, as it was a county problem
                    FixMyStreet::override_config {
                        ALLOWED_COBRANDS => [ 'hart', 'fixmystreet' ],
                    }, sub {
                        is $mech->get( '/report/' . $report->id )->code, 404, "report not found";
                    };

                    # But should be on the main site
                    $mech->host( 'www.fixmystreet.com' );
                }
                FixMyStreet::override_config {
                    ALLOWED_COBRANDS => [ 'hart', 'fixmystreet' ],
                }, sub {
                    $mech->get_ok( '/report/' . $report->id );
                };
            }

            $report->discard_changes;
            is $report->state, 'confirmed', "Report is now confirmed";

            is $report->name, 'Joe Bloggs', 'name updated correctly';

            $mech->delete_user($user);
        };
    }
};

subtest "report confirmation page" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my ($report, $report2) = $mech->create_problems_for_body(2, $body_ids{2226}, 'Title',{
            category => 'Potholes', cobrand => 'fixmystreet',
            dt => DateTime->now(time_zone => FixMyStreet->time_zone || FixMyStreet->local_time_zone),
        });
        $report->discard_changes;

        my $token = $report->confirmation_token;

        subtest "going to confirmation page with valid token works" => sub {
            $mech->get_ok("/report/confirmation/" . $report->id . "?token=$token");
            $mech->content_contains($report->title);
            $mech->content_contains("Thank you for reporting this issue!");
        };

        subtest "going to confirmation page without token shows 404" => sub {
            $mech->get("/report/confirmation/" . $report->id);
            is $mech->res->code, 404, "got 404";
            $mech->content_lacks($report->title);
            $mech->content_lacks("Thank you for reporting this issue!");
        };

        subtest "going to this page with invalid token shows 404" => sub {
            $mech->get("/report/confirmation/" . $report->id . "?token=blahblah");
            is $mech->res->code, 404, "got 404";
            $mech->content_lacks($report->title);
            $mech->content_lacks("Thank you for reporting this issue!");
        };

        subtest "unconfirming the report and going to its confirmation page shows the 'check email' message" => sub {
            $report->update({ confirmed => undef });
            $mech->get_ok("/report/confirmation/" . $report->id . "?token=$token");
            $mech->content_contains("Nearly done! Now check your email");
            $mech->content_lacks($report->title);
            $mech->content_lacks("Thank you for reporting this issue!");
        };

        subtest "going to another report page with this valid token shows 404" => sub {
            $mech->get("/report/confirmation/" . $report2->id . "?token=$token");
            is $mech->res->code, 404, "got 404";
            $mech->content_lacks($report->title);
            $mech->content_lacks("Thank you for reporting this issue!");
        };

        subtest "going to confirmation page now redirects to the report page" => sub {
            # make report 10 minutes old and regenerate token
            my $created = $report->created->subtract({ minutes => 45 });
            $report->update({ created => $created, confirmed => $created });
            $token = $report->confirmation_token;
            $mech->get_ok("/report/confirmation/" . $report->id . "?token=$token");
            is $mech->res->code, 200, "got 200";
            is $mech->res->previous->code, 302, "got 302 for redirect";
            is $mech->uri->path, '/report/' . $report->id, 'redirected to report page';
        };
    };
};

subtest "categories from deleted bodies shouldn't be visible for new reports" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/report/new/ajax?latitude=51.896268&longitude=-2.093063'); # Cheltenham
        ok $mech->content_contains( $contact3->category );

        # Delete the body which the contact belongs to.
        $contact3->body->update( { deleted => 1 } );

        $mech->get_ok('/report/new/ajax?latitude=51.896268&longitude=-2.093063'); # Cheltenham
        ok $mech->content_lacks( $contact3->category );

        $contact3->body->update( { deleted => 0 } );
    };
};

subtest "check field overrides for categories" => sub {
    my $body = $mech->create_body_ok(2238, "A", {}, { cobrand => "overrides" });
    my $contact = $mech->create_contact_ok(
        body_id => $body->id,
        category => 'test',
        email => 'test@example.org',
    );
    my $lat = "52.855684";
    my $long = "-2.723877";

    my $json_response;

    # Cobrand level overrides apply when the category has a single body with that cobrand.

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'overrides',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $json_response = $mech->get_ok_json( '/report/new/ajax?w=1&latitude=' . $lat . '&longitude=' . $long );
    };
    is $json_response->{by_category}->{test}->{title_label}, "cobrand title label", "cobrand title label applied";
    is $json_response->{by_category}->{test}->{title_hint}, "cobrand title hint", "cobrand title hint override applied";
    is $json_response->{by_category}->{test}->{detail_label}, "cobrand detail label", "cobrand detail label override applied";
    is $json_response->{by_category}->{test}->{detail_hint}, "cobrand detail hint", "cobrand detail hint override applied";

    # Contact level overrides supersede cobrand level ones.

    $contact->set_extra_metadata('title_hint', 'contact title hint');
    $contact->set_extra_metadata('detail_label', 'contact detail label');
    $contact->set_extra_metadata('detail_hint', 'contact detail hint');
    $contact->update;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'overrides',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $json_response = $mech->get_ok_json( '/report/new/ajax?w=1&latitude=' . $lat . '&longitude=' . $long );
    };
    is $json_response->{by_category}->{test}->{title_label}, "cobrand title label", "cobrand title label override applied";
    is $json_response->{by_category}->{test}->{title_hint}, "contact title hint", "contact title hint override applied";
    is $json_response->{by_category}->{test}->{detail_label}, "contact detail label", "contact detail label override applied";
    is $json_response->{by_category}->{test}->{detail_hint}, "contact detail hint", "contact detail hint override applied";

    # Cobrand level overrides don't apply if the category has multiple bodies.

    $contact->unset_extra_metadata('title_hint');
    $contact->unset_extra_metadata('detail_label');
    $contact->unset_extra_metadata('detail_hint');
    $contact->update;

    my $second_body = $mech->create_body_ok(2238, "B", {}, {});
    my $second_contact = $mech->create_contact_ok(
        body_id => $second_body->id,
        category => 'test',
        email => 'test@example.org',
    );

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'overrides',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $json_response = $mech->get_ok_json( '/report/new/ajax?w=1&latitude=' . $lat . '&longitude=' . $long );
    };
    is $json_response->{by_category}->{test}->{title_label}, undef, "cobrand title label override not applied";
    is $json_response->{by_category}->{test}->{title_hint}, undef, "title hint override not applied";
    is $json_response->{by_category}->{test}->{detail_label}, undef, "detail label override not applied";
    is $json_response->{by_category}->{test}->{detail_hint}, undef, "detail hint override not applied";
};

subtest "confirmation links log a user in within 30 seconds of first use" => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;

    set_fixed_time('2023-08-03T17:00:00Z');

    my $test_email = 'confirmation-links-test@example.com';
    my $user = $mech->create_user_ok($test_email);

    # submit form
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_register',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    username_register => $user->email,
                    name          => 'Joe Bloggs',
                    category      => 'Street lighting',
                }
            },
            "submit good details"
        );
    };
    my $email = $mech->get_email;
    ok $email, "got an email";
    like $mech->get_text_body_from_email($email), qr/confirm that you want to send your\s+report/i, "confirm the problem";

    my $url = $mech->get_link_from_email($email);

    # first visit
    $mech->get_ok($url);
    $mech->logged_in_ok;
    $mech->log_out_ok;

    # immediately again...
    $mech->get_ok($url);
    $mech->logged_in_ok;
    $mech->log_out_ok;

    # after 30 seconds...
    set_fixed_time('2023-08-03T17:00:31Z');
    $mech->get_ok($url);
    $mech->not_logged_in_ok;

    # cleanup
    $mech->delete_user($user);
};

done_testing();
