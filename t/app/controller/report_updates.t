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

my $body = $mech->create_body_ok(2504, 'Westminster City Council');

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
        bodies_str         => $body->id,
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
        meta       => 'Posted by Other User at 15:47, Sat 16 April 2011',
    },
    {
        description => 'blank user, anon is false',
        name       => '',
        anonymous  => 'f',
        mark_fixed => 'false',
        mark_open  => 'false',
        meta       => 'Posted anonymously at 15:47, Sat 16 April 2011',
    },
    {
        description => 'named user, anon is true',
        name       => 'Other User',
        anonymous  => 't',
        mark_fixed => 'false',
        mark_open  => 'false',
        meta       => 'Posted anonymously at 15:47, Sat 16 April 2011',
    },
    {
        description => 'named user, anon is true, fixed',
        name       => 'Other User',
        anonymous  => 't',
        mark_fixed => 'true',
        mark_open  => 'false',
        meta =>
'Posted anonymously at 15:47, Sat 16 April 2011, marked as fixed',
    },
    {
        description => 'named user, anon is true, reopened',
        name       => 'Other User',
        anonymous  => 't',
        mark_fixed => 'false',
        mark_open  => 'true',
        meta => 'Posted anonymously at 15:47, Sat 16 April 2011, reopened',
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
    is $meta->[0], 'Posted by Other User at 12:23, Thu 10 March 2011', 'first update';
    is $meta->[1], 'Posted by Main User at 12:23, Thu 10 March 2011', 'second update';
    is $meta->[2], 'Posted anonymously at 08:12, Tue 15 March 2011, marked as fixed', 'third update';
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
            remember_me => undef,
            password_register => '',
            password_sign_in => '',
        },
        changes => {},
        field_errors => [ 'Please enter a message', 'Please enter your email', 'Please enter your name' ]
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
            remember_me => undef,
            password_sign_in => '',
            password_register => '',
        },
        changes => {},
        field_errors => [ 'Please enter a message', 'Please enter a valid email', 'Please enter your name' ]
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
            remember_me => undef,
            password_register => '',
            password_sign_in => '',
        },
        changes => {
            rznvy => 'test@example.com',
        },
        field_errors => [ 'Please enter a message', 'Please enter your name' ]
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
            remember_me => undef,
            password_register => '',
            password_sign_in => '',
        },
        changes => {
            rznvy => 'test@example.com',
        },
        field_errors => [ 'Please enter a message', 'Please enter your name' ]
    },
  )
{
    subtest "submit an update - $test->{desc}" => sub {
        $mech->get_ok("/report/$report_id");

        $mech->submit_form_ok( { with_fields => $test->{fields} },
            'submit update' );

        is_deeply $mech->page_errors, $test->{field_errors}, 'field errors';

        my $values = {
            %{ $test->{fields} },
            %{ $test->{changes} },
        };

        is_deeply $mech->visible_form_values('updateForm'), $values, 'form changes';
    };
}

for my $test (
    {
        desc => 'submit an update for a non registered user',
        initial_values => {
            name          => '',
            rznvy         => '',
            may_show_name => 1,
            add_alert     => 1,
            photo         => '',
            update        => '',
            fixed         => undef,
            remember_me => undef,
            password_register => '',
            password_sign_in => '',
        },
        form_values => {
            submit_update => 1,
            rznvy         => 'unregistered@example.com',
            update        => 'Update from an unregistered user',
            add_alert     => undef,
            name          => 'Unreg User',
            may_show_name => undef,
        },
        changes => {},
    },
    {
        desc => 'submit an update for a non registered user and sign up',
        initial_values => {
            name          => '',
            rznvy         => '',
            may_show_name => 1,
            add_alert     => 1,
            photo         => '',
            update        => '',
            fixed         => undef,
            remember_me => undef,
            password_register => '',
            password_sign_in => '',
        },
        form_values => {
            submit_update => 1,
            rznvy         => 'unregistered@example.com',
            update        => "update from an\r\n\r\nunregistered user",
            add_alert     => 1,
            name          => 'Unreg User',
            may_show_name => undef,
        },
        changes => {
            update => "Update from an\n\nUnregistered user",
        },
    }
) {
    subtest $test->{desc} => sub {
        $mech->log_out_ok();
        $mech->clear_emails_ok();

        $mech->get_ok("/report/$report_id");

        my $values = $mech->visible_form_values('updateForm');

        is_deeply $values, $test->{initial_values}, 'initial form values';

        $mech->submit_form_ok(
            {
                with_fields => $test->{form_values}
            },
            'submit update'
        );

        $mech->content_contains('Nearly done! Now check your email');

        my $email = $mech->get_email;
        ok $email, "got an email";
        like $email->body, qr/confirm your update on/i, "Correct email text";

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

        my $details = {
            %{ $test->{form_values} },
            %{ $test->{changes} }
        };

        ok $update, 'found update in database';
        is $update->state, 'unconfirmed', 'update unconfirmed';
        is $update->user->email, $details->{rznvy}, 'update email';
        is $update->text, $details->{update}, 'update text';
        is $add_alerts, $details->{add_alert} ? 1 : 0, 'do not sign up for alerts';

        $mech->get_ok( $url . $url_token );
        $mech->content_contains("/report/$report_id#update_$update_id");

        my $unreg_user = FixMyStreet::App->model( 'DB::User' )->find( { email => $details->{rznvy} } );

        ok $unreg_user, 'found user';

        my $alert = FixMyStreet::App->model( 'DB::Alert' )->find(
            { user => $unreg_user, alert_type => 'new_updates', confirmed => 1, }
        );

        ok $details->{add_alert} ? defined( $alert ) : !defined( $alert ), 'sign up for alerts';

        $update->discard_changes;

        is $update->state, 'confirmed', 'update confirmed';
        $mech->delete_user( $unreg_user );
    };
}

