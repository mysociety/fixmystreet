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
        anonymous  => 'f',
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
            anonymous  => 'f',
        },
        {
            problem_id => $report_id,
            user_id    => $user->id,
            name       => 'Main User',
            mark_fixed => 'false',
            text       => 'Second update',
            state      => 'confirmed',
            confirmed  => '2011-03-10 12:23:16',
            anonymous  => 'f',
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
        desc => 'No email, no message',
        fields => {
            rznvy  => '',
            update => '',
            name   => '',
            photo  => '',
            fixed  => undef,
            add_alert => 1,
            may_show_name => undef,
        },
        changes => {},
        field_errors => [ 'Please enter your email', 'Please enter a message' ]
    },
    {
        desc => 'Invalid email, no message',
        fields => {
            rznvy  => 'test',
            update => '',
            name   => '',
            photo  => '',
            fixed  => undef,
            add_alert => 1,
            may_show_name => undef,
        },
        changes => {},
        field_errors => [ 'Please enter a valid email', 'Please enter a message' ]
    },
    {
        desc => 'email with spaces, no message',
        fields => {
            rznvy  => 'test @ example. com',
            update => '',
            name   => '',
            photo  => '',
            fixed  => undef,
            add_alert => 1,
            may_show_name => undef,
        },
        changes => {
            rznvy => 'test@example.com',
        },
        field_errors => [ 'Please enter a message' ]
    },
    {
        desc => 'email with uppercase, no message',
        fields => {
            rznvy  => 'test@EXAMPLE.COM',
            update => '',
            name   => '',
            photo  => '',
            fixed  => undef,
            add_alert => 1,
            may_show_name => undef,
        },
        changes => {
            rznvy => 'test@example.com',
        },
        field_errors => [ 'Please enter a message' ]
    },
  )
{
    subtest "submit an update - $test->{desc}" => sub {
        $mech->get_ok("/report/$report_id");

        $mech->submit_form_ok( { with_fields => $test->{fields} },
            'submit update' );

        is_deeply $mech->form_errors, $test->{field_errors}, 'field errors';

        my $values = {
            %{ $test->{fields} },
            %{ $test->{changes} },
        };

        is_deeply $mech->visible_form_values('updateForm'), $values, 'form changes';
    };
}

