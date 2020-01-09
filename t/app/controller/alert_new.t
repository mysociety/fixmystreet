use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;

my $mech = FixMyStreet::TestMech->new;

my $user = FixMyStreet::App->model('DB::User')
          ->new( { email => 'test@example.com' } );

my $body = $mech->create_body_ok(2651, 'Edinburgh Council');
my ($report) = $mech->create_problems_for_body(1, $body->id, 'Existing');

foreach my $test (
    {
        email      => $user->email,
        type       => 'area_problems',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => "confirms that you'd like to receive an email",
        uri =>
'/alert/subscribe?type=local&rznvy=' . $user->email . '&feed=area:1000:A_Location',
        param1 => 1000
    },
    {
        email      => $user->email,
        type       => 'council_problems',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => "confirms that you'd like to receive an email",
        uri =>
'/alert/subscribe?type=local&rznvy=' . $user->email . '&feed=council:1000:A_Location',
        param1 => 1000,
        param2 => 1000,
    },
    {
        email      => $user->email,
        type       => 'ward_problems',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => "confirms that you'd like to receive an email",
        uri =>
'/alert/subscribe?type=local&rznvy=' . $user->email . '&feed=ward:1000:1001:A_Location:Diff_Location',
        param1 => 1000,
        param2 => 1001,
    },
    {
        email      => $user->email,
        type       => 'local_problems',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => "confirms that you'd like to receive an email",
        uri =>
'/alert/subscribe?type=local&rznvy=' . $user->email . '&feed=local:10.2:20.1',
        param1 => 20.1,
        param2 => 10.2,
    },
    {
        email      => $user->email,
        type       => 'new_updates',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => "confirms that you'd like to receive an email",
        uri    => '/alert/subscribe?type=updates&rznvy=' . $user->email . '&id=' . $report->id,
        param1 => $report->id,
    }
  )
{
    subtest "$test->{type} alert correctly created" => sub {
        $mech->clear_emails_ok;

        my $type = $test->{type};

        $mech->get_ok('/alert/subscribe?id=' . $report->id);
        my ($csrf) = $mech->content =~ /name="token" value="([^"]*)"/;

        $mech->get_ok( $test->{uri} . "&token=$csrf" );
        $mech->content_contains( $test->{content} );

        my $user =
          FixMyStreet::DB->resultset('User')
          ->find( { email => $test->{email} } );

        ok $user, 'user created for alert';

        my $alert = FixMyStreet::DB->resultset('Alert')->find(
            {
                user       => $user,
                alert_type => $type,
                parameter  => $test->{param1},
                parameter2 => $test->{param2},
                confirmed  => 0,
            }
        );

        ok $alert, "Found the alert";

        my $email = $mech->get_email;
        ok $email, "got an email";
        like $mech->get_text_body_from_email($email), qr/$test->{email_text}/i, "Correct email text";

        my $url = $mech->get_link_from_email($email);
        my ($url_token) = $url =~ m{/A/(\S+)};
        ok $url, "extracted confirm url '$url'";

        my $token = FixMyStreet::DB->resultset('Token')->find(
            {
                token => $url_token,
                scope => 'alert'
            }
        );
        ok $token, 'Token found in database';
        ok $alert->id == $token->data->{id}, 'token alertid matches alert id';

        $mech->clear_emails_ok;

        my $existing_id    = $alert->id;
        my $existing_token = $url_token;

        $mech->get_ok( $test->{uri} . "&token=$csrf" );

        $url = $mech->get_link_from_email;
        ($url_token) = $url =~ m{/A/(\S+)};
        ok $url_token ne $existing_token, 'sent out a new token';

        $token = FixMyStreet::DB->resultset('Token')->find(
            {
                token => $url_token,
                scope => 'alert'
            }
        );

        ok $token, 'new token found in database';
        ok $token->data->{id} == $existing_id, 'subscribed to existing alert';

        $mech->get_ok("/A/$url_token");
        $mech->content_contains('alert created');

        $alert =
          FixMyStreet::DB->resultset('Alert')->find( { id => $existing_id, } );

        ok $alert->confirmed, 'alert set to confirmed';
        $mech->delete_user($user);
    };
}