$report->state('confirmed');
$report->update;

for my $test (
    {
        desc => 'overriding email confirmation allows report confirmation with no email sent',
        initial_values => {
            name          => '',
            rznvy         => '',
            may_show_name => 1,
            add_alert     => 1,
            photo         => '',
            update        => '',
            fixed         => undef,
            remember_me => undef,
            password_register => '',
            password_sign_in => '',
        },
        form_values => {
            submit_update => 1,
            rznvy         => 'unregistered@example.com',
            update        => "update no email confirm",
            add_alert     => 1,
            name          => 'Unreg User',
            may_show_name => undef,
        },
        changes => {
            update => "Update no email confirm",
        },
    }
) {
    subtest $test->{desc} => sub {
        my $send_confirmation_mail_override = Sub::Override->new(
            "FixMyStreet::Cobrand::Default::never_confirm_updates",
            sub { return 1; }
        );
        $mech->log_out_ok();
        $mech->clear_emails_ok();

        $mech->get_ok("/report/$report_id");

        my $values = $mech->visible_form_values('updateForm');

        is_deeply $values, $test->{initial_values}, 'initial form values';

        $mech->submit_form_ok(
            {
                with_fields => $test->{form_values}
            },
            'submit update'
        );
        $mech->content_contains("/report/$report_id");
        $mech->get_ok("/report/$report_id");

        $mech->content_contains('Test 2');
        $mech->content_contains('Update no email confirm');

        my $email = $mech->email_count_is(0);

        my $update =
          FixMyStreet::App->model('DB::Comment')->find( { problem_id => $report_id, text => 'Update no email confirm' } );
        my $update_id = $update->id;

        $mech->content_contains('name="update_' . $update_id . '"');

        my $details = {
            %{ $test->{form_values} },
            %{ $test->{changes} }
        };

        ok $update, 'found update in database';
        is $update->state, 'confirmed', 'update confirmed';
        is $update->user->email, $details->{rznvy}, 'update email';
        is $update->text, $details->{update}, 'update text';

        my $unreg_user = FixMyStreet::App->model( 'DB::User' )->find( { email => $details->{rznvy} } );

        ok $unreg_user, 'found user';

        $mech->delete_user( $unreg_user );
        $send_confirmation_mail_override->restore();
    };
}

subtest 'check non authority user cannot change set state' => sub {
    $mech->log_in_ok( $user->email );
    $user->from_body( undef );
    $user->update;

    $mech->get_ok("/report/$report_id");
    $mech->post_ok( "/report/update", {
                submit_update => 1,
                id => $report_id,
                name => $user->name,
                may_show_name => 1,
                add_alert => undef,
                photo => '',
                update => 'this is a forbidden update',
                state => 'fixed - council',
        },
        'submitted with state',
    );

    is $mech->uri->path, "/report/update", "at /report/update";

    my $errors = $mech->page_errors;
    is_deeply $errors, [ 'There was a problem with your update. Please try again.' ], 'error message';

    is $report->state, 'confirmed', 'state unchanged';
};

for my $state ( qw/unconfirmed hidden partial/ ) {
    subtest "check that update cannot set state to $state" => sub {
        $mech->log_in_ok( $user->email );
        $user->from_body( $body->id );
        $user->update;

        $mech->get_ok("/report/$report_id");
        $mech->post_ok( "/report/update", {
                    submit_update => 1,
                    id => $report_id,
                    name => $user->name,
                    may_show_name => 1,
                    add_alert => undef,
                    photo => '',
                    update => 'this is a forbidden update',
                    state => $state,
            },
            'submitted with state',
        );

        is $mech->uri->path, "/report/update", "at /report/update";

        my $errors = $mech->page_errors;
        is_deeply $errors, [ 'There was a problem with your update. Please try again.' ], 'error message';

        is $report->state, 'confirmed', 'state unchanged';
    };
}

