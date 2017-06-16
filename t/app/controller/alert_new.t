use FixMyStreet::TestMech;
use FixMyStreet::App;
use FixMyStreet::Script::Alerts;

my $mech = FixMyStreet::TestMech->new;

$mech->log_in_ok('test@example.com');
$mech->get_ok('/alert/subscribe?id=1');
my ($csrf) = $mech->content =~ /name="token" value="([^"]*)"/;

foreach my $test (
    {
        email      => 'test@example.com',
        type       => 'area_problems',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => "confirms that you'd like to receive an email",
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=area:1000:A_Location',
        param1 => 1000
    },
    {
        email      => 'test@example.com',
        type       => 'council_problems',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => "confirms that you'd like to receive an email",
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=council:1000:A_Location',
        param1 => 1000,
        param2 => 1000,
    },
    {
        email      => 'test@example.com',
        type       => 'ward_problems',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => "confirms that you'd like to receive an email",
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=ward:1000:1001:A_Location:Diff_Location',
        param1 => 1000,
        param2 => 1001,
    },
    {
        email      => 'test@example.com',
        type       => 'local_problems',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => "confirms that you'd like to receive an email",
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=local:10.2:20.1',
        param1 => 20.1,
        param2 => 10.2,
    },
    {
        email      => 'test@example.com',
        type       => 'new_updates',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => "confirms that you'd like to receive an email",
        uri    => '/alert/subscribe?type=updates&rznvy=test@example.com&id=1',
        param1 => 1,
    }
  )
{
    subtest "$test->{type} alert correctly created" => sub {
        $mech->clear_emails_ok;

        my $type = $test->{type};

        my $user =
          FixMyStreet::App->model('DB::User')
          ->find( { email => $test->{email} } );

        # we don't want an alert
        if ($user) {
            $mech->delete_user($user);
        }

        $mech->get_ok( $test->{uri} . "&token=$csrf" );
        $mech->content_contains( $test->{content} );

        $user =
          FixMyStreet::App->model('DB::User')
          ->find( { email => $test->{email} } );

        ok $user, 'user created for alert';

        my $alert = FixMyStreet::App->model('DB::Alert')->find(
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

        my $token = FixMyStreet::App->model('DB::Token')->find(
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

        $token = FixMyStreet::App->model('DB::Token')->find(
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
          FixMyStreet::App->model('DB::Alert')->find( { id => $existing_id, } );

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

        my $alert = FixMyStreet::App->model('DB::Alert')->find(
            {
                user       => $user,
                alert_type => $type
            }
        );
        # clear existing data so we can be sure we're creating it
        ok $alert->delete() if $alert && !$test->{exist};

        $mech->get_ok( '/alert/subscribe?type=local&rznvy=test-new@example.com&feed=area:1000:A_Location&token=' . $csrf );

        $alert = FixMyStreet::App->model('DB::Alert')->find(
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
        param1     => 2651,
        param2     => 2651,
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
            ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/alert/list?pc=EH991SP');
        };
        $mech->set_visible( [ radio => 'council:2651:City_of_Edinburgh' ] );
        $mech->click('alert');

        my $alert = FixMyStreet::App->model('DB::Alert')->find(
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
        email      => 'test@example.com',
        type       => 'new_updates',
        content    => 'Click the link in our confirmation email to activate your alert',
        email_text => 'confirm the alert',
        uri    => '/alert/subscribe?type=updates&rznvy=test@example.com&id=1',
        param1 => 1,
    }
  )
{
    subtest "cannot sign up for alert if in abuse table" => sub {
        $mech->clear_emails_ok;

        my $type = $test->{type};

        my $user =
          FixMyStreet::App->model('DB::User')
          ->find( { email => $test->{email} } );

        # we don't want an alert
        my $alert;
        if ($user) {
            $mech->delete_user($user);
        }

        my $abuse =
          FixMyStreet::App->model('DB::Abuse')
          ->find_or_create( { email => $test->{email} } );

        $mech->get_ok( $test->{uri} . "&token=$csrf" );
        $mech->content_contains( $test->{content} );

        $user =
          FixMyStreet::App->model('DB::User')
          ->find( { email => $test->{email} } );

        ok $user, 'user created for alert';

        $alert = FixMyStreet::App->model('DB::Alert')->find(
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

$mech->create_body_ok(2226, 'Gloucestershire County Council');
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
            ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
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
    $mech->delete_user( 'reporter@example.com' );
    $mech->delete_user( 'alerts@example.com' );

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
            ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
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
            my $token = FixMyStreet::App->model('DB::Token')->find( { token => $url_token, scope => 'alert' } );
            $mech->get_ok( $url );
            $mech->content_contains('alert created');
        } else {
            $mech->content_contains('alert created');
        }
    }

    my $dt = DateTime->now(time_zone => 'Europe/London')->add(days => 2);

    my $dt_parser = FixMyStreet::App->model('DB')->schema->storage->datetime_parser;

    my $report_time = '2011-03-01 12:00:00';
    my $report = FixMyStreet::App->model('DB::Problem')->find_or_create( {
        postcode           => 'EH1 1BB',
        bodies_str         => '1',
        areas              => ',11808,135007,14419,134935,2651,20728,',
        category           => 'Street lighting',
        title              => 'Testing',
        detail             => 'Testing Detail',
        used_map           => 1,
        name               => $user1->name,
        anonymous          => 0,
        state              => 'fixed - user',
        confirmed          => $dt_parser->format_datetime($dt),
        lastupdate         => $dt_parser->format_datetime($dt),
        whensent           => $dt_parser->format_datetime($dt->clone->add( minutes => 5 )),
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 1,
        latitude           => '55.951963',
        longitude          => '-3.189944',
        user_id            => $user1->id,
    } );
    my $report_id = $report->id;
    ok $report, "created test report - $report_id";

    my $alert = FixMyStreet::App->model('DB::Alert')->create( {
        parameter  => $report_id,
        alert_type => 'new_updates',
        user       => $user1,
    } )->confirm;
    ok $alert, 'created alert for reporter';

    my $update = FixMyStreet::App->model('DB::Comment')->create( {
        problem_id => $report_id,
        user_id    => $user2->id,
        name       => 'Other User',
        mark_fixed => 'false',
        text       => 'This is some update text',
        state      => 'confirmed',
        confirmed  => $dt->clone->add( hours => 7 ),
        anonymous  => 'f',
    } );
    my $update_id = $update->id;
    ok $update, "created test update - $update_id";

    $update = FixMyStreet::App->model('DB::Comment')->create( {
        problem_id => $report_id,
        user_id    => $user2->id,
        name       => 'Anonymous User',
        mark_fixed => 'true',
        text       => 'This is some more update text',
        state      => 'confirmed',
        confirmed  => $dt->clone->add( hours => 8 ),
        anonymous  => 't',
    } );
    $update_id = $update->id;
    ok $update, "created test update - $update_id";

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
    my $body = $mech->get_text_body_from_email($email);
    like $body, qr/Other User/, 'Update name given';
    unlike $body, qr/Anonymous User/, 'Update name not given';

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

subtest "Test signature template is used from cobrand" => sub {
    $mech->delete_user( 'reporter@example.com' );
    $mech->delete_user( 'alerts@example.com' );

    my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User' );

    my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User' );

    my $dt = DateTime->now(time_zone => 'Europe/London')->add(days => 2);

    my $dt_parser = FixMyStreet::App->model('DB')->schema->storage->datetime_parser;

    my $report_time = '2011-03-01 12:00:00';
    my $report = FixMyStreet::App->model('DB::Problem')->find_or_create( {
        postcode           => 'EH1 1BB',
        bodies_str         => '2651',
        areas              => ',11808,135007,14419,134935,2651,20728,',
        category           => 'Street lighting',
        title              => 'Testing',
        detail             => 'Testing Detail',
        used_map           => 1,
        name               => $user1->name,
        anonymous          => 0,
        state              => 'fixed - user',
        confirmed          => $dt_parser->format_datetime($dt),
        lastupdate         => $dt_parser->format_datetime($dt),
        whensent           => $dt_parser->format_datetime($dt->clone->add( minutes => 5 )),
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 1,
        latitude           => '55.951963',
        longitude          => '-3.189944',
        user_id            => $user1->id,
    } );
    my $report_id = $report->id;
    ok $report, "created test report - $report_id";

    my $alert = FixMyStreet::App->model('DB::Alert')->create( {
        parameter  => $report_id,
        alert_type => 'new_updates',
        user       => $user1,
        cobrand    => 'default',
    } );
    my $ret = $alert->confirm;
    ok $ret, 'created alert for reporter';

    my $update = FixMyStreet::App->model('DB::Comment')->create( {
        problem_id => $report_id,
        user_id    => $user2->id,
        name       => 'Other User',
        mark_fixed => 'false',
        text       => 'This is some update text',
        state      => 'confirmed',
        confirmed  => $dt->clone->add( hours => 7 ),
        anonymous  => 'f',
    } );
    my $update_id = $update->id;
    ok $update, "created test update - $update_id";


    $mech->clear_emails_ok;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
    }, sub {
        FixMyStreet::App->model('DB::AlertType')->email_alerts();
    };

    my $email = $mech->get_text_body_from_email;
    like $email, qr/All the best/, 'default signature used';
    unlike $email, qr/twitter.com/, 'nothing from fixmystreet signature';

    $update = FixMyStreet::App->model('DB::Comment')->create( {
        problem_id => $report_id,
        user_id    => $user2->id,
        name       => 'Anonymous User',
        mark_fixed => 'true',
        text       => 'This is some more update text',
        state      => 'confirmed',
        confirmed  => $dt->clone->add( hours => 8 ),
        anonymous  => 't',
    } );
    $update_id = $update->id;
    ok $update, "created test update - $update_id";

    $alert->cobrand('fixmystreet');
    $alert->update;

    $mech->clear_emails_ok;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
    }, sub {
        FixMyStreet::App->model('DB::AlertType')->email_alerts();
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
            parameter => '2651',
            parameter2 => '2651',
        }
    },
    {
        desc => 'check non public reports are not included in ward problems alerts',
        alert_params => {
            alert_type => 'ward_problems',
            parameter => '2651',
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
        $mech->delete_user( 'reporter@example.com' );
        $mech->delete_user( 'alerts@example.com' );

        my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User');

        my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User');

        my $dt = DateTime->now->add( minutes => -30 );
        my $r_dt = $dt->clone->add( minutes => 20 );

        my $alert_params = $test->{alert_params};
        $alert_params->{user} = $user1;
        $alert_params->{whensubscribed} = $dt;
        $alert_params->{confirmed} = 1;

        my $alert_user1 = FixMyStreet::App->model('DB::Alert')->create( $alert_params );
        ok $alert_user1, "alert created";

        my $dt_parser = FixMyStreet::App->model('DB')->schema->storage->datetime_parser;

        my $report = FixMyStreet::App->model('DB::Problem')->find_or_create( {
            postcode           => 'EH1 1BB',
            bodies_str         => '2651',
            areas              => ',11808,135007,14419,134935,2651,20728,',
            category           => 'Street lighting',
            title              => 'Alert test for non public reports',
            detail             => 'Testing Detail',
            used_map           => 1,
            name               => $user2->name,
            anonymous          => 0,
            state              => 'confirmed',
            confirmed          => $dt_parser->format_datetime($r_dt),
            lastupdate         => $dt_parser->format_datetime($r_dt),
            whensent           => $dt_parser->format_datetime($r_dt->clone->add( minutes => 5 )),
            lang               => 'en-gb',
            service            => '',
            cobrand            => 'default',
            cobrand_data       => '',
            send_questionnaire => 1,
            latitude           => '55.951963',
            longitude          => '-3.189944',
            user_id            => $user2->id,
            non_public         => 1,
        } );

        $mech->clear_emails_ok;
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            FixMyStreet::App->model('DB::AlertType')->email_alerts();
        };
        $mech->email_count_is(0);

        $report->update( { non_public => 0 } );
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            FixMyStreet::App->model('DB::AlertType')->email_alerts();
        };
        my $email = $mech->get_text_body_from_email;
        like $email, qr/Alert\s+test\s+for\s+non\s+public\s+reports/, 'alert contains public report';

        $mech->delete_user( $user1 );
        $mech->delete_user( $user2 );
    };
}

subtest 'check new updates alerts for non public reports only go to report owner' => sub {
    $mech->delete_user( 'reporter@example.com' );
    $mech->delete_user( 'alerts@example.com' );

    my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User');

    my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User');

    my $user3 = $mech->create_user_ok('updates@example.com', name => 'Update User');

    my $dt = DateTime->now->add( minutes => -30 );
    my $r_dt = $dt->clone->add( minutes => 20 );

    my $dt_parser = FixMyStreet::App->model('DB')->schema->storage->datetime_parser;

    my $report = FixMyStreet::App->model('DB::Problem')->find_or_create( {
        postcode           => 'EH1 1BB',
        bodies_str         => '2651',
        areas              => ',11808,135007,14419,134935,2651,20728,',
        category           => 'Street lighting',
        title              => 'Alert test for non public reports',
        detail             => 'Testing Detail',
        used_map           => 1,
        name               => $user2->name,
        anonymous          => 0,
        state              => 'confirmed',
        confirmed          => $dt_parser->format_datetime($r_dt),
        lastupdate         => $dt_parser->format_datetime($r_dt),
        whensent           => $dt_parser->format_datetime($r_dt->clone->add( minutes => 5 )),
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 1,
        latitude           => '55.951963',
        longitude          => '-3.189944',
        user_id            => $user2->id,
        non_public         => 1,
    } );

    my $update = FixMyStreet::App->model('DB::Comment')->create( {
        problem_id => $report->id,
        user_id    => $user3->id,
        name       => 'Anonymous User',
        mark_fixed => 'false',
        text       => 'This is some more update text',
        state      => 'confirmed',
        confirmed  => $r_dt->clone->add( minutes => 8 ),
        anonymous  => 't',
    } );

    my $alert_user1 = FixMyStreet::App->model('DB::Alert')->create( {
            user       => $user1,
            alert_type => 'new_updates',
            parameter  => $report->id,
            confirmed  => 1,
            whensubscribed => $dt,
    } );
    ok $alert_user1, "alert created";


    $mech->clear_emails_ok;
    FixMyStreet::App->model('DB::AlertType')->email_alerts();
    $mech->email_count_is(0);

    my $alert_user2 = FixMyStreet::App->model('DB::Alert')->create( {
            user       => $user2,
            alert_type => 'new_updates',
            parameter  => $report->id,
            confirmed  => 1,
            whensubscribed => $dt,
    } );
    ok $alert_user2, "alert created";

    FixMyStreet::App->model('DB::AlertType')->email_alerts();
    my $email = $mech->get_text_body_from_email;
    like $email, qr/This is some more update text/, 'alert contains update text';

    $mech->clear_emails_ok;
    $report->update( { non_public => 0 } );
    FixMyStreet::App->model('DB::AlertType')->email_alerts();
    $email = $mech->get_text_body_from_email;
    like $email, qr/This is some more update text/, 'alert contains update text';

    $mech->delete_user( $user1 );
    $mech->delete_user( $user2 );
    $mech->delete_user( $user3 );
};

subtest 'check setting inlude dates in new updates cobrand option' => sub {
    my $include_date_in_alert_override= Sub::Override->new(
        "FixMyStreet::Cobrand::Default::include_time_in_update_alerts",
        sub { return 1; }
    );
    $mech->delete_user( 'reporter@example.com' );
    $mech->delete_user( 'alerts@example.com' );

    my $user1 = $mech->create_user_ok('reporter@example.com', name => 'Reporter User');

    my $user2 = $mech->create_user_ok('alerts@example.com', name => 'Alert User');

    my $user3 = $mech->create_user_ok('updates@example.com', name => 'Update User');

    my $dt = DateTime->now->add( minutes => -30 );
    my $r_dt = $dt->clone->add( minutes => 20 );

    my $dt_parser = FixMyStreet::App->model('DB')->schema->storage->datetime_parser;

    my $report = FixMyStreet::App->model('DB::Problem')->find_or_create( {
        postcode           => 'EH1 1BB',
        bodies_str         => '2651',
        areas              => ',11808,135007,14419,134935,2651,20728,',
        category           => 'Street lighting',
        title              => 'Alert test for non public reports',
        detail             => 'Testing Detail',
        used_map           => 1,
        name               => $user2->name,
        anonymous          => 0,
        state              => 'confirmed',
        confirmed          => $dt_parser->format_datetime($r_dt),
        lastupdate         => $dt_parser->format_datetime($r_dt),
        whensent           => $dt_parser->format_datetime($r_dt->clone->add( minutes => 5 )),
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 1,
        latitude           => '55.951963',
        longitude          => '-3.189944',
        user_id            => $user2->id,
    } );

    my $update = FixMyStreet::App->model('DB::Comment')->create( {
        problem_id => $report->id,
        user_id    => $user3->id,
        name       => 'Anonymous User',
        mark_fixed => 'false',
        text       => 'This is some more update text',
        state      => 'confirmed',
        confirmed  => $r_dt->clone->add( minutes => 8 ),
        anonymous  => 't',
    } );

    my $alert_user1 = FixMyStreet::App->model('DB::Alert')->create( {
            user       => $user1,
            alert_type => 'new_updates',
            parameter  => $report->id,
            confirmed  => 1,
            whensubscribed => $dt,
    } );
    ok $alert_user1, "alert created";


    $mech->clear_emails_ok;
    FixMyStreet::App->model('DB::AlertType')->email_alerts();

    # if we don't do this then we're applying the date inflation code and
    # it's timezone munging to the DateTime object above and not the DateTime
    # object that's inflated from the database value and these turn out to be
    # different as the one above has a UTC timezone and not the floating one
    # that those from the DB do.
    $update->discard_changes();

    my $date_in_alert = Utils::prettify_dt( $update->confirmed );
    my $email = $mech->get_text_body_from_email;
    like $email, qr/$date_in_alert/, 'alert contains date';

    $mech->delete_user( $user1 );
    $mech->delete_user( $user2 );
    $mech->delete_user( $user3 );
    $include_date_in_alert_override->restore();
};

done_testing();
