use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use Web::Scraper;
use Path::Class;
use DateTime;

my $mech = FixMyStreet::TestMech->new;

# create a test user and report
$mech->delete_user('commenter@example.com');
$mech->delete_user('test@example.com');

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
        user_id    => $user2->id,
        name       => 'Other User',
        mark_fixed => 'false',
        text       => 'This is some update text',
        state      => 'confirmed',
        confirmed  => $dt->ymd . ' ' . $dt->hms,
    }
);

my $comment_id = $comment->id;
ok $comment, "created test update - $comment_id";

for my $test (
    {
        description => 'named user, anon is false',
        name       => 'Other User',
        anonymous  => 'f',
        mark_fixed => 'false',
        mark_open  => 'false',
        meta       => 'Posted by Other User at 15:47, Saturday 16 April 2011',
    },
    {
        description => 'blank user, anon is false',
        name       => '',
        anonymous  => 'f',
        mark_fixed => 'false',
        mark_open  => 'false',
        meta       => 'Posted anonymously at 15:47, Saturday 16 April 2011',
    },
    {
        description => 'named user, anon is true',
        name       => 'Other User',
        anonymous  => 't',
        mark_fixed => 'false',
        mark_open  => 'false',
        meta       => 'Posted anonymously at 15:47, Saturday 16 April 2011',
    },
    {
        description => 'named user, anon is true, fixed',
        name       => 'Other User',
        anonymous  => 't',
        mark_fixed => 'true',
        mark_open  => 'false',
        meta =>
'Posted anonymously at 15:47, Saturday 16 April 2011, marked as fixed',
    },
    {
        description => 'named user, anon is true, reopened',
        name       => 'Other User',
        anonymous  => 't',
        mark_fixed => 'false',
        mark_open  => 'true',
        meta => 'Posted anonymously at 15:47, Saturday 16 April 2011, reopened',
    }
  )
{
    subtest "test update displayed for $test->{description}" => sub {
        $comment->name( $test->{name} );
        $comment->mark_fixed( $test->{mark_fixed} );
        $comment->mark_open( $test->{mark_open} );
        $comment->anonymous( $test->{anonymous} );
        $comment->update;

        $mech->get_ok("/report/$report_id");
        is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
        $mech->content_contains('This is some update text');

        my $meta = $mech->extract_update_metas;
        is scalar @$meta, 1, 'number of updates';
        is $meta->[0], $test->{meta};
    };
}

subtest "unconfirmed updates not displayed" => sub {
    $comment->state( 'unconfirmed' );
    $comment->update;
    $mech->get_ok("/report/$report_id");

    my $meta = $mech->extract_update_metas;
    is scalar @$meta, 0, 'update not displayed';
};

subtest "several updates shown in correct order" => sub {
    for my $fields ( {
            problem_id => $report_id,
            user_id    => $user2->id,
            name       => 'Other User',
            mark_fixed => 'false',
            text       => 'First update',
            state      => 'confirmed',
            confirmed  => '2011-03-10 12:23:15',
        },
        {
            problem_id => $report_id,
            user_id    => $user->id,
            name       => 'Main User',
            mark_fixed => 'false',
            text       => 'Second update',
            state      => 'confirmed',
            confirmed  => '2011-03-10 12:23:16',
        },
        {
            problem_id => $report_id,
            user_id    => $user->id,
            name       => 'Other User',
            anonymous  => 'true',
            mark_fixed => 'true',
            text       => 'Third update',
            state      => 'confirmed',
            confirmed  => '2011-03-15 08:12:36',
        }
    ) {
        my $comment = FixMyStreet::App->model('DB::Comment')->find_or_create(
            $fields
        );
    }

    $mech->get_ok("/report/$report_id");

    my $meta = $mech->extract_update_metas;
    is scalar @$meta, 3, 'number of updates';
    is $meta->[0], 'Posted by Other User at 12:23, Thursday 10 March 2011', 'first update';
    is $meta->[1], 'Posted by Main User at 12:23, Thursday 10 March 2011', 'second update';
    is $meta->[2], 'Posted anonymously at 08:12, Tuesday 15 March 2011, marked as fixed', 'third update';
};

for my $test (
    {
        fields => {
            rznvy  => '',
            update => '',
            name   => '',
        },
        field_errors => [ 'Please enter your email', 'Please enter a message' ]
    },
    {
        fields => {
            rznvy  => 'test',
            update => '',
            name   => '',
        },
        field_errors => [ 'Please enter a valid email', 'Please enter a message' ]
    },
  )
{
    subtest "submit an update" => sub {
        $mech->get_ok("/report/$report_id");

        $mech->submit_form_ok( { with_fields => $test->{fields} },
            'submit update' );

        is_deeply $mech->form_errors, $test->{field_errors}, 'field errors';
    };
}

ok $comment->delete, 'deleted comment';
$mech->delete_user('commenter@example.com');
$mech->delete_user('test@example.com');
done_testing();