for my $test (
    {
        desc => 'from authority user marks report as investigating',
        fields => {
            name => $user->name,
            may_show_name => 1,
            add_alert => undef,
            photo => '',
            update => 'Set state to investigating',
            state => 'investigating',
        },
        state => 'investigating',
    },
    {
        desc => 'from authority user marks report as in progress',
        fields => {
            name => $user->name,
            may_show_name => 1,
            add_alert => undef,
            photo => '',
            update => 'Set state to in progress',
            state => 'in progress',
        },
        state => 'in progress',
    },
    {
        desc => 'from authority user marks report as fixed',
        fields => {
            name => $user->name,
            may_show_name => 1,
            add_alert => undef,
            photo => '',
            update => 'Set state to fixed',
            state => 'fixed',
        },
        state => 'fixed - council',
    },
    {
        desc => 'from authority user marks report as action scheduled',
        fields => {
            name => $user->name,
            may_show_name => 1,
            add_alert => undef,
            photo => '',
            update => 'Set state to action scheduled',
            state => 'action scheduled',
        },
        state => 'action scheduled',
    },
    {
        desc => 'from authority user marks report as unable to fix',
        fields => {
            name => $user->name,
            may_show_name => 1,
            add_alert => undef,
            photo => '',
            update => 'Set state to unable to fix',
            state => 'unable to fix',
        },
        state => 'unable to fix',
    },
    {
        desc => 'from authority user marks report as internal referral',
        fields => {
            name => $user->name,
            may_show_name => 1,
            add_alert => undef,
            photo => '',
            update => 'Set state to internal referral',
            state => 'internal referral',
        },
        state => 'internal referral',
        meta  => "an internal referral",
    },
    {
        desc => 'from authority user marks report as not responsible',
        fields => {
            name => $user->name,
            may_show_name => 1,
            add_alert => undef,
            photo => '',
            update => 'Set state to not responsible',
            state => 'not responsible',
        },
        state => 'not responsible',
        meta  => "not the council's responsibility"
    },
    {
        desc => 'from authority user marks report as duplicate',
        fields => {
            name => $user->name,
            may_show_name => 1,
            add_alert => undef,
            photo => '',
            update => 'Set state to duplicate',
            state => 'duplicate',
        },
        state => 'duplicate',
        meta  => 'a duplicate report',
    },
    {
        desc => 'from authority user marks report as internal referral',
        fields => {
            name => $user->name,
            may_show_name => 1,
            add_alert => undef,
            photo => '',
            update => 'Set state to internal referral',
            state => 'internal referral',
        },
        state => 'internal referral',
        meta  => 'an internal referral',
    },
    {
        desc => 'from authority user marks report sent to two councils as fixed',
        fields => {
            name => $user->name,
            may_show_name => 1,
            add_alert => undef,
            photo => '',
            update => 'Set state to fixed',
            state => 'fixed',
        },
        state => 'fixed - council',
        report_bodies => $body->id . ',2505',
    },
) {
    subtest $test->{desc} => sub {
        $report->comments->delete;
        if ( $test->{ report_bodies } ) {
            $report->bodies_str( $test->{ report_bodies } );
            $report->update;
        }

        $mech->log_in_ok( $user->email );
        $user->from_body( $body->id );
        $user->update;

        $mech->get_ok("/report/$report_id");

        $mech->submit_form_ok(
            {
                with_fields => $test->{fields},
            },
            'submit update'
        );
        $mech->get_ok("/report/$report_id");

        $report->discard_changes;
        my $update = $report->comments->first;
        ok $update, 'found update';
        is $update->text, $test->{fields}->{update}, 'update text';
        is $update->problem_state, $test->{state}, 'problem state set';

        my $update_meta = $mech->extract_update_metas;
        my $meta_state = $test->{meta} || $test->{fields}->{state};
        if ( $test->{reopened} ) {
            like $update_meta->[0], qr/reopened$/, 'update meta says reopened';
        } else {
            like $update_meta->[0], qr/marked as $meta_state$/, 'update meta includes state change';
        }
        like $update_meta->[0], qr{Test User \(Westminster City Council\)}, 'update meta includes council name';
        $mech->content_contains( 'Test User (<strong>Westminster City Council</strong>)', 'council name in bold');

        $report->discard_changes;
        is $report->state, $test->{state}, 'state set';
    };
}

subtest 'check meta correct for comments marked confirmed but not marked open' => sub {
    $report->comments->delete;
    my $comment = FixMyStreet::App->model('DB::Comment')->create(
        {
            user          => $user,
            problem_id    => $report->id,
            text          => 'update text',
            confirmed     => DateTime->now( time_zone => 'local' ),
            problem_state => 'confirmed',
            anonymous     => 0,
            mark_open     => 0,
            mark_fixed    => 0,
            state         => 'confirmed',
        }
    );

    $mech->get_ok( "/report/" . $report->id );
    my $update_meta = $mech->extract_update_metas;
    unlike $update_meta->[0], qr/reopened$/,
      'update meta does not say reopened';

    $comment->update( { mark_open => 1, problem_state => undef } );
    $mech->get_ok( "/report/" . $report->id );
    $update_meta = $mech->extract_update_metas;

    unlike $update_meta->[0], qr/marked as open$/,
      'update meta does not says marked as open';
    like $update_meta->[0], qr/reopened$/, 'update meta does say reopened';

    $comment->update( { mark_open => 0, problem_state => undef } );
    $mech->get_ok( "/report/" . $report->id );
    $update_meta = $mech->extract_update_metas;

    unlike $update_meta->[0], qr/marked as open$/,
      'update meta does not says marked as open';
    unlike $update_meta->[0], qr/reopened$/, 'update meta does not say reopened';
};

subtest "check first comment with no status change has no status in meta" => sub {
    $mech->log_in_ok( $user->email );
    $user->from_body( undef );
    $user->update;

    my $comment = $report->comments->first;
    $comment->update( { mark_fixed => 0, problem_state => 'confirmed' } );

    $mech->get_ok("/report/$report_id");

    my $update_meta = $mech->extract_update_metas;
    unlike $update_meta->[0], qr/marked as|reopened/, 'update meta does not include state change';
};

