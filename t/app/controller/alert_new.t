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

        # we don't want an alert
        my $alert = FixMyStreet::App->model('DB::Alert')->find(
            {
                email      => $test->{email},
                alert_type => $type
            }
        );
        $alert->delete() if $alert;

        $mech->get_ok( $test->{uri} );
        $mech->content_contains( $test->{content} );

        $alert = FixMyStreet::App->model('DB::Alert')->find(
            {
                email      => $test->{email},
                alert_type => $type,
                parameter  => $test->{param1},
                parameter2 => $test->{param2}
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
    };
}

done_testing();
