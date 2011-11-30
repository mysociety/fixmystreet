use strict;
use warnings;
use Test::More;
use FixMyStreet::TestMech;

mySociety::Locale::gettext_domain( 'FixMyStreet' );

my $mech = FixMyStreet::TestMech->new();

# this is the easiest way to make sure we're not going
# to get any emails sent by data kicking about in the database
FixMyStreet::App->model('DB::AlertType')->email_alerts();
$mech->clear_emails_ok;

my $user =
  FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'test@example.com', name => 'Test User' } );
ok $user, "created test user";

my $user2 =
  FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'commenter@example.com', name => 'Commenter' } );
ok $user2, "created comment user";


my $dt = DateTime->new(
    year   => 2011,
    month  => 04,
    day    => 16,
    hour   => 15,
    minute => 47,
    second => 23
);

my $report = FixMyStreet::App->model('DB::Problem')->find_or_create(
    {
        postcode           => 'SW1A 1AA',
        council            => '2504',
        areas              => ',105255,11806,11828,2247,2504,',
        category           => 'Other',
        title              => 'Test 2',
        detail             => 'Test 2 Detail',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
        state              => 'closed',
        confirmed          => $dt->ymd . ' ' . $dt->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.5016605453401',
        longitude          => '-0.142497580865087',
        user_id            => $user->id,
    }
);
my $report_id = $report->id;
ok $report, "created test report - $report_id";

my $comment = FixMyStreet::App->model('DB::Comment')->find_or_create(
    {
        problem_id => $report_id,
        user_id    => $user2->id,
        name       => 'Other User',
        mark_fixed => 'false',
        text       => 'This is some update text',
        state      => 'confirmed',
        confirmed  => $dt->ymd . ' ' . $dt->hms,
        anonymous  => 'f',
    }
);
my $comment2 = FixMyStreet::App->model('DB::Comment')->find_or_create(
    {
        problem_id => $report_id,
        user_id    => $user2->id,
        name       => 'Other User',
        mark_fixed => 'false',
        text       => 'This is other update text',
        state      => 'confirmed',
        confirmed  => $dt->ymd . ' ' . $dt->hms,
        anonymous  => 'f',
    }
);

$comment->confirmed( \"ms_current_timestamp() - '3 days'::interval" );
$comment->update;

my $alert = FixMyStreet::App->model('DB::Alert')->find_or_create(
    {
        user => $user,
        parameter => $report_id,
        alert_type => 'new_updates',
        whensubscribed => $dt->ymd . ' ' . $dt->hms,
        confirmed => 1,
    }
);

for my $test (
    {
        state => 'closed',
        msg => 'This report is currently marked as closed',
    },
    {
        state => 'fixed',
        msg => 'This report is currently marked as fixed',
    },
    {
        state => 'confirmed',
        msg => 'This report is currently marked as open',
    },
) {
    subtest "correct summary for state of $test->{state}" => sub {
        $mech->clear_emails_ok;

        my $sent = FixMyStreet::App->model('DB::AlertSent')->search(
            {
                alert_id => $alert->id,
                parameter => $comment->id,
            }
        )->delete;

        $report->state( $test->{state} );
        $report->update;

        FixMyStreet::App->model('DB::AlertType')->email_alerts();

        $mech->email_count_is( 1 );
        my $email = $mech->get_email;
        my $msg = $test->{msg};
        my $body = $email->body;

        like $body, qr/$msg/, 'email says problem is ' . $test->{state};
        like $body, qr{report/$report_id}, 'contains problem url';
        like $body, qr/This is some update text/, 'contains update text';
        unlike $body, qr/This is other update text/, 'does not contains other update text';

        my $comments = $body =~ s/(------)//gs;
        is $comments, 1, 'only 1 update';
    };
}

my $now = DateTime->now();
$report->confirmed( $now->ymd . ' ' . $now->hms );
$report->update();

my $council_alert = FixMyStreet::App->model('DB::Alert')->find_or_create(
    {
        user => $user2,
        parameter => 2504,
        parameter2 => 2504,
        alert_type => 'council_problems',
        whensubscribed => $dt->ymd . ' ' . $dt->hms,
        confirmed => 1,
    }
);

for my $test (
    {
        postcode           => 'SW1A 1AA',
        expected_postcode  => 'SW1A 1AA',
    },
    {
        postcode           => 'sw1a 1AA',
        expected_postcode  => 'SW1A 1AA',
    },
    {
        postcode           => 'SW1A 1aa',
        expected_postcode  => 'SW1A 1AA',
    },
    {
        postcode           => 'SW1A1AA',
        expected_postcode  => 'SW1A 1AA',
    },  
    {
        postcode           => 'Buckingham Gate',
        expected_postcode  => 'Buckingham Gate',
    },  
    {
        postcode           => 'Buckingham gate',
        expected_postcode  => 'Buckingham gate',
    },  
) {
    subtest "correct text for postcode $test->{postcode}" => sub {
        $mech->clear_emails_ok;

        my $sent = FixMyStreet::App->model('DB::AlertSent')->search(
            {
                alert_id => $council_alert->id,
                parameter => $report->id,
            }
        )->delete;

        $report->postcode( $test->{postcode} );
        $report->update;

        FixMyStreet::App->model('DB::AlertType')->email_alerts();
            
        $mech->email_count_is( 1 );
        my $email = $mech->get_email;
        my $pc = $test->{expected_postcode};
        my $title = $report->title;
        my $body = $email->body;

        like $body, qr#report/$report_id - $title, $pc#, 'email contains expected postcode';
    };
}

$report->postcode( 'SW1A 1AA' );
$report->update;

done_testing();