subtest "check comment with no status change has not status in meta" => sub {
        $mech->log_in_ok( $user->email );
        $user->from_body( undef );
        $user->update;

        my $comment = $report->comments->first;
        $comment->update( { mark_fixed => 1, problem_state => 'fixed - council' } );

        $mech->get_ok("/report/$report_id");

        $mech->submit_form_ok(
            {
                with_fields => {
                    name => $user->name,
                    may_show_name => 1,
                    add_alert => undef,
                    photo => '',
                    update => 'Comment that does not change state',
                },
            },
            'submit update'
        );
        $mech->get_ok("/report/$report_id");

        $report->discard_changes;
        my @updates = $report->comments->all;
        is scalar @updates, 2, 'correct number of updates';

        my $update = pop @updates;

        is $report->state, 'fixed - council', 'correct report state';
        is $update->problem_state, 'fixed - council', 'correct update state';
        my $update_meta = $mech->extract_update_metas;
        unlike $update_meta->[1], qr/marked as/, 'update meta does not include state change';

        $user->from_body( $body->id );
        $user->update;

        $mech->get_ok("/report/$report_id");

        $mech->submit_form_ok(
            {
                with_fields => {
                    name => $user->name,
                    may_show_name => 1,
                    add_alert => undef,
                    photo => '',
                    update => 'Comment that sets state to investigating',
                    state => 'investigating',
                },
            },
            'submit update'
        );
        $mech->get_ok("/report/$report_id");

        $report->discard_changes;
        @updates = $report->comments->search(undef, { order_by => 'created' })->all;;

        is scalar @updates, 3, 'correct number of updates';

        $update = pop @updates;

        is $report->state, 'investigating', 'correct report state';
        is $update->problem_state, 'investigating', 'correct update state';
        $update_meta = $mech->extract_update_metas;
        like $update_meta->[0], qr/marked as fixed/, 'first update meta says fixed';
        unlike $update_meta->[1], qr/marked as/, 'second update meta does not include state change';
        like $update_meta->[2], qr/marked as investigating/, 'third update meta says investigating';

        my $dt = DateTime->now( time_zone => "local" )->add( seconds => 1 );
        $comment = FixMyStreet::App->model('DB::Comment')->find_or_create(
            {
                problem_id => $report_id,
                user_id    => $user->id,
                name       => 'Other User',
                mark_fixed => 'false',
                text       => 'This is some update text',
                state      => 'confirmed',
                confirmed  => $dt->ymd . ' ' . $dt->hms,
                anonymous  => 'f',
            }
        );

        $mech->get_ok("/report/$report_id");

        $report->discard_changes;
        @updates = $report->comments->search(undef, { order_by => 'created' })->all;;
        is scalar @updates, 4, 'correct number of updates';

        $update = pop @updates;

        is $report->state, 'investigating', 'correct report state';
        is $update->problem_state, undef, 'no update state';
        $update_meta = $mech->extract_update_metas;
        like $update_meta->[0], qr/marked as fixed/, 'first update meta says fixed';
        unlike $update_meta->[1], qr/marked as/, 'second update meta does not include state change';
        like $update_meta->[2], qr/marked as investigating/, 'third update meta says investigating';
        unlike $update_meta->[3], qr/marked as/, 'fourth update meta has no state change';
};

subtest 'check meta correct for second comment marking as reopened' => sub {
    $report->comments->delete;
    my $comment = FixMyStreet::App->model('DB::Comment')->create(
        {
            user          => $user,
            problem_id    => $report->id,
            text          => 'update text',
            confirmed     => DateTime->now( time_zone => 'local'),
            problem_state => 'fixed - user',
            anonymous     => 0,
            mark_open     => 0,
            mark_fixed    => 1,
            state         => 'confirmed',
        }
    );

    $mech->get_ok( "/report/" . $report->id );
    my $update_meta = $mech->extract_update_metas;
    like $update_meta->[0], qr/fixed$/, 'update meta says fixed';

    $comment = FixMyStreet::App->model('DB::Comment')->create(
        {
            user          => $user,
            problem_id    => $report->id,
            text          => 'update text',
            confirmed     => DateTime->now( time_zone => 'local' ) + DateTime::Duration->new( minutes => 1 ),
            problem_state => 'confirmed',
            anonymous     => 0,
            mark_open     => 0,
            mark_fixed    => 0,
            state         => 'confirmed',
        }
    );

    $mech->get_ok( "/report/" . $report->id );
    $update_meta = $mech->extract_update_metas;
    like $update_meta->[1], qr/reopened$/, 'update meta says reopened';
};

$user->from_body(undef);
$user->update;

$report->state('confirmed');
$report->bodies_str($body->id);
$report->update;

for my $test (
    {
        desc => 'submit an update for a registered user, signing in with wrong password',
        form_values => {
            submit_update => 1,
            rznvy         => 'registered@example.com',
            update        => 'Update from a user',
            add_alert     => undef,
            password_sign_in => 'secret',
        },
        field_errors => [
            "There was a problem with your email/password combination. If you cannot remember your password, or do not have one, please fill in the \x{2018}sign in by email\x{2019} section of the form.",
            'Please enter your name', # FIXME Not really necessary error
        ],
    },
    {
        desc => 'submit an update for a registered user and sign in',
        form_values => {
            submit_update => 1,
            rznvy         => 'registered@example.com',
            update        => 'Update from a user',
            add_alert     => undef,
            password_sign_in => 'secret2',
        },
        message => 'You have successfully signed in; please check and confirm your details are accurate:',
    }
) {
    subtest $test->{desc} => sub {
        # Set things up
        my $user = $mech->create_user_ok( $test->{form_values}->{rznvy} );
        my $pw = 'secret2';
        $user->update( { name => 'Mr Reg', password => $pw } );
        $report->comments->delete;

        $mech->log_out_ok();
        $mech->clear_emails_ok();
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok(
            {
                button => 'submit_sign_in',
                with_fields => $test->{form_values}
            },
            'submit update'
        );

        $mech->content_contains($test->{message}) if $test->{message};

        is_deeply $mech->page_errors, $test->{field_errors}, 'check there were errors'
            if $test->{field_errors};

        SKIP: {
            skip( "Incorrect password", 5 ) unless $test->{form_values}{password_sign_in} eq $pw;

            # Now submit with a name
            $mech->submit_form_ok(
                {
                    with_fields => {
                        name => 'Joe Bloggs',
                    }
                },
                "submit good details"
            );

            $mech->content_contains('Thank you for updating this issue');
            $mech->email_count_is(0);

            my $update = $report->comments->first;
            ok $update, 'found update';
            is $update->text, $test->{form_values}->{update}, 'update text';
            is $update->user->email, $test->{form_values}->{rznvy}, 'update user';
            is $update->state, 'confirmed', 'update confirmed';
            $mech->delete_user( $update->user );
        }
    };
}

