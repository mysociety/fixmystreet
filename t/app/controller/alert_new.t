use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

foreach my $test (
    {
        email      => 'test@example.com',
        type       => 'area',
        content    => 'your alert will not be activated',
        email_text => 'confirm the alert',
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=area:1000:A_Location',
        param1 => 1000
    },
    {
        email      => 'test@example.com',
        type       => 'council',
        content    => 'your alert will not be activated',
        email_text => 'confirm the alert',
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=council:1000:A_Location',
        param1 => 1000,
        param2 => 1000,
    },
    {
        email      => 'test@example.com',
        type       => 'ward',
        content    => 'your alert will not be activated',
        email_text => 'confirm the alert',
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=ward:1000:1001:A_Location:Diff_Location',
        param1 => 1000,
        param2 => 1001,
    },
    {
        email      => 'test@example.com',
        type       => 'local',
        content    => 'your alert will not be activated',
        email_text => 'confirm the alert',
        uri =>
'/alert/subscribe?type=local&rznvy=test@example.com&feed=local:10.2:20.1',
        param1 => 10.2,
        param2 => 20.1,
    }
  )
{
    subtest "$test->{type} alert correctly created" => sub {
        $mech->clear_emails_ok;

        my $type = $test->{type} . '_problems';

        my $user = FixMyStreet::App->model('DB::User')->find(
            {
                email => $test->{email}
            }
        );

        # we don't want an alert
        my $alert;
        if ( $user ) {
            $mech->delete_user( $user );
        }

        $mech->get_ok( $test->{uri} );
        $mech->content_contains( $test->{content} );

        $user = FixMyStreet::App->model('DB::User')->find(
            {
                email => $test->{email}
            }
        );

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
        ok $token->data->{id} == $existing_id, 'subscribed to exsiting alert';

        $mech->get_ok("/A/$url_token");
        $mech->content_contains('successfully confirmed');

        $alert =
          FixMyStreet::App->model('DB::Alert')->find( { id => $existing_id, } );

        ok $alert->confirmed, 'alert set to confirmed';
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
) {
    subtest "use existing user in a alert" => sub {
        my $type = $test->{type} . '_problems';

        my $user = FixMyStreet::App->model('DB::User')->find_or_create(
            {
                email => $test->{email}
            }
        );

        my $alert;
        if ( $user ) {
            $alert = FixMyStreet::App->model('DB::Alert')->find(
                {
                    user       => $user,
                    alert_type => $type
                }
            );

            # clear existing data so we can be sure we're creating it
            $alert->delete() if $alert;
        }

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

        ok $alert, 'New alert created with existing user';
    };
}

done_testing();