foreach my $test (
    { exist => 0 },
    { exist => 1 },
  )
{
    subtest "use existing unlogged in user in a alert ($test->{exist})" => sub {
        $mech->log_out_ok();

        my $type = 'area_problems';

        my $user = $mech->create_user_ok('test-new@example.com');

        my $alert = FixMyStreet::DB->resultset('Alert')->find(
            {
                user       => $user,
                alert_type => $type
            }
        );
        # clear existing data so we can be sure we're creating it
        ok $alert->delete() if $alert && !$test->{exist};

        $mech->get_ok('/alert/subscribe?id=' . $report->id);
        my ($csrf) = $mech->content =~ /name="token" value="([^"]*)"/;

        $mech->get_ok( '/alert/subscribe?type=local&rznvy=' . $user->email . '&feed=area:1000:A_Location&token=' . $csrf );

        $alert = FixMyStreet::DB->resultset('Alert')->find(
            {
                user       => $user,
                alert_type => $type,
                parameter  => 1000,
                parameter2 => undef,
                confirmed  => $test->{exist},
            }
        );

        $mech->content_contains( 'Now check your email' );

        $alert->confirm();
        ok $alert, 'New alert created with existing user';

        $mech->delete_user($user) if $test->{exist};
    };
}

foreach my $test (
    {
        desc       => 'logged in user signing up',
        email      => 'test-sign-in@example.com',
        type       => 'council',
        param1     => $body->id,
        param2     => $body->id,
        confirmed  => 1,
    }
  )
{
    subtest $test->{desc} => sub {
        my $type = $test->{type} . '_problems';

        my $user = $mech->create_user_ok($test->{email});

        $mech->log_in_ok( $test->{email} );
        $mech->clear_emails_ok;

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'fixmystreet',
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/alert/list?pc=EH11BB');
        };
        $mech->set_visible( [ radio => 'council:' . $body->id . ':City_of_Edinburgh' ] );
        $mech->click('alert');

        my $alert = FixMyStreet::DB->resultset('Alert')->find(
            {
                user       => $user,
                alert_type => $type,
                parameter  => $test->{param1},
                parameter2 => $test->{param2},
                confirmed  => $test->{confirmed},
            }
        );

        ok $alert, 'New alert created with logged in user';
        $mech->email_count_is( 0 );
        $mech->delete_user($user);
    };
}

for my $test (
    {
        email      => $user->email,
        type       => 'new_updates',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => 'confirm the alert',
        uri    => '/alert/subscribe?type=updates&rznvy=' . $user->email . '&id=' . $report->id,
        param1 => $report->id,
    }
  )
{
    subtest "cannot sign up for alert if in abuse table" => sub {
        $mech->clear_emails_ok;

        my $type = $test->{type};

        my $user =
          FixMyStreet::DB->resultset('User')
          ->find( { email => $test->{email} } );

        # we don't want an alert
        my $alert;
        if ($user) {
            $mech->delete_user($user);
        }

        my $abuse =
          FixMyStreet::DB->resultset('Abuse')
          ->find_or_create( { email => $test->{email} } );

        $mech->get_ok('/alert/subscribe?id=' . $report->id);
        my ($csrf) = $mech->content =~ /name="token" value="([^"]*)"/;

        $mech->get_ok( $test->{uri} . "&token=$csrf" );
        $mech->content_contains( $test->{content} );

        $user =
          FixMyStreet::DB->resultset('User')
          ->find( { email => $test->{email} } );

        ok $user, 'user created for alert';

        $alert = FixMyStreet::DB->resultset('Alert')->find(
            {
                user       => $user,
                alert_type => $type,
                parameter  => $test->{param1},
                parameter2 => $test->{param2},
                confirmed  => 0,
            }
        );

        ok $alert, "Found the alert";

        $mech->clear_emails_ok;

        ok !$alert->confirmed, 'alert not set to confirmed';

        $abuse->delete;
        $mech->delete_user($user);
    };
}