subtest "submit an update for a non registered user" => sub {
    $mech->clear_emails_ok();

    $mech->get_ok("/report/$report_id");

    my $values = $mech->visible_form_values('updateForm');

    is_deeply $values,
      {
        name          => '',
        rznvy         => '',
        may_show_name => undef,
        add_alert     => 1,
        photo         => '',
        update        => '',
        fixed         => undef,
      },
      'initial form values';

    $mech->submit_form_ok(
        {
            with_fields => {
                submit_update => 1,
                rznvy         => 'unregistered@example.com',
                update        => 'update from an unregistered user',
                add_alert     => undef,
            }
        },
        'submit update'
    );

    $mech->content_contains('Nearly Done! Now check your email');

    my $email = $mech->get_email;
    ok $email, "got an email";
    like $email->body, qr/confirm the update you/i, "Correct email text";

    my ( $url, $url_token ) = $email->body =~ m{(http://\S+/C/)(\S+)};
    ok $url, "extracted confirm url '$url'";

    my $token = FixMyStreet::App->model('DB::Token')->find(
        {
            token => $url_token,
            scope => 'comment'
        }
    );
    ok $token, 'Token found in database';

    my $update_id  = $token->data->{id};
    my $add_alerts = $token->data->{add_alert};
    my $update =
      FixMyStreet::App->model('DB::Comment')->find( { id => $update_id } );

    ok $update, 'found update in database';
    is $update->state, 'unconfirmed', 'update unconfirmed';
    is $update->user->email, 'unregistered@example.com', 'update email';
    is $update->text, 'Update from an unregistered user', 'update text';
    is $add_alerts, 0, 'do not sign up for alerts';

    $mech->get_ok( $url . $url_token );
    $mech->content_contains("/report/$report_id#$update_id");

    $update->discard_changes;

    is $update->state, 'confirmed', 'update confirmed';
};

for my $test (
    {
        desc => 'submit update for register user',
        initial_values => {
            name => 'Test User',
            rznvy => 'test@example.com',
            may_show_name => 1,
            add_alert => 1,
            photo => '',
            update => '',
            fixed => undef,
        },
        fields => {
            submit_update => 1,
            rznvy  => 'test@example.com',
            update => 'update from a registered user',
            add_alert => undef,
            fixed => undef,
        },
        changed => {
            update => 'Update from a registered user'
        },
        initial_banner => '',
        endstate_banner => '',
        alert => 0,
        anonymous => 0,
    },
    {
        desc => 'submit update for register user anonymously by unchecking',
        initial_values => {
            name => 'Test User',
            rznvy => 'test@example.com',
            may_show_name => 1,
            add_alert => 1,
            photo => '',
            update => '',
            fixed => undef,
        },
        fields => {
            submit_update => 1,
            rznvy  => 'test@example.com',
            update => 'update from a registered user',
            may_show_name => undef,
            add_alert => undef,
            fixed => undef,
        },
        changed => {
            update => 'Update from a registered user'
        },
        initial_banner => '',
        endstate_banner => '',
        alert => 0,
        anonymous => 1,
    },
    {
        desc => 'submit update for register user anonymously by deleting name',
        initial_values => {
            name => 'Test User',
            rznvy => 'test@example.com',
            may_show_name => 1,
            add_alert => 1,
            photo => '',
            update => '',
            fixed => undef,
        },
        fields => {
            submit_update => 1,
            name => '',
            rznvy  => 'test@example.com',
            update => 'update from a registered user',
            may_show_name => 1,
            add_alert => undef,
            fixed => undef,
        },
        changed => {
            update => 'Update from a registered user'
        },
        initial_banner => '',
        endstate_banner => '',
        alert => 0,
        anonymous => 1,
    },
    {
        desc => 'submit update for register user and sign up',
        initial_values => {
            name => 'Test User',
            rznvy => 'test@example.com',
            may_show_name => 1,
            add_alert => 1,
            photo => '',
            update => '',
            fixed => undef,
        },
        fields => {
            submit_update => 1,
            rznvy  => 'test@example.com',
            update => 'update from a registered user',
            add_alert => 1,
            fixed => undef,
        },
        changed => {
            update => 'Update from a registered user'
        },
        initial_banner => '',
        endstate_banner => '',
        alert => 1,
        anonymous => 0,
    },
    {
        desc => 'submit update for register user and mark fixed',
        initial_values => {
            name => 'Commenter',
            rznvy => 'commenter@example.com',
            may_show_name => 1,
            add_alert => 1,
            photo => '',
            update => '',
            fixed => undef,
        },
        fields => {
            submit_update => 1,
            rznvy  => 'commenter@example.com',
            update => 'update from a registered user',
            add_alert => undef,
            fixed => 1,
        },
        changed => {
            update => 'Update from a registered user'
        },
        initial_banner => '',
        endstate_banner => ' This problem has been fixed. ',
        alert => 1, # we signed up for alerts before, do not unsign us
        anonymous => 0,
    },
) {
    subtest $test->{desc} => sub {
        # clear out comments for this problem to make
        # checking details easier later
        ok( $_->delete, 'deleted comment ' . $_->id )
            for $report->comments;

        $mech->clear_emails_ok();

        $mech->log_in_ok( $test->{fields}->{rznvy} );
        $mech->get_ok("/report/$report_id");

        my $values = $mech->visible_form_values( 'updateForm' );

        is_deeply $values, $test->{initial_values}, 'initial form values';

        is $mech->extract_problem_banner->{text}, $test->{initial_banner}, 'initial banner';

        $mech->submit_form_ok(
            {
                with_fields => $test->{fields},
            },
            'submit update'
        );

        is $mech->uri->path, "/report/" . $report_id, "redirected to report page";

        is $mech->extract_problem_banner->{text}, $test->{endstate_banner}, 'submitted banner';

        $mech->email_count_is(0);

        my $results = {
            %{ $test->{fields} },
            %{ $test->{changed} },
        };

        my $update = $report->comments->first;
        ok $update, 'found update';
        is $update->text, $results->{update}, 'update text';
        is $update->user->email, $test->{fields}->{rznvy}, 'update user';
        is $update->state, 'confirmed', 'update confirmed';
        is $update->anonymous, $test->{anonymous}, 'user anonymous';

        my $alert =
          FixMyStreet::App->model('DB::Alert')
          ->find( { user => $user, alert_type => 'new_updates' } );

        ok $test->{alert} ? $alert : !$alert, 'not signed up for alerts';
    };
}

foreach my $test (
    {
        desc           => 'logged in reporter submits update and marks problem fixed',
        initial_values => {
            name          => 'Test User',
            rznvy         => 'test@example.com',
            may_show_name => 1,
            add_alert     => 1,
            photo         => '',
            update        => '',
            fixed         => undef,
        },
        fields => {
            submit_update => 1,
            rznvy         => 'test@example.com',
            update        => 'update from owner',
            add_alert     => undef,
            fixed         => 1,
        },
        changed        => { update => 'Update from owner' },
        initial_banner => '',
        alert     => 1,    # we signed up for alerts before, do not unsign us
        anonymous => 0,
        answered  => 0,
        login     => 1,
        path => '/report/update',
        content =>
"Thanks, glad to hear it's been fixed! Could we just ask if you have ever reported a problem to a council before?",
    },
    {
        desc =>
'logged in reporter submits update and marks problem fixed and has answered questionnaire',
        initial_values => {
            name          => 'Test User',
            rznvy         => 'test@example.com',
            may_show_name => 1,
            add_alert     => 1,
            photo         => '',
            update        => '',
            fixed         => undef,
        },
        fields => {
            submit_update => 1,
            rznvy         => 'test@example.com',
            update        => 'update from owner',
            add_alert     => undef,
            fixed         => 1,
        },
        changed        => { update => 'Update from owner' },
        initial_banner => '',
        alert     => 1,    # we signed up for alerts before, do not unsign us
        anonymous => 0,
        answered  => 1,
        login     => 1,
        path    => '/report/' . $report->id,
        content => $report->title,
    },
    {
        desc           => 'reporter submits update and marks problem fixed',
        initial_values => {
            name          => 'Test User',
            rznvy         => 'test@example.com',
            may_show_name => 1,
            add_alert     => 1,
            photo         => '',
            update        => '',
            fixed         => undef,
        },
        fields => {
            submit_update => 1,
            rznvy         => 'test@example.com',
            update        => 'update from owner',
            add_alert     => undef,
            fixed         => 1,
        },
        changed        => { update => 'Update from owner' },
        initial_banner => '',
        alert     => 1,    # we signed up for alerts before, do not unsign us
        anonymous => 0,
        answered  => 0,
        login     => 0,
        path => '/report/update',
        content =>
"Thanks, glad to hear it's been fixed! Could we just ask if you have ever reported a problem to a council before?",
    },
    {
        desc =>
'reporter submits update and marks problem fixed and has answered questionnaire',
        initial_values => {
            name          => 'Test User',
            rznvy         => 'test@example.com',
            may_show_name => 1,
            add_alert     => 1,
            photo         => '',
            update        => '',
            fixed         => undef,
        },
        fields => {
            submit_update => 1,
            rznvy         => 'test@example.com',
            update        => 'update from owner',
            add_alert     => undef,
            fixed         => 1,
        },
        changed        => { update => 'Update from owner' },
        initial_banner => '',
        alert     => 1,    # we signed up for alerts before, do not unsign us
        anonymous => 0,
        answered  => 1,
        login     => 0,
        path    => '/report/' . $report->id,
        content => $report->title,
    },
  )
{
    subtest $test->{desc} => sub {

        # clear out comments for this problem to make
        # checking details easier later
        ok( $_->delete, 'deleted comment ' . $_->id ) for $report->comments;

        $report->discard_changes;
        $report->state('confirmed');
        $report->update;

        my $questionnaire;
        if ( $test->{answered} ) {
            $questionnaire =
              FixMyStreet::App->model('DB::Questionnaire')->create(
                {
                    problem_id    => $report_id,
                    ever_reported => 'y',
                    whensent      => \'ms_current_timestamp()',
                }
              );

            ok $questionnaire, 'added questionnaire';
        }

        $report->discard_changes;

        $mech->clear_emails_ok();

        SKIP: {
            skip 'not logging user in', 1 unless $test->{login};
            $mech->log_in_ok( $test->{fields}->{rznvy} );
        };
        $mech->get_ok("/report/$report_id");

        my $values = $mech->visible_form_values('updateForm');

        is_deeply $values, $test->{initial_values}, 'initial form values';

        is $mech->extract_problem_banner->{text}, $test->{initial_banner},
          'initial banner';

        $mech->submit_form_ok( { with_fields => $test->{fields}, },
            'submit update' );

        is $mech->uri->path, $test->{path}, "page after submission";

        $mech->content_contains( $test->{content} );

        $mech->email_count_is(0);

        my $results = { %{ $test->{fields} }, %{ $test->{changed} }, };

        my $update = $report->comments->first;
        ok $update, 'found update';
        is $update->text, $results->{update}, 'update text';
        is $update->user->email, $test->{fields}->{rznvy}, 'update user';
        is $update->state, 'confirmed', 'update confirmed';
        is $update->anonymous, $test->{anonymous}, 'user anonymous';

        SKIP: {
            skip( 'not answering questionnaire', 5 ) if $questionnaire;

            $mech->submit_form_ok( );

            my @errors = @{ $mech->page_errors };
            ok scalar @errors, 'displayed error messages';
            is $errors[0], "Please say whether you've ever reported a problem to your council before", 'error message';

            $mech->submit_form_ok( { with_fields => { reported => 'Yes' } } );

            $mech->content_contains( 'Thank you &mdash; you can' );

            $questionnaire = FixMyStreet::App->model( 'DB::Questionnaire' )->find(
                { problem_id => $report_id }
            );

            ok $questionnaire, 'questionnaire exists';
            ok $questionnaire->ever_reported, 'ever reported is yes';
        };

        if ($questionnaire) {
            $questionnaire->delete;
            ok !$questionnaire->in_storage, 'questionnaire deleted';
        }
    };
}

ok $comment->delete, 'deleted comment';
$mech->delete_user('commenter@example.com');
$mech->delete_user('test@example.com');
done_testing();
