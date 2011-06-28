use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

foreach my $test (
    {
        email      => 'test@example.com',
        type       => 'area_problems',
        content    => 'your alert will not be activated',
        email_text => 'confirm the alert',
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=area:1000:A_Location',
        param1 => 1000
    },
    {
        email      => 'test@example.com',
        type       => 'council_problems',
        content    => 'your alert will not be activated',
        email_text => 'confirm the alert',
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=council:1000:A_Location',
        param1 => 1000,
        param2 => 1000,
    },
    {
        email      => 'test@example.com',
        type       => 'ward_problems',
        content    => 'your alert will not be activated',
        email_text => 'confirm the alert',
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=ward:1000:1001:A_Location:Diff_Location',
        param1 => 1000,
        param2 => 1001,
    },
    {
        email      => 'test@example.com',
        type       => 'local_problems',
        content    => 'your alert will not be activated',
        email_text => 'confirm the alert',
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=local:10.2:20.1',
        param1 => 20.1,
        param2 => 10.2,
    },
    {
        email      => 'test@example.com',
        type       => 'new_updates',
        content    => 'your alert will not be activated',
        email_text => 'confirm the alert',
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

        $mech->get_ok( $test->{uri} );
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
        like $email->body, qr/$test->{email_text}/i, "Correct email text";

        my ( $url, $url_token ) = $email->body =~ m{(http://\S+/A/)(\S+)};
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

        $mech->get_ok( $test->{uri} );

        $email = $mech->get_email;
        ok $email, 'got a second email';

        ($url_token) = $email->body =~ m{http://\S+/A/(\S+)};
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
        $mech->content_contains('successfully confirmed');

        $alert =
          FixMyStreet::App->model('DB::Alert')->find( { id => $existing_id, } );

        ok $alert->confirmed, 'alert set to confirmed';
        $mech->delete_user($user);
    };
}

foreach my $test (
    {
        email      => 'test-new@example.com',
        type       => 'area',
        content    => 'your alert will not be activated',
        email_text => 'confirm the alert',
        uri =>
'/alert/subscribe?type=local&rznvy=test-new@example.com&feed=area:1000:A_Location',
        param1 => 1000
    }
  )
{
    subtest "use existing unlogged in user in a alert" => sub {
        $mech->log_out_ok();

        my $type = $test->{type} . '_problems';

        my $user =
          FixMyStreet::App->model('DB::User')
          ->find_or_create( { email => $test->{email} } );

        my $alert = FixMyStreet::App->model('DB::Alert')->find(
            {
                user       => $user,
                alert_type => $type
            }
        );
        # clear existing data so we can be sure we're creating it
        ok $alert->delete() if $alert;

        $mech->get_ok( $test->{uri} );

        $alert = FixMyStreet::App->model('DB::Alert')->find(
            {
                user       => $user,
                alert_type => $type,
                parameter  => $test->{param1},
                parameter2 => $test->{param2},
                confirmed  => 0,
            }
        );

        $mech->content_contains( 'Now check your email' );

        ok $alert, 'New alert created with existing user';
        $mech->delete_user($user);
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

        my $user =
          FixMyStreet::App->model('DB::User')
          ->find_or_create( { email => $test->{email} } );

        $mech->log_in_ok( $test->{email} );
        $mech->clear_emails_ok;

        $mech->get_ok('/alert/list?pc=EH991SP');
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
        content    => 'your alert will not be activated',
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

        $mech->get_ok( $test->{uri} );
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

        my $email = $mech->get_email;
        ok $email, "got an email";
        like $email->body, qr/$test->{email_text}/i, "Correct email text";

        my ( $url, $url_token ) = $email->body =~ m{(http://\S+/A/)(\S+)};
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

        $mech->get_ok("/A/$url_token");
        $mech->content_contains('error confirming');

        $alert->discard_changes;

        ok !$alert->confirmed, 'alert not set to confirmed';

        $abuse->delete;
        $mech->delete_user($user);
    };
}

subtest "Test two-tier council alerts" => sub {
    for my $alert (
        { feed => "local:51.896269:-2.093063",          result => '/rss/l/51.896269,-2.093063' },
        { feed => "area:2326:Cheltenham",               result => '/rss/area/Cheltenham' },
        { feed => "area:2326:4544:Cheltenham:Lansdown", result => '/rss/area/Cheltenham/Lansdown'  },
        { feed => "area:2226:Gloucestershire",          result => '/rss/area/Gloucestershire' },
        { feed => "area:2226:14949:Gloucestershire:Lansdown%2C_Park_and_Warden_Hill",
          result => '/rss/area/Gloucestershire/Lansdown%2C+Park+and+Warden+Hill'
        },
        { feed => "council:2326:Cheltenham",            result => '/rss/reports/Cheltenham' },
        { feed => "ward:2326:4544:Cheltenham:Lansdown", result => '/rss/reports/Cheltenham/Lansdown' },
        { feed => "council:2226:Gloucestershire",       result => '/rss/reports/Gloucestershire' },
        { feed => "ward:2226:14949:Gloucestershire:Lansdown%2C_Park_and_Warden_Hill",
          result => '/rss/reports/Gloucestershire/Lansdown%2C+Park+and+Warden+Hill'
        },
    ) {
        $mech->get_ok( '/alert/list?pc=GL502PR' );
        $mech->submit_form_ok( {
            button => 'rss',
            with_fields => {
                feed => $alert->{feed},
            }
        } );
        is $mech->uri->path, $alert->{result};
    }
};

subtest "Test normal alert signups and that alerts are sent" => sub {
    my $user1 = FixMyStreet::App->model('DB::User')
      ->find_or_create( { email => 'reporter@example.com', name => 'Reporter User' } );
    ok $user1, "created test user";
    $user1->alerts->delete;

    my $user2 = FixMyStreet::App->model('DB::User')
      ->find_or_create( { email => 'alerts@example.com', name => 'Alert User' } );
    ok $user2, "created test user";
    $user2->alerts->delete;

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
                feed => 'council:2651:City_of_Edinburgh',
            }
        },
    ) {
        $mech->get_ok( '/alert' );
        $mech->submit_form_ok( { with_fields => { pc => 'EH11BB' } } );
        $mech->submit_form_ok( {
            button => 'alert',
            with_fields => $alert->{fields},
        } );
        if ( $alert->{email_confirm} ) {
            my $email = $mech->get_email;
            $mech->clear_emails_ok;
            my ( $url, $url_token ) = $email->body =~ m{http://\S+(/A/(\S+))};
            my $token = FixMyStreet::App->model('DB::Token')->find( { token => $url_token, scope => 'alert' } );
            $mech->get_ok( $url );
            $mech->content_contains('successfully confirmed');
        } else {
            $mech->content_contains('successfully created');
        }
    }

    my $dt = DateTime->now()->add( days => 2);

    my $report_time = '2011-03-01 12:00:00';
    my $report = FixMyStreet::App->model('DB::Problem')->find_or_create( {
        postcode           => 'EH1 1BB',
        council            => '2651',
        areas              => ',11808,135007,14419,134935,2651,20728,',
        category           => 'Street lighting',
        title              => 'Testing',
        detail             => 'Testing Detail',
        used_map           => 1,
        name               => $user1->name,
        anonymous          => 0,
        state              => 'confirmed',
        confirmed          => $dt,
        lastupdate         => $dt,
        whensent           => $dt->clone->add( minutes => 5 ),
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

    FixMyStreet::App->model('DB::AlertType')->email_alerts();
    $mech->email_count_is(3);
    my @emails = $mech->get_email;
    my $count;
    for (@emails) {
        $count++ if $_->body =~ /The following updates have been left on this problem:/;
        $count++ if $_->body =~ /The following new problems have been reported to City of\s*Edinburgh Council:/;
        $count++ if $_->body =~ /The following nearby problems have been added:/;
    }
    is $count, 3, 'Three emails with the right things in them';

    my ( $url, $url_token ) = $emails[0]->body =~ m{http://\S+(/A/(\S+))};
    $mech->get_ok( $url );
    $mech->content_contains('successfully deleted');

    $mech->delete_user($user1);
    $mech->delete_user($user2);
};

done_testing();