subtest 'Test body user signing someone else up for alerts' => sub {
    my $staff_user = $mech->create_user_ok('astaffuser@example.com', name => 'A staff user', from_body => $body);
    $mech->log_in_ok($staff_user->email);

    $mech->get_ok('/alert/subscribe?id=' . $report->id);
    my ($csrf) = $mech->content =~ /name="token" value="([^"]*)"/;
    $mech->post_ok('/alert/subscribe', { rznvy => 'someoneelse@example.org', id => $report->id, type => 'updates', token => $csrf });

    my $user = FixMyStreet::DB->resultset('User')->find({ email => 'someoneelse@example.org' });
    is $user, undef, 'No user made by bad request';

    my $alert = FixMyStreet::DB->resultset('Alert')->find({
        user       => $staff_user,
        alert_type => 'new_updates',
        parameter  => $report->id,
        confirmed  => 1,
    });
    ok $alert, 'New alert created with logged in user';
    $alert->delete;

    $staff_user->user_body_permissions->create({ permission_type => 'contribute_as_another_user', body => $body });
    $mech->get_ok('/alert/subscribe?id=' . $report->id);
    $mech->submit_form_ok({ with_fields => { rznvy => 'someoneelse@example.org' } });
    $mech->content_contains('Email alert created');

    $user = FixMyStreet::DB->resultset('User')->find({ email => 'someoneelse@example.org' });
    ok $user, 'user created for alert';

    $alert = FixMyStreet::DB->resultset('Alert')->find({
        user       => $user,
        alert_type => 'new_updates',
        parameter  => $report->id,
        confirmed  => 1,
    });
    ok $alert, 'New alert created for another user';

    $alert = FixMyStreet::DB->resultset('Alert')->find({
        user       => $staff_user,
        alert_type => 'new_updates',
        parameter  => $report->id,
        confirmed  => 1,
    });
    is $alert, undef, 'No alert created for staff user';
};

$report->delete; # Emails sent otherwise below

my $gloucester = $mech->create_body_ok(2226, 'Gloucestershire County Council');
$mech->create_body_ok(2326, 'Cheltenham Borough Council');

subtest "Test two-tier council alerts" => sub {
    for my $alert (
        { feed => "local:51.896269:-2.093063",          result => '/rss/l/51.896269,-2.093063' },
        { feed => "area:2326:Cheltenham",               result => '/rss/area/Cheltenham' },
        { feed => "area:2326:4544:Cheltenham:Lansdown", result => '/rss/area/Cheltenham/Lansdown'  },
        { feed => "area:2226:Gloucestershire",          result => '/rss/area/Gloucestershire' },
        { feed => "area:2226:14949:Gloucestershire:Lansdown_and_Park",
          result => '/rss/area/Gloucestershire/Lansdown+and+Park'
        },
        { feed => "council:2326:Cheltenham",            result => '/rss/reports/Cheltenham' },
        { feed => "ward:2326:4544:Cheltenham:Lansdown", result => '/rss/reports/Cheltenham/Lansdown' },
        { feed => "council:2226:Gloucestershire",       result => '/rss/reports/Gloucestershire' },
        { feed => "ward:2226:14949:Gloucestershire:Lansdown_and_Park",
          result => '/rss/reports/Gloucestershire/Lansdown+and+Park'
        },
    ) {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'fixmystreet',
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok( '/alert/list?pc=GL502PR' );
            $mech->submit_form_ok( {
                button => 'rss',
                with_fields => {
                    feed => $alert->{feed},
                }
            } );
        };
        is $mech->uri->path, $alert->{result}, 'Redirected to right RSS feed';
    }
};

