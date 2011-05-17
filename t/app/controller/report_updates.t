use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use Web::Scraper;
use Path::Class;
use DateTime;

my $mech = FixMyStreet::TestMech->new;

# create a test user and report
$mech->delete_user('test@example.com');
my $user =
  FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'test@example.com', name => 'Test User' } );
ok $user, "created test user";

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
        state              => 'confirmed',
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
        name       => 'Other User',
        mark_fixed => 'false',
        text  => 'This is some update text',
        email => 'commenter@example.com',
        state => 'confirmed',
        confirmed => $dt->ymd . ' ' . $dt->hms,
    }
);

my $comment_id = $comment->id;
ok $comment, "created test update - $comment_id";

for my $test ( 
    {
        name => 'Other User',
        mark_fixed => 'false',
        mark_open => 'false',
        meta => 'Posted by Other User at 15:47, Saturday 16 April 2011',
    },
    {
        name => '',
        mark_fixed => 'false',
        mark_open => 'false',
        meta => 'Posted anonymously at 15:47, Saturday 16 April 2011',
    },
    {
        name => '',
        mark_fixed => 'true',
        mark_open => 'false',
        meta => 'Posted anonymously at 15:47, Saturday 16 April 2011, marked as fixed',
    },
    {
        name => '',
        mark_fixed => 'false',
        mark_open => 'true',
        meta => 'Posted anonymously at 15:47, Saturday 16 April 2011, reopened',
    }
) {
    subtest "test update displayed" => sub {
        $comment->name( $test->{name} );
        $comment->mark_fixed( $test->{mark_fixed} );
        $comment->mark_open( $test->{mark_open} );
        $comment->update;

        $mech->get_ok("/report/$report_id");
        is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
        $mech->content_contains('This is some update text');

        my $meta = $mech->extract_update_metas;
        is scalar @$meta, 1, 'number of updates';
        is $meta->[0], $test->{meta};
    };
}

ok $comment->delete, 'deleted comment';
$mech->delete_user('test@example.com');
done_testing();