subtest 'submit an update for a registered user, creating update by email' => sub {
    my $user = $mech->create_user_ok( 'registered@example.com' );
    $user->update( { name => 'Mr Reg', password => 'secret2' } );
    $report->comments->delete;
    $mech->log_out_ok();
    $mech->clear_emails_ok();
    $mech->get_ok("/report/$report_id");
    $mech->submit_form_ok( {
        with_fields => {
            submit_update => 1,
            rznvy         => 'registered@example.com',
            update        => 'Update from a user',
            add_alert     => undef,
            name          => 'New Name',
            password_register => 'new_secret',
        },
    }, 'submit update' );

    $mech->content_contains('Nearly done! Now check your email');

    # No change to user yet.
    $user->discard_changes;
    ok $user->check_password( 'secret2' ), 'password unchanged';
    is $user->name, 'Mr Reg', 'name unchanged';

    my $email = $mech->get_email;
    ok $email, "got an email";
    like $email->body, qr/confirm your update on/i, "Correct email text";

    my ( $url, $url_token ) = $email->body =~ m{(http://\S+/C/)(\S+)};
    ok $url, "extracted confirm url '$url'";

    my $token = FixMyStreet::App->model('DB::Token')->find( {
        token => $url_token,
        scope => 'comment'
    } );
    ok $token, 'Token found in database';

    my $update_id  = $token->data->{id};
    my $add_alerts = $token->data->{add_alert};
    my $update = FixMyStreet::App->model('DB::Comment')->find( { id => $update_id } );

    ok $update, 'found update in database';
    is $update->state, 'unconfirmed', 'update unconfirmed';
    is $update->user->email, 'registered@example.com', 'update email';
    is $update->text, 'Update from a user', 'update text';

    $mech->get_ok( $url . $url_token );
    $mech->content_contains("/report/$report_id#update_$update_id");

    # User should have new name and password
    $user->discard_changes;
    ok $user->check_password( 'new_secret' ), 'password changed';
    is $user->name, 'New Name', 'name changed';

    $update->discard_changes;
    is $update->state, 'confirmed', 'update confirmed';
    $mech->delete_user( $user );
};

for my $test (
    {
        desc => 'submit update for registered user',
        initial_values => {
            name => 'Test User',
            may_show_name => 1,
            add_alert => 1,
            photo => '',
            update => '',
            fixed => undef,
        },
        email  => 'test@example.com',
        fields => {
            submit_update => 1,
            update => 'update from a registered user',
            add_alert => undef,
            fixed => undef,
        },
        changed => {
            update => 'Update from a registered user'
        },
        initial_banner => undef,
        endstate_banner => undef,
        alert => 0,
        anonymous => 0,
    },
    {
        desc => 'submit update for registered user anonymously by unchecking',
        initial_values => {
            name => 'Test User',
            may_show_name => 1,
            add_alert => 1,
            photo => '',
            update => '',
            fixed => undef,
        },
        email  => 'test@example.com',
        fields => {
            submit_update => 1,
            update => 'update from a registered user',
            may_show_name => undef,
            add_alert => undef,
            fixed => undef,
        },
        changed => {
            update => 'Update from a registered user'
        },
        initial_banner => undef,
        endstate_banner => undef,
        alert => 0,
        anonymous => 1,
    },
    {
        desc => 'submit update for registered user and sign up',
        initial_values => {
            name => 'Test User',
            may_show_name => 1,
            add_alert => 1,
            photo => '',
            update => '',
            fixed => undef,
        },
        email  => 'test@example.com',
        fields => {
            submit_update => 1,
            update => 'update from a registered user',
            add_alert => 1,
            fixed => undef,
        },
        changed => {
            update => 'Update from a registered user'
        },
        initial_banner => undef,
        endstate_banner => undef,
        alert => 1,
        anonymous => 0,
    },
    {
        desc => 'submit update for registered user and mark fixed',
        initial_values => {
            name => 'Commenter',
            may_show_name => 1,
            add_alert => 1,
            photo => '',
            update => '',
            fixed => undef,
        },
        email  => 'commenter@example.com',
        fields => {
            submit_update => 1,
            update => 'update from a registered user',
            add_alert => 1,
            fixed => 1,
        },
        changed => {
            update => 'Update from a registered user'
        },
        initial_banner => undef,
        endstate_banner => 'Fixed',
        alert => 1,
        anonymous => 0,
    },
    {
        desc => 'submit another update for registered user and want no more alerts',
        initial_values => {
            name => 'Commenter',
            may_show_name => 1,
            add_alert => 1,
            photo => '',
            update => '',
        },
        email  => 'commenter@example.com',
        fields => {
            submit_update => 1,
            update => 'another update from a registered user',
            add_alert => undef,
        },
        changed => {
            update => 'Another update from a registered user'
        },
        initial_banner => 'Fixed',
        endstate_banner => 'Fixed',
        alert => 0,
        anonymous => 0,
    },
        # If logged in person unticks the box and already has an alert, they should be unsubscribed.
) {
    subtest $test->{desc} => sub {
        $mech->log_out_ok();

        # clear out comments for this problem to make
        # checking details easier later
        ok( $_->delete, 'deleted comment ' . $_->id )
            for $report->comments;

        $mech->clear_emails_ok();

        $mech->log_in_ok( $test->{email} );
        $mech->get_ok("/report/$report_id");

        my $values = $mech->visible_form_values( 'updateForm' );

        is_deeply $values, $test->{initial_values}, 'initial form values';

        if ( !defined( $test->{initial_banner} ) ) {
            is $mech->extract_problem_banner->{text}, undef, 'initial banner';
        } else {
            like $mech->extract_problem_banner->{text}, qr/@{[ $test->{initial_banner} ]}/i, 'initial banner';
        }

        $mech->submit_form_ok(
            {
                with_fields => $test->{fields},
            },
            'submit update'
        );

        $mech->content_contains('Thank you for updating this issue');
        $mech->content_contains("/report/" . $report_id);
        $mech->get_ok("/report/" . $report_id);

        if ( !defined( $test->{endstate_banner} ) ) {
            is $mech->extract_problem_banner->{text}, undef, 'endstate banner';
        } else {
            like $mech->extract_problem_banner->{text}, qr/@{[ $test->{endstate_banner} ]}/i, 'endstate banner';
        }

        $mech->email_count_is(0);

        my $results = {
            %{ $test->{fields} },
            %{ $test->{changed} },
        };

        my $update = $report->comments->first;
        ok $update, 'found update';
        is $update->text, $results->{update}, 'update text';
        is $update->user->email, $test->{email}, 'update user';
        is $update->state, 'confirmed', 'update confirmed';
        is $update->anonymous, $test->{anonymous}, 'user anonymous';

        my $alert =
          FixMyStreet::App->model('DB::Alert')
          ->find( { user => $update->user, alert_type => 'new_updates', confirmed => 1, whendisabled => undef } );

        ok $test->{alert} ? $alert : !$alert, 'not signed up for alerts';
    };
}

foreach my $test (
    {
        desc           => 'logged in reporter submits update and marks problem fixed',
        initial_values => {
            name          => 'Test User',
            may_show_name => 1,
            add_alert     => 1,
            photo         => '',
            update        => '',
            fixed         => undef,
        },
        email  => 'test@example.com',
        fields => {
            submit_update => 1,
            update        => 'update from owner',
            add_alert     => undef,
            fixed         => 1,
        },
        changed        => { update => 'Update from owner' },
        initial_banner => undef,
        initial_state  => 'confirmed',
        alert     => 1,    # we signed up for alerts before, do not unsign us
        anonymous => 0,
        answered  => 0,
        content =>
"Thanks, glad to hear it's been fixed! Could we just ask if you have ever reported a problem to a council before?",
    },
    {
        desc           => 'logged in reporter submits update and marks in progress problem fixed',
        initial_values => {
            name          => 'Test User',
            may_show_name => 1,
            add_alert     => 1,
            photo         => '',
            update        => '',
            fixed         => undef,
        },
        email  => 'test@example.com',
        fields => {
            submit_update => 1,
            update        => 'update from owner',
            add_alert     => undef,
            fixed         => 1,
        },
        changed        => { update => 'Update from owner' },
        initial_banner => 'In progress',
        initial_state  => 'in progress',
        alert     => 1,    # we signed up for alerts before, do not unsign us
        anonymous => 0,
        answered  => 0,
        content =>
"Thanks, glad to hear it's been fixed! Could we just ask if you have ever reported a problem to a council before?",
    },
    {
        desc =>
'logged in reporter submits update and marks problem fixed and has answered questionnaire',
        initial_values => {
            name          => 'Test User',
            may_show_name => 1,
            add_alert     => 1,
            photo         => '',
            update        => '',
            fixed         => undef,
        },
        email  => 'test@example.com',
        fields => {
            submit_update => 1,
            update        => 'update from owner',
            add_alert     => undef,
            fixed         => 1,
        },
        changed        => { update => 'Update from owner' },
        initial_banner => undef,
        initial_state  => 'confirmed',
        alert     => 1,    # we signed up for alerts before, do not unsign us
        anonymous => 0,
        answered  => 1,
        content => $report->title,
    },
  )
{
    subtest $test->{desc} => sub {

        # double check
        $mech->log_out_ok();

        # clear out comments for this problem to make
        # checking details easier later
        ok( $_->delete, 'deleted comment ' . $_->id ) for $report->comments;

        $report->discard_changes;
        $report->state( $test->{initial_state} );
        $report->update;

        my $questionnaire;
        if ( $test->{answered} ) {
            $questionnaire =
              FixMyStreet::App->model('DB::Questionnaire')->create(
                {
                    problem_id    => $report_id,
                    ever_reported => 'y',
                    whensent      => \'current_timestamp',
                }
              );

            ok $questionnaire, 'added questionnaire';
        }

        $report->discard_changes;

        $mech->clear_emails_ok();

        $mech->log_in_ok( $test->{email} );
        $mech->get_ok("/report/$report_id");

        my $values = $mech->visible_form_values('updateForm');

        is_deeply $values, $test->{initial_values}, 'initial form values';

        if ( !defined( $test->{initial_banner} ) ) {
            is $mech->extract_problem_banner->{text}, undef, 'initial banner';
        } else {
            like $mech->extract_problem_banner->{text}, qr/@{[ $test->{initial_banner} ]}/i,
              'initial banner';
        }

        $mech->submit_form_ok( { with_fields => $test->{fields}, },
            'submit update' );

        is $mech->uri->path, '/report/update', "page after submission";

        $mech->content_contains( $test->{content} );

        $mech->email_count_is(0);

        my $results = { %{ $test->{fields} }, %{ $test->{changed} }, };

        $report->discard_changes;

        my $update = $report->comments->first;
        ok $update, 'found update';
        is $update->text, $results->{update}, 'update text';
        is $update->user->email, $test->{email}, 'update user';
        is $update->state, 'confirmed', 'update confirmed';
        is $update->anonymous, $test->{anonymous}, 'user anonymous';

        is $report->state, 'fixed - user', 'report state';

        SKIP: {
            skip( 'not answering questionnaire', 5 ) if $questionnaire;

            $mech->submit_form_ok( );

            my @errors = @{ $mech->page_errors };
            ok scalar @errors, 'displayed error messages';
            is $errors[0], "Please say whether you've ever reported a problem to your council before", 'error message';

            $mech->submit_form_ok( { with_fields => { reported => 'Yes' } } );

            $mech->content_contains( $report->title );
            $mech->content_contains( 'Thank you for updating this issue' );

            $questionnaire = FixMyStreet::App->model( 'DB::Questionnaire' )->find(
                { problem_id => $report_id }
            );

            ok $questionnaire, 'questionnaire exists';
            ok $questionnaire->ever_reported, 'ever reported is yes';
            is $questionnaire->old_state(), $test->{initial_state}, 'questionnaire old state';
            is $questionnaire->new_state(), 'fixed - user', 'questionnaire new state';
        };

        if ($questionnaire) {
            $questionnaire->delete;
            ok !$questionnaire->in_storage, 'questionnaire deleted';
        }
    };
}


for my $test (
    {
        desc           => 'reporter submits update and marks problem fixed',
        fields => {
            submit_update => 1,
            name          => 'Test User',
            rznvy         => 'test@example.com',
            may_show_name => 1,
            update        => 'update from owner',
            add_alert     => undef,
            fixed         => 1,
        },
        changed        => { update => 'Update from owner' },
        initial_banner => undef,
        alert     => 1,    # we signed up for alerts before, do not unsign us
        anonymous => 0,
        answered  => 0,
        path => '/report/update',
        content =>
"Thanks, glad to hear it's been fixed! Could we just ask if you have ever reported a problem to a council before?",
    },
    {
        desc =>
'reporter submits update and marks problem fixed and has answered questionnaire',
        fields => {
            submit_update => 1,
            name          => 'Test User',
            may_show_name => 1,
            rznvy         => 'test@example.com',
            update        => 'update from owner',
            add_alert     => undef,
            fixed         => 1,
        },
        changed        => { update => 'Update from owner' },
        initial_banner => undef,
        alert     => 1,    # we signed up for alerts before, do not unsign us
        anonymous => 0,
        answered  => 1,
        path    => '/report/update',
        content => "Thank you for updating this issue",
    },
  )
{
    subtest $test->{desc} => sub {

        # double check
        $mech->log_out_ok();

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
                    whensent      => \'current_timestamp',
                }
              );

            ok $questionnaire, 'added questionnaire';
        }

        $report->discard_changes;

        $mech->clear_emails_ok();

        $mech->get_ok("/report/$report_id");

        my $values = $mech->visible_form_values('updateForm');

        is $mech->extract_problem_banner->{text}, $test->{initial_banner},
          'initial banner';

        $mech->submit_form_ok( { with_fields => $test->{fields}, },
            'submit update' );

        is $mech->uri->path, $test->{path}, "page after submission";

        $mech->content_contains( 'Now check your email' );

        $mech->email_count_is(1);

        my $results = { %{ $test->{fields} }, %{ $test->{changed} }, };

        my $update = $report->comments->first;
        ok $update, 'found update';
        is $update->text, $results->{update}, 'update text';
        is $update->user->email, $test->{fields}->{rznvy}, 'update user';
        is $update->state, 'unconfirmed', 'update confirmed';
        is $update->anonymous, $test->{anonymous}, 'user anonymous';

        my $email = $mech->get_email;
        ok $email, "got an email";
        like $email->body, qr/confirm your update on/i, "Correct email text";

        my ( $url, $url_token ) = $email->body =~ m{(http://\S+/C/)(\S+)};
        ok $url, "extracted confirm url '$url'";

        my $token = FixMyStreet::App->model('DB::Token')->find(
            {
                token => $url_token,
                scope => 'comment'
            }
        );
        ok $token, 'Token found in database';

        $mech->get_ok( '/C/' . $url_token );

        $mech->content_contains( $test->{content} );

        SKIP: {
            skip( 'not answering questionnaire', 5 ) if $questionnaire;

            $mech->submit_form_ok( );

            my @errors = @{ $mech->page_errors };
            ok scalar @errors, 'displayed error messages';
            is $errors[0], "Please say whether you've ever reported a problem to your council before", 'error message';

            $mech->submit_form_ok( { with_fields => { reported => 'Yes' } } );

            $mech->content_contains( $report->title );
            $mech->content_contains( 'Thank you for updating this issue' );

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

for my $test (
    {
        desc => 'update confirmed without marking as fixed leaves state unchanged',
        initial_state => 'confirmed',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 0,
        },
        end_state => 'confirmed',
    },
    {
        desc => 'update investigating without marking as fixed leaves state unchanged',
        initial_state => 'investigating',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 0,
        },
        end_state => 'investigating',
    },
    {
        desc => 'update in progress without marking as fixed leaves state unchanged',
        initial_state => 'in progress',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 0,
        },
        end_state => 'in progress',
    },
    {
        desc => 'update action scheduled without marking as fixed leaves state unchanged',
        initial_state => 'action scheduled',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 0,
        },
        end_state => 'action scheduled',
    },
    {
        desc => 'update fixed without marking as open leaves state unchanged',
        initial_state => 'fixed',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 0,
        },
        end_state => 'fixed',
    },
    {
        desc => 'update unable to fix without marking as fixed leaves state unchanged',
        initial_state => 'unable to fix',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 0,
        },
        end_state => 'unable to fix',
    },
    {
        desc => 'update internal referral without marking as fixed leaves state unchanged',
        initial_state => 'internal referral',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 0,
        },
        end_state => 'internal referral',
    },
    {
        desc => 'update not responsible without marking as fixed leaves state unchanged',
        initial_state => 'not responsible',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 0,
        },
        end_state => 'not responsible',
    },
    {
        desc => 'update duplicate without marking as fixed leaves state unchanged',
        initial_state => 'duplicate',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 0,
        },
        end_state => 'duplicate',
    },
    {
        desc => 'can mark confirmed as fixed',
        initial_state => 'confirmed',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 1,
        },
        end_state => 'fixed - user',
    },
    {
        desc => 'can mark investigating as fixed',
        initial_state => 'investigating',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 1,
        },
        end_state => 'fixed - user',
    },
    {
        desc => 'can mark in progress as fixed',
        initial_state => 'in progress',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 1,
        },
        end_state => 'fixed - user',
    },
    {
        desc => 'can mark action scheduled as fixed',
        initial_state => 'action scheduled',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 1,
        },
        end_state => 'fixed - user',
    },
    {
        desc => 'cannot mark fixed as fixed, can mark as not fixed',
        initial_state => 'fixed',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 1,
        },
        end_state => 'confirmed',
    },
    {
        desc => 'can mark unable to fix as fixed, cannot mark not closed',
        initial_state => 'unable to fix',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 1,
        },
        end_state => 'fixed - user',
    },
    {
        desc => 'can mark internal referral as fixed, cannot mark not closed',
        initial_state => 'internal referral',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 1,
        },
        end_state => 'fixed - user',
    },
    {
        desc => 'can mark not responsible as fixed, cannot mark not closed',
        initial_state => 'not responsible',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 1,
        },
        end_state => 'fixed - user',
    },
    {
        desc => 'can mark duplicate as fixed, cannot mark not closed',
        initial_state => 'duplicate',
        expected_form_fields => {
            fixed => undef,
        },
        submitted_form_fields => {
            fixed => 1,
        },
        end_state => 'fixed - user',
    },
) {
    subtest $test->{desc} => sub {
        $mech->log_in_ok( $report->user->email );

        my %standard_fields = (
            name => $report->user->name,
            update => 'update text',
            photo         => '',
            may_show_name => 1,
            add_alert => 1,
        );

        my %expected_fields = (
            %standard_fields,
            %{ $test->{expected_form_fields} },
            update => '',
        );

        my %submitted_fields = (
            %standard_fields,
            %{ $test->{submitted_form_fields} },
        );

        # clear out comments for this problem to make
        # checking details easier later
        ok( $_->delete, 'deleted comment ' . $_->id ) for $report->comments;

        $report->discard_changes;
        $report->state($test->{initial_state});
        $report->update;

        $mech->get_ok("/report/$report_id");

        my $values = $mech->visible_form_values('updateForm');
        is_deeply $values, \%expected_fields, 'correct form fields present';

        if ( $test->{submitted_form_fields} ) {
            $mech->submit_form_ok( {
                    with_fields => \%submitted_fields
                },
                'submit update'
            );

            $report->discard_changes;
            is $report->state, $test->{end_state}, 'update sets correct report state';
        }
    };
}

subtest 'check have to be logged in for creator fixed questionnaire' => sub {
    $mech->log_out_ok();

    $mech->get_ok( "/questionnaire/submit?problem=$report_id&reported=Yes" );

    $mech->content_contains( "I'm afraid we couldn't locate your problem in the database." )
};

subtest 'check cannot answer other user\'s creator fixed questionnaire' => sub {
    $mech->log_out_ok();
    $mech->log_in_ok( $user2->email );

    $mech->get_ok( "/questionnaire/submit?problem=$report_id&reported=Yes" );

    $mech->content_contains( "I'm afraid we couldn't locate your problem in the database." )
};

ok $comment->delete, 'deleted comment';
$mech->delete_user('commenter@example.com');
$mech->delete_user('test@example.com');
done_testing();