subtest "Test normal alert signups and that alerts are sent" => sub {
    my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User' );
    my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User' );

    for my $alert (
        {
            fields => {
                feed => 'local:55.951963:-3.189944',
                rznvy => $user2->email,
            },
            email_confirm => 1
        },
        {
            fields => {
                feed => 'area:2651:City_of_Edinburgh',
            }
        },
    ) {
        $mech->get_ok( '/alert' );
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'fixmystreet',
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => 'EH11BB' } } );
            $mech->submit_form_ok( {
                button => 'alert',
                with_fields => $alert->{fields},
            } );
        };
        if ( $alert->{email_confirm} ) {
            my $url = $mech->get_link_from_email;
            my ($url_token) = $url =~ m{/A/(\S+)};
            $mech->clear_emails_ok;
            my $token = FixMyStreet::DB->resultset('Token')->find( { token => $url_token, scope => 'alert' } );
            $mech->get_ok( $url );
            $mech->content_contains('alert created');
        } else {
            $mech->content_contains('alert created');
        }
    }

    my $dt = DateTime->now()->add(days => 2);

    my ($report) = $mech->create_problems_for_body(1, 1, 'Testing', {
        dt => $dt,
        user => $user1,
        postcode           => 'EH1 1BB',
        areas              => ',11808,135007,14419,134935,2651,20728,',
        category           => 'Street lighting',
        state              => 'fixed - user',
        lastupdate         => $dt,
        whensent           => $dt->clone->add( minutes => 5 ),
        latitude           => '55.951963',
        longitude          => '-3.189944',
    });
    my $report_id = $report->id;
    ok $report, "created test report - $report_id";

    subtest 'check signing up for alerts via report page' => sub {
        $mech->log_in_ok($user1->email);
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'alert', with_fields => { type => 'updates' } });
    };

    $mech->create_comment_for_problem($report, $user2, 'Other User', 'This is some update text', 'f', 'confirmed', undef, { confirmed  => $dt->clone->add( hours => 7 ) });
    $mech->create_comment_for_problem($report, $user2, 'Anonymous User', 'This is some more update text', 't', 'confirmed', 'fixed - user', { confirmed  => $dt->clone->add( hours => 8 ) });

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        FixMyStreet::Script::Alerts::send();
    };
    # TODO Note the below will fail if the db has an existing alert that matches
    $mech->email_count_is(3);
    my @emails = $mech->get_email;
    my $count;
    for (@emails) {
        my $body = $mech->get_text_body_from_email($_);
        $count++ if $body =~ /The following updates have been left on this report:/;
        $count++ if $body =~ /The following new FixMyStreet reports have been added in the Area 2651 area:/;
        $count++ if $body =~ /The following FixMyStreet reports have been made within the area you\s+specified:/;
        $count++ if $body =~ /\s+-\s+Testing/;
    }
    is $count, 5, 'Three emails, with five matching lines in them';

    my $email = $emails[0];
    is +(my $c = () = $email->as_string =~ /Other User/g), 2, 'Update name given, twice';
    unlike $email->as_string, qr/Anonymous User/, 'Update name not given';

    $report->discard_changes;
    ok $report->get_extra_metadata('closure_alert_sent_at'), 'Closure time set';

    # The update alert was to the problem reporter, so has a special update URL
    $mech->log_out_ok;
    $mech->get_ok( "/report/$report_id" );
    $mech->content_lacks( 'has not been fixed' );
    my @urls = $mech->get_link_from_email($email, 1);
    ok $urls[0] =~ m{/R/\S+}, "extracted update url '$urls[0]'";
    $mech->get_ok( $urls[0] );
    is $mech->uri->path, "/report/" . $report_id, "redirected to report page";
    $mech->content_contains( 'has not been fixed' );
    $mech->not_logged_in_ok;

    ok $urls[-1] =~ m{/A/\S+}, "unsubscribe URL '$urls[-1]'";
    $mech->get_ok( $urls[-1] );
    $mech->content_contains('alert deleted');
    $mech->not_logged_in_ok;

    $mech->delete_user($user1);
    $mech->delete_user($user2);
};

subtest "Test alerts are not sent for no-text updates" => sub {
    my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User' );
    my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User' );
    my $user3 = $mech->create_user_ok('staff@example.com', name => 'Staff User', from_body => $gloucester );
    my $dt = DateTime->now()->add(days => 2);

    my ($report, $report2) = $mech->create_problems_for_body(2, 1, 'Testing', {
        user => $user1,
    });
    my $report_id = $report->id;
    ok $report, "created test report - $report_id";
    my $report2_id = $report2->id;
    ok $report2, "created test report - $report2_id";

    # Must be first
    my $alert2 = FixMyStreet::DB->resultset('Alert')->create( {
        parameter  => $report2_id,
        alert_type => 'new_updates',
        user       => $user2,
    } )->confirm;
    ok $alert2, 'created alert for other user';

    my $alert = FixMyStreet::DB->resultset('Alert')->create( {
        parameter  => $report_id,
        alert_type => 'new_updates',
        user       => $user2,
    } )->confirm;
    ok $alert, 'created alert for other user';

    $mech->create_comment_for_problem($report, $user3, 'Staff User', '', 'f', 'confirmed', undef, { confirmed  => $dt->clone->add( hours => 9 ) });
    $mech->create_comment_for_problem($report2, $user3, 'Staff User', 'This is a normal update', 'f', 'confirmed', undef, { confirmed  => $dt->clone->add( hours => 9 ) });

    $mech->clear_emails_ok;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        FixMyStreet::Script::Alerts::send();
    };

    $mech->email_count_is(1);

    $mech->delete_user($user1);
    $mech->delete_user($user2);
    $mech->delete_user($user3);
};

subtest "Test no marked as confirmed added to alerts" => sub {
    my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User' );
    my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User' );
    my $user3 = $mech->create_user_ok('staff@example.com', name => 'Staff User', from_body => $gloucester );
    my $dt = DateTime->now()->add(days => 2);

    my ($report) = $mech->create_problems_for_body(1, 1, 'Testing', {
        user => $user1,
    });
    my $report_id = $report->id;
    ok $report, "created test report - $report_id";

    my $alert = FixMyStreet::DB->resultset('Alert')->create( {
        parameter  => $report_id,
        alert_type => 'new_updates',
        user       => $user2,
    } )->confirm;
    ok $alert, 'created alert for other user';

    $mech->create_comment_for_problem($report, $user3, 'Staff User', 'this is update', 'f', 'confirmed', 'confirmed', { confirmed  => $dt->clone->add( hours => 9 ) });

    $mech->clear_emails_ok;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        FixMyStreet::Script::Alerts::send();
    };

    $mech->email_count_is(1);
    my $email = $mech->get_email;
    my $body = $mech->get_text_body_from_email($email);
    like $body, qr/The following updates have been left on this report:/, 'email is about updates to existing report';
    like $body, qr/Staff User/, 'Update comes from correct user';
    unlike $body, qr/State changed to: Open/s, 'no marked as confirmed text';

    $mech->delete_user($user1);
    $mech->delete_user($user2);
    $mech->delete_user($user3);
};

for my $test (
    {
        update_text => '',
        problem_state => 'investigating',
        expected_text => 'State changed to: Investigating',
        desc => 'comment changing status included in email',
    },
    {
        update_text => 'Category changed to Potholes',
        problem_state => '',
        expected_text => 'Category changed to Potholes',
        desc => 'comment about category included',
    },
    {
        update_text => 'Category changed to Potholes',
        problem_state => 'investigating',
        expected_text => 'Category changed to Potholes.*Investigating',
        desc => 'comment about category and status change included',
    },
) {
    subtest $test->{desc} => sub {
        my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User' );
        my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User' );
        my $user3 = $mech->create_user_ok('staff@example.com', name => 'Staff User', from_body => $gloucester );
        my $dt = DateTime->now()->add(days => 2);

        my ($report) = $mech->create_problems_for_body(1, 1, 'Testing', {
            user => $user1,
        });
        my $report_id = $report->id;
        ok $report, "created test report - $report_id";

        my $alert = FixMyStreet::DB->resultset('Alert')->create( {
            parameter  => $report_id,
            alert_type => 'new_updates',
            user       => $user2,
        } )->confirm;
        ok $alert, 'created alert for other user';

        $mech->create_comment_for_problem($report, $user3, 'Staff User', $test->{update_text}, 'f', 'confirmed', $test->{problem_state}, { confirmed  => $dt->clone->add( hours => 9 ) });

        $mech->clear_emails_ok;
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            FixMyStreet::Script::Alerts::send();
        };

        $mech->email_count_is(1);
        my $expected_text = $test->{expected_text};
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/The following updates have been left on this report:/, 'email is about updates to existing report';
        like $body, qr/Staff User/, 'Update comes from correct user';
        like $body, qr/$expected_text/s, 'Expected text present';

        my @urls = $mech->get_link_from_email($email, 1);
        is $urls[0], "http://www.example.org/report/" . $report_id, "Correct report URL in email";

        $mech->delete_user($user1);
        $mech->delete_user($user2);
        $mech->delete_user($user3);
    };
}

subtest "Test signature template is used from cobrand" => sub {
    my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User' );
    my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User' );

    my $dt = DateTime->now()->add(days => 2);

    my ($report) = $mech->create_problems_for_body(1, $body->id, 'Testing', {
        user => $user1,
    });
    my $report_id = $report->id;
    ok $report, "created test report - $report_id";

    my $alert = FixMyStreet::DB->resultset('Alert')->create( {
        parameter  => $report_id,
        alert_type => 'new_updates',
        user       => $user1,
        cobrand    => 'default',
    } );
    my $ret = $alert->confirm;
    ok $ret, 'created alert for reporter';

    $mech->create_comment_for_problem($report, $user2, 'Other User', 'This is some update text', 'f', 'confirmed', undef, { confirmed  => $dt->clone->add( hours => 7 ) });

    $mech->clear_emails_ok;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'fixmystreet',
    }, sub {
        FixMyStreet::DB->resultset('AlertType')->email_alerts();
    };

    my $email = $mech->get_text_body_from_email;
    like $email, qr/All the best/, 'default signature used';
    unlike $email, qr/twitter.com/, 'nothing from fixmystreet signature';

    $mech->create_comment_for_problem($report, $user2, 'Anonymous User', 'This is some more update text', 't', 'confirmed', 'fixed - user', { confirmed  => $dt->clone->add( hours => 8 ) });

    $alert->cobrand('fixmystreet');
    $alert->update;

    $mech->clear_emails_ok;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'fixmystreet',
    }, sub {
        FixMyStreet::DB->resultset('AlertType')->email_alerts();
    };

    $email = $mech->get_text_body_from_email;
    like $email, qr/twitter.com/, 'fixmystreet signature used';

    $mech->delete_user($user1);
    $mech->delete_user($user2);
};

for my $test (
    {
        desc => 'check non public reports are not included in council problems alerts',
        alert_params => {
            alert_type => 'council_problems',
            parameter => $body->id,
            parameter2 => $body->id,
        }
    },
    {
        desc => 'check non public reports are not included in ward problems alerts',
        alert_params => {
            alert_type => 'ward_problems',
            parameter => $body->id,
            parameter2 => '20728',
        }
    },
    {
        desc => 'check non public reports are not included in local problems alerts',
        alert_params => {
            alert_type => 'local_problems',
            parameter => '-3.189944',
            parameter2 => '55.951963',
        }
    },
    {
        desc => 'check non public reports are not included in area problems alerts',
        alert_params => {
            alert_type => 'area_problems',
            parameter => '20728',
            parameter2 => '20728',
        }
    },
) {
    subtest $test->{desc} => sub {
        my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User');
        my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User');

        my $dt = DateTime->now()->add( minutes => -30 );
        my $r_dt = $dt->clone->add( minutes => 20 );

        my $alert_params = $test->{alert_params};
        $alert_params->{user} = $user1;
        $alert_params->{whensubscribed} = $dt;
        $alert_params->{confirmed} = 1;

        my $alert_user1 = FixMyStreet::DB->resultset('Alert')->create( $alert_params );
        ok $alert_user1, "alert created";

        my ($report) = $mech->create_problems_for_body(1, $body->id, 'Testing', {
            areas              => ',11808,135007,14419,134935,2651,20728,',
            title              => 'Alert test for non public reports',
            confirmed          => $r_dt, # Needed so timezone set right
            latitude           => '55.951963',
            longitude          => '-3.189944',
            user               => $user2,
            non_public         => 1,
        });

        $mech->clear_emails_ok;
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            FixMyStreet::DB->resultset('AlertType')->email_alerts();
        };
        $mech->email_count_is(0);

        $report->update( { non_public => 0 } );
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            FixMyStreet::DB->resultset('AlertType')->email_alerts();
        };
        my $email = $mech->get_text_body_from_email;
        like $email, qr/Alert\s+test\s+for\s+non\s+public\s+reports/, 'alert contains public report';

        $mech->delete_user( $user1 );
        $mech->delete_user( $user2 );
    };
}

subtest 'check new updates alerts for non public reports only go to report owner' => sub {
    my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User');
    my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User');
    my $user3 = $mech->create_user_ok('updates@example.com', name => 'Update User');

    my $dt = DateTime->now->add( minutes => -30 );
    my $r_dt = $dt->clone->add( minutes => 20 );

    my ($report) = $mech->create_problems_for_body(1, $body->id, 'Testing', {
        user => $user2,
        non_public => 1,
    });

    $mech->create_comment_for_problem($report, $user3, 'Anonymous User', 'This is some more update text', 't', 'confirmed', undef, { confirmed  => $r_dt->clone->add( minutes => 8 ) });

    my $alert_user1 = FixMyStreet::DB->resultset('Alert')->create( {
            user       => $user1,
            alert_type => 'new_updates',
            parameter  => $report->id,
            confirmed  => 1,
            whensubscribed => $dt,
    } );
    ok $alert_user1, "alert created";

    $mech->clear_emails_ok;
    FixMyStreet::DB->resultset('AlertType')->email_alerts();
    $mech->email_count_is(0);

    my $alert_user2 = FixMyStreet::DB->resultset('Alert')->create( {
            user       => $user2,
            alert_type => 'new_updates',
            parameter  => $report->id,
            confirmed  => 1,
            whensubscribed => $dt,
    } );
    ok $alert_user2, "alert created";

    FixMyStreet::DB->resultset('AlertType')->email_alerts();
    my $email = $mech->get_text_body_from_email;
    like $email, qr/This is some more update text/, 'alert contains update text';

    $mech->clear_emails_ok;
    $report->update( { non_public => 0 } );
    FixMyStreet::DB->resultset('AlertType')->email_alerts();
    $email = $mech->get_text_body_from_email;
    like $email, qr/This is some more update text/, 'alert contains update text';

    $mech->delete_user( $user1 );
    $mech->delete_user( $user2 );
    $mech->delete_user( $user3 );
};

subtest 'check setting include dates in new updates cobrand option' => sub {
    my $include_date_in_alert_override= Sub::Override->new(
        "FixMyStreet::Cobrand::Default::include_time_in_update_alerts",
        sub { return 1; }
    );

    my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User');
    my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User');
    my $user3 = $mech->create_user_ok('updates@example.com', name => 'Update User');

    my $dt = DateTime->now->add( minutes => -30 );
    my $r_dt = $dt->clone->add( minutes => 20 );

    my ($report) = $mech->create_problems_for_body(1, $body->id, 'Testing', {
        user => $user2,
    });

    my $update = $mech->create_comment_for_problem($report, $user3, 'Anonymous User', 'This is some more update text', 't', 'confirmed', undef, { confirmed  => $r_dt });

    my $alert_user1 = FixMyStreet::DB->resultset('Alert')->create( {
            user       => $user1,
            alert_type => 'new_updates',
            parameter  => $report->id,
            confirmed  => 1,
            whensubscribed => $dt,
    } );
    ok $alert_user1, "alert created";


    $mech->clear_emails_ok;
    FixMyStreet::DB->resultset('AlertType')->email_alerts();

    my $date_in_alert = Utils::prettify_dt( $update->confirmed );
    my $email = $mech->get_text_body_from_email;
    like $email, qr/$date_in_alert/, 'alert contains date';

    $mech->delete_user( $user1 );
    $mech->delete_user( $user2 );
    $mech->delete_user( $user3 );
    $include_date_in_alert_override->restore();
};

done_testing();
