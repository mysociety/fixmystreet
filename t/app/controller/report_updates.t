use strict;
use warnings;

package FixMyStreet::Cobrand::NoUpdates;

use parent 'FixMyStreet::Cobrand::FixMyStreet';

sub updates_disallowed { 1 }

package main;

use FixMyStreet::TestMech;
use Web::Scraper;
use Path::Class;
use DateTime;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $user2 = $mech->create_user_ok('commenter@example.com', name => 'Commenter');

my $body = $mech->create_body_ok(2504, 'Westminster City Council');

my $dt = DateTime->new(
    year   => 2011,
    month  => 04,
    day    => 16,
    hour   => 15,
    minute => 47,
    second => 23
);

my $report = FixMyStreet::DB->resultset('Problem')->find_or_create(
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

my $comment = FixMyStreet::DB->resultset('Comment')->find_or_create(
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
        meta => [ 'State changed to: Fixed', 'Posted anonymously at 15:47, Sat 16 April 2011' ]
    },
    {
        description => 'named user, anon is true, reopened',
        name       => 'Other User',
        anonymous  => 't',
        mark_fixed => 'false',
        mark_open  => 'true',
        meta => [ 'State changed to: Open', 'Posted anonymously at 15:47, Sat 16 April 2011' ]
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
        my $test_meta = ref $test->{meta} ? $test->{meta} : [ $test->{meta} ];
        is scalar @$meta, scalar @$test_meta, 'number of updates';
        is_deeply $meta, $test_meta;
    };
}

subtest "updates displayed on report with empty bodies_str" => sub {
    my $old_bodies_str = $report->bodies_str;
    $report->update({ bodies_str => undef });
    $comment->update({ problem_state => 'fixed - user' , mark_open => 'false', mark_fixed => 'false' });

    $mech->get_ok("/report/$report_id");

    my $meta = $mech->extract_update_metas;
    is scalar @$meta, 2, 'update displayed';

    $report->update({ bodies_str => $old_bodies_str });
};

subtest "unconfirmed updates not displayed" => sub {
    $comment->state( 'unconfirmed' );
    $comment->update;
    $mech->get_ok("/report/$report_id");

    my $meta = $mech->extract_update_metas;
    is scalar @$meta, 0, 'update not displayed';
};

subtest "several updates shown in correct order" => sub {
    my @qs;
    for my $fields ( { # One with an associated update below
            problem_id => $report_id,
            whensent => '2011-03-10 12:23:16',
            whenanswered => '2011-03-10 12:23:16',
            old_state => 'confirmed',
            new_state => 'confirmed',
        },
        { # One with no associated update
            problem_id => $report_id,
            whensent => '2011-03-11 12:23:16',
            whenanswered => '2011-03-11 12:23:16',
            old_state => 'confirmed',
            new_state => 'confirmed',
        },
        { # One with no associated update, different state (doesn't match problem state, never mind)
            problem_id => $report_id,
            whensent => '2011-03-12 12:23:16',
            whenanswered => '2011-03-12 12:23:16',
            old_state => 'investigating',
            new_state => 'investigating',
        },
        { # One for the fixed update
            problem_id => $report_id,
            whensent => '2011-03-15 08:12:36',
            whenanswered => '2011-03-15 08:12:36',
            old_state => 'confirmed',
            new_state => 'fixed - user',
        },
        { # One reopening, no associated update
            problem_id => $report_id,
            whensent => '2011-03-16 08:12:36',
            whenanswered => '2011-03-16 08:12:36',
            old_state => 'fixed - user',
            new_state => 'confirmed',
        },
        { # One marking fixed, no associated update
            problem_id => $report_id,
            whensent => '2011-03-17 08:12:36',
            whenanswered => '2011-03-17 08:12:36',
            old_state => 'confirmed',
            new_state => 'fixed - user',
        },
    ) {
        my $q = FixMyStreet::DB->resultset('Questionnaire')->find_or_create(
            $fields
        );
        push @qs, $q;
    }

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
        my $comment = FixMyStreet::DB->resultset('Comment')->find_or_create(
            $fields
        );
        if ($fields->{text} eq 'Second update') {
            $comment->set_extra_metadata(questionnaire_id => $qs[0]->id);
            $comment->update;
        }
        if ($fields->{text} eq 'Third update') {
            $comment->set_extra_metadata(questionnaire_id => $qs[3]->id);
            $comment->update;
        }
    }

    $mech->get_ok("/report/$report_id");

    my $meta = $mech->extract_update_metas;
    is scalar @$meta, 8, 'number of updates';
    is $meta->[0], 'Posted by Other User at 12:23, Thu 10 March 2011', 'first update';
    is $meta->[1], 'Posted by Main User at 12:23, Thu 10 March 2011 Still open, via questionnaire', 'second update';
    is $meta->[2], 'Still open, via questionnaire, 12:23, Fri 11 March 2011', 'questionnaire';
    is $meta->[3], 'Still open, via questionnaire, 12:23, Sat 12 March 2011', 'questionnaire';
    is $meta->[4], 'State changed to: Fixed', 'third update, part 1';
    is $meta->[5], 'Posted anonymously at 08:12, Tue 15 March 2011', 'third update, part 2';
    is $meta->[6], 'Still open, via questionnaire, 08:12, Wed 16 March 2011', 'reopen questionnaire';
    is $meta->[7], 'Questionnaire filled in by problem reporter; State changed to: Fixed, 08:12, Thu 17 March 2011', 'fix questionnaire';
    $report->questionnaires->delete;
};

for my $test (
    {
        desc => 'No email, no message',
        fields => {
            username  => '',
            update => '',
            name   => '',
            photo1 => '',
            photo2 => '',
            photo3 => '',
            fixed  => undef,
            add_alert => 1,
            may_show_name => undef,
            password_register => '',
            password_sign_in => '',
        },
        changes => {},
        field_errors => [ 'Please enter a message', 'Please enter your email', 'Please enter your name' ]
    },
    {
        desc => 'Invalid email, no message',
        fields => {
            username  => 'test',
            update => '',
            name   => '',
            photo1 => '',
            photo2 => '',
            photo3 => '',
            fixed  => undef,
            add_alert => 1,
            may_show_name => undef,
            password_sign_in => '',
            password_register => '',
        },
        changes => {},
        field_errors => [ 'Please enter a message', 'Please enter a valid email', 'Please enter your name' ]
    },
    {
        desc => 'email with spaces, no message',
        fields => {
            username => 'test @ example. com',
            update => '',
            name   => '',
            photo1 => '',
            photo2 => '',
            photo3 => '',
            fixed  => undef,
            add_alert => 1,
            may_show_name => undef,
            password_register => '',
            password_sign_in => '',
        },
        changes => {
            username => 'test@example.com',
        },
        field_errors => [ 'Please enter a message', 'Please enter your name' ]
    },
    {
        desc => 'email with uppercase, no message',
        fields => {
            username => 'test@EXAMPLE.COM',
            update => '',
            name   => '',
            photo1 => '',
            photo2 => '',
            photo3 => '',
            fixed  => undef,
            add_alert => 1,
            may_show_name => undef,
            password_register => '',
            password_sign_in => '',
        },
        changes => {
            username => 'test@example.com',
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
            username => '',
            may_show_name => undef,
            add_alert     => 1,
            photo1 => '',
            photo2 => '',
            photo3 => '',
            update        => '',
            fixed         => undef,
            password_register => '',
            password_sign_in => '',
        },
        form_values => {
            submit_update => 1,
            username => 'unregistered@example.com',
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
            username => '',
            may_show_name => undef,
            add_alert     => 1,
            photo1 => '',
            photo2 => '',
            photo3 => '',
            update        => '',
            fixed         => undef,
            password_register => '',
            password_sign_in => '',
        },
        form_values => {
            submit_update => 1,
            username => 'unregistered@example.com',
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
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/confirm your update on/i, "Correct email text";

        my $url = $mech->get_link_from_email($email);
        my ($url_token) = $url =~ m{/C/(\S+)};
        ok $url, "extracted confirm url '$url'";

        my $token = FixMyStreet::DB->resultset('Token')->find(
            {
                token => $url_token,
                scope => 'comment'
            }
        );
        ok $token, 'Token found in database';

        my $update_id  = $token->data->{id};
        my $add_alerts = $token->data->{add_alert};
        my $update =
          FixMyStreet::DB->resultset('Comment')->find( { id => $update_id } );

        my $details = {
            %{ $test->{form_values} },
            %{ $test->{changes} }
        };

        ok $update, 'found update in database';
        is $update->state, 'unconfirmed', 'update unconfirmed';
        is $update->user->email, $details->{username}, 'update email';
        is $update->text, $details->{update}, 'update text';
        is $add_alerts, $details->{add_alert} ? 1 : 0, 'do not sign up for alerts';

        $mech->get_ok( $url );
        $mech->content_contains("/report/$report_id#update_$update_id");

        my $unreg_user = FixMyStreet::DB->resultset( 'User' )->find( { email => $details->{username} } );

        ok $unreg_user, 'found user';

        my $alert = FixMyStreet::DB->resultset( 'Alert' )->find(
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
            username => '',
            may_show_name => undef,
            add_alert     => 1,
            photo1 => '',
            photo2 => '',
            photo3 => '',
            update        => '',
            fixed         => undef,
            password_register => '',
            password_sign_in => '',
        },
        form_values => {
            submit_update => 1,
            username => 'unregistered@example.com',
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
          FixMyStreet::DB->resultset('Comment')->find( { problem_id => $report_id, text => 'Update no email confirm' } );
        my $update_id = $update->id;

        $mech->content_contains('name="update_' . $update_id . '"');

        my $details = {
            %{ $test->{form_values} },
            %{ $test->{changes} }
        };

        ok $update, 'found update in database';
        is $update->state, 'confirmed', 'update confirmed';
        is $update->user->email, $details->{username}, 'update email';
        is $update->text, $details->{update}, 'update text';

        my $unreg_user = FixMyStreet::DB->resultset( 'User' )->find( { email => $details->{username} } );

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
    $mech->submit_form_ok( {
        form_id => 'form_update_form',
        fields => {
            may_show_name => 1,
            update => 'this is a forbidden update',
            state => 'fixed - council',
        },
    }, 'submitted with state');

    is $mech->uri->path, "/report/update", "at /report/update";

    my $errors = $mech->page_errors;
    is_deeply $errors, [ 'There was a problem with your update. Please try again.' ], 'error message';

    is $report->state, 'confirmed', 'state unchanged';
};

for my $state ( qw/unconfirmed hidden partial/ ) {
    subtest "check that update cannot set state to $state" => sub {
        $user->from_body( $body->id );
        $user->update;

        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok( {
            form_id => 'form_update_form',
            fields => {
                may_show_name => 1,
                update => 'this is a forbidden update',
                state => $state,
            },
        }, 'submitted with state');

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
            update => 'Set state to fixed',
            state => 'fixed - council',
        },
        state => 'fixed - council',
        meta => 'fixed',
    },
    {
        desc => 'from authority user marks report as action scheduled',
        fields => {
            name => $user->name,
            may_show_name => 1,
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
            update => 'Set state to unable to fix',
            state => 'no further action',
        },
        state => 'unable to fix',
    },
    {
        desc => 'from authority user marks report as internal referral',
        fields => {
            name => $user->name,
            may_show_name => 1,
            update => 'Set state to internal referral',
            state => 'internal referral',
        },
        state => 'internal referral',
    },
    {
        desc => 'from authority user marks report as not responsible',
        fields => {
            name => $user->name,
            may_show_name => 1,
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
            update => 'Set state to duplicate',
            state => 'duplicate',
        },
        state => 'duplicate',
    },
    {
        desc => 'from authority user marks report as internal referral',
        fields => {
            name => $user->name,
            may_show_name => 1,
            update => 'Set state to internal referral',
            state => 'internal referral',
        },
        state => 'internal referral',
    },
    {
        desc => 'from authority user marks report sent to two councils as fixed',
        fields => {
            name => $user->name,
            may_show_name => 1,
            update => 'Set state to fixed',
            state => 'fixed - council',
        },
        state => 'fixed - council',
        meta => 'fixed',
        report_bodies => $body->id . ',2505',
    },
    {
      desc => 'from authority user show username for users with correct permissions',
      fields => {
          name => $user->name,
          may_show_name => 1,
          update => 'Set state to fixed',
          state => 'fixed - council',
      },
      state => 'fixed - council',
      meta => 'fixed',
      report_bodies => $body->id . ',2505',
      view_username => 1
    },
) {
    subtest $test->{desc} => sub {
        $report->comments->delete;
        if ( $test->{ report_bodies } ) {
            $report->bodies_str( $test->{ report_bodies } );
            $report->update;
        }

        if ($test->{view_username}) {
          ok $user->user_body_permissions->create({
            body => $body,
            permission_type => 'view_body_contribute_details'
          }), 'Give user view_body_contribute_details permissions';
        }

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
        like $update_meta->[0], qr/$meta_state/i, 'update meta includes state change';

        if ($test->{view_username}) {
          like $update_meta->[1], qr{Westminster City Council \(Test User\)}, 'update meta includes council and user name';
          $user->user_body_permissions->delete_all;
        } else {
          like $update_meta->[1], qr{Westminster City Council}, 'update meta includes council name';
          $mech->content_contains( '<strong>Westminster City Council</strong>', 'council name in bold');
        }

        $report->discard_changes;
        is $report->state, $test->{state}, 'state set';
    };
}

subtest 'check meta correct for comments marked confirmed but not marked open' => sub {
    $report->comments->delete;
    my $comment = FixMyStreet::DB->resultset('Comment')->create(
        {
            user          => $user,
            problem_id    => $report->id,
            text          => 'update text',
            # Subtract a day to deal with any code/db timezone difference
            confirmed     => DateTime->now( time_zone => 'local' ) - DateTime::Duration->new( days => 1 ),
            problem_state => 'confirmed',
            anonymous     => 0,
            mark_open     => 0,
            mark_fixed    => 0,
            state         => 'confirmed',
        }
    );

    $mech->get_ok( "/report/" . $report->id );
    my $update_meta = $mech->extract_update_metas;
    unlike $update_meta->[0], qr/Open/,
      'update meta does not say reopened';

    $comment->update( { mark_open => 1, problem_state => undef } );
    $mech->get_ok( "/report/" . $report->id );
    $update_meta = $mech->extract_update_metas;

    like $update_meta->[0], qr/Open/, 'update meta does say open';

    $comment->update( { mark_open => 0, problem_state => undef } );
    $mech->get_ok( "/report/" . $report->id );
    $update_meta = $mech->extract_update_metas;

    unlike $update_meta->[0], qr/Open/,
      'update meta does not says marked as open';
    unlike $update_meta->[0], qr/Open/, 'update meta does not say reopened';
};

subtest "check first comment with no status change has no status in meta" => sub {
    $user->from_body( undef );
    $user->update;

    my $comment = $report->comments->first;
    $comment->update( { mark_fixed => 0, problem_state => 'confirmed' } );

    $mech->get_ok("/report/$report_id");

    my $update_meta = $mech->extract_update_metas;
    unlike $update_meta->[0], qr/State changed to/, 'update meta does not include state change';
};

subtest "check comment with no status change has not status in meta" => sub {
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
                    photo1 => '',
                    photo2 => '',
                    photo3 => '',
                    update => 'Comment that does not change state',
                },
            },
            'submit update'
        );
        $mech->get_ok("/report/$report_id");

        $report->discard_changes;
        my @updates = $report->comments->search(undef, { order_by => ['created', 'id'] })->all;
        is scalar @updates, 2, 'correct number of updates';

        my $update = pop @updates;

        is $report->state, 'fixed - council', 'correct report state';
        is $update->problem_state, 'fixed - council', 'correct update state';
        my $update_meta = $mech->extract_update_metas;
        unlike $update_meta->[1], qr/State changed to/, 'update meta does not include state change';

        $user->from_body( $body->id );
        $user->update;

        $mech->get_ok("/report/$report_id");

        $mech->submit_form_ok(
            {
                with_fields => {
                    name => $user->name,
                    may_show_name => 1,
                    add_alert => undef,
                    photo1 => '',
                    photo2 => '',
                    photo3 => '',
                    update => 'Comment that sets state to investigating',
                    state => 'investigating',
                },
            },
            'submit update'
        );
        $mech->get_ok("/report/$report_id");

        $report->discard_changes;
        @updates = $report->comments->search(undef, { order_by => ['created', 'id'] })->all;

        is scalar @updates, 3, 'correct number of updates';

        $update = pop @updates;

        is $report->state, 'investigating', 'correct report state';
        is $update->problem_state, 'investigating', 'correct update state';
        $update_meta = $mech->extract_update_metas;
        like $update_meta->[0], qr/fixed/i, 'first update meta says fixed';
        unlike $update_meta->[2], qr/State changed to/, 'second update meta does not include state change';
        like $update_meta->[3], qr/investigating/i, 'third update meta says investigating';

        my $dt = DateTime->now( time_zone => "local" )->add( seconds => 1 );
        $comment = FixMyStreet::DB->resultset('Comment')->find_or_create(
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
        @updates = $report->comments->search(undef, { order_by => ['created', 'id'] })->all;;
        is scalar @updates, 4, 'correct number of updates';

        $update = pop @updates;

        is $report->state, 'investigating', 'correct report state';
        is $update->problem_state, undef, 'no update state';
        $update_meta = $mech->extract_update_metas;
        like $update_meta->[0], qr/fixed/i, 'first update meta says fixed';
        unlike $update_meta->[2], qr/State changed to/, 'second update meta does not include state change';
        like $update_meta->[3], qr/investigating/i, 'third update meta says investigating';
        unlike $update_meta->[5], qr/State changed to/, 'fourth update meta has no state change';
};

subtest 'check meta correct for second comment marking as reopened' => sub {
    $report->comments->delete;
    my $comment = FixMyStreet::DB->resultset('Comment')->create(
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
    like $update_meta->[0], qr/fixed/i, 'update meta says fixed';

    $comment = FixMyStreet::DB->resultset('Comment')->create(
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
    like $update_meta->[2], qr/Open/, 'update meta says reopened';
};

subtest 'check meta correct for comment after mark_fixed with not problem_state' => sub {
    $report->comments->delete;
    my $comment = FixMyStreet::DB->resultset('Comment')->create(
        {
            user          => $user,
            problem_id    => $report->id,
            text          => 'update text',
            confirmed     => DateTime->now( time_zone => 'local'),
            problem_state => '',
            anonymous     => 0,
            mark_open     => 0,
            mark_fixed    => 1,
            state         => 'confirmed',
        }
    );

    $mech->get_ok( "/report/" . $report->id );
    my $update_meta = $mech->extract_update_metas;
    like $update_meta->[0], qr/fixed/i, 'update meta says fixed';

    $comment = FixMyStreet::DB->resultset('Comment')->create(
        {
            user          => $user,
            problem_id    => $report->id,
            text          => 'update text',
            confirmed     => DateTime->now( time_zone => 'local' ) + DateTime::Duration->new( minutes => 1 ),
            problem_state => 'fixed - user',
            anonymous     => 0,
            mark_open     => 0,
            mark_fixed    => 0,
            state         => 'confirmed',
        }
    );

    $mech->get_ok( "/report/" . $report->id );
    $update_meta = $mech->extract_update_metas;
    unlike $update_meta->[2], qr/Fixed/i, 'update meta does not say fixed';
};

for my $test(
    {
      user => $user2,
      name => $body->name,
      body => $body,
      superuser => 0,
      desc =>"check first comment from body user with status change but no text is displayed"
    },
    {
      user => $user2,
      name => $body->name,
      superuser => 0,
      bodyuser => 1,
      desc =>"check first comment from ex body user with status change but no text is displayed"
    },
    {
      user => $user2,
      name => $body->name,
      body => $body,
      superuser => 1,
      desc =>"check first comment from body super user with status change but no text is displayed"
    },
    {
      user => $user2,
      name => 'an administrator',
      superuser => 1,
      desc =>"check first comment from super user with status change but no text is displayed"
    }
) {
subtest $test->{desc} => sub {
    my $extra = {};
    if ($test->{body}) {
        $extra->{is_body_user} = $test->{body}->id;
        $user2->from_body( $test->{body}->id );
    } else {
        if ($test->{superuser}) {
            $extra->{is_superuser} = 1;
        } elsif ($test->{bodyuser}) {
            $extra->{is_body_user} = $body->id;
        }
        $user2->from_body(undef);
    }
    $user2->is_superuser($test->{superuser});
    $user2->update;

    $report->comments->delete;

    my $comment = FixMyStreet::DB->resultset('Comment')->create(
        {
            user          => $test->{user},
            name          => $test->{name},
            problem_id    => $report->id,
            text          => '',
            confirmed     => DateTime->now( time_zone => 'local'),
            problem_state => 'investigating',
            anonymous     => 0,
            mark_open     => 0,
            mark_fixed    => 0,
            state         => 'confirmed',
            extra         => $extra,
        }
    );

    ok $user->user_body_permissions->search({
      body_id => $body->id,
      permission_type => 'view_body_contribute_details'
    })->delete, 'Remove user view_body_contribute_details permissions';

    $mech->get_ok("/report/$report_id");

    my $update_meta = $mech->extract_update_metas;
    like $update_meta->[1], qr/Updated by/, 'updated by meta if no text';
    unlike $update_meta->[1], qr/Commenter/, 'commenter name not included';
    like $update_meta->[0], qr/investigating/i, 'update meta includes state change';

    if ($test->{body} || $test->{bodyuser}) {
        like $update_meta->[1], qr/Westminster/, 'body user update uses body name';
    } elsif ($test->{superuser}) {
        like $update_meta->[1], qr/an administrator/, 'superuser update says an administrator';
    }

    ok $user->user_body_permissions->create({
      body => $body,
      permission_type => 'view_body_contribute_details'
    }), 'Give user view_body_contribute_details permissions';

    $mech->get_ok("/report/$report_id");
    $update_meta = $mech->extract_update_metas;
    like $update_meta->[1], qr/Updated by/, 'updated by meta if no text';
    like $update_meta->[1], qr/Commenter/, 'commenter name included if user has view contribute permission';
    like $update_meta->[0], qr/investigating/i, 'update meta includes state change';
};
}

for my $test(
    {
      desc =>"check comment from super user hiding report is not displayed",
      problem_state => 'hidden',
    },
    {
      desc =>"check comment from super user unconfirming report is not displayed",
      problem_state => 'unconfirmed',
    }
) {
subtest $test->{desc} => sub {
    my $extra = { is_superuser => 1 };
    $user2->is_superuser(1);
    $user2->update;

    $report->comments->delete;

    my $comment = FixMyStreet::DB->resultset('Comment')->create(
        {
            user          => $user2,
            name          => 'an administrator',
            problem_id    => $report->id,
            text          => '',
            confirmed     => DateTime->now( time_zone => 'local'),
            problem_state => $test->{problem_state},
            anonymous     => 0,
            mark_open     => 0,
            mark_fixed    => 0,
            state         => 'confirmed',
            extra         => $extra,
        }
    );
    $mech->get_ok("/report/$report_id");

    my $update_meta = $mech->extract_update_metas;
    is scalar(@$update_meta), 0, 'no comments on report';
  };
}

for my $test(
    {
      desc =>"check comments from super user hiding and unhiding report are not displayed",
      problem_states => [qw/hidden confirmed/],
      comment_count => 0,
    },
    {
      desc =>"check comment from super user unconfirming and confirming report are is not displayed",
      problem_states => [qw/unconfirmed confirmed/],
      comment_count => 0,
    },
    {
      desc =>"check comment after unconfirming and confirming a report is displayed",
      problem_states => [qw/unconfirmed confirmed investigating/],
      comment_count => 2, # state change line + who updated line
    },
    {
      desc =>"check comment after confirming a report after blank state is not displayed",
      problem_states => ['unconfirmed', '', 'confirmed'],
      comment_count => 0, # state change line + who updated line
    },
) {
subtest $test->{desc} => sub {
    my $extra = { is_superuser => 1 };
    $user2->is_superuser(1);
    $user2->update;

    $report->comments->delete;

    for my $state (@{$test->{problem_states}}) {
        my $comment = FixMyStreet::DB->resultset('Comment')->create(
            {
                user          => $user2,
                name          => 'an administrator',
                problem_id    => $report->id,
                text          => '',
                confirmed     => DateTime->now( time_zone => 'local'),
                problem_state => $state,
                anonymous     => 0,
                mark_open     => 0,
                mark_fixed    => 0,
                state         => 'confirmed',
                extra         => $extra,
            }
        );
    }
    $mech->get_ok("/report/$report_id");

    my $update_meta = $mech->extract_update_metas;
    is scalar(@$update_meta), $test->{comment_count}, 'expected number of comments on report';
  };
}

$user2->is_superuser(0);
$user2->from_body(undef);
$user2->update;

$user->from_body(undef);
$user->update;

$report->state('confirmed');
$report->bodies_str($body->id);
$report->update;
$report->comments->delete;

for my $test (
    {
        desc => 'submit an update for a registered user, signing in with wrong password',
        form_values => {
            submit_update => 1,
            username => 'registered@example.com',
            update        => 'Update from a user',
            add_alert     => undef,
            password_sign_in => 'secret',
        },
        field_errors => [
            "There was a problem with your login information. If you cannot remember your password, or do not have one, please fill in the \x{2018}No\x{2019} section of the form.",
            'Please enter your name', # FIXME Not really necessary error
        ],
    },
    {
        desc => 'submit an update for a registered user and sign in',
        form_values => {
            submit_update => 1,
            username => 'registered@example.com',
            update        => 'Update from a user',
            add_alert     => undef,
            password_sign_in => 'secret2',
        },
        message => 'You have successfully signed in; please check and confirm your details are accurate:',
    }
) {
    subtest $test->{desc} => sub {
        # Set things up
        my $user = $mech->create_user_ok( $test->{form_values}->{username} );
        $test->{form_values}{username} = $user->email;
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
            is $update->user->email, $test->{form_values}->{username}, 'update user';
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
            username => $user->email,
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
    my $body = $mech->get_text_body_from_email($email);
    like $body, qr/confirm your update on/i, "Correct email text";

    my $url = $mech->get_link_from_email($email);
    my ($url_token) = $url =~ m{/C/(\S+)};
    ok $url, "extracted confirm url '$url'";

    my $token = FixMyStreet::DB->resultset('Token')->find( {
        token => $url_token,
        scope => 'comment'
    } );
    ok $token, 'Token found in database';

    my $update_id  = $token->data->{id};
    my $add_alerts = $token->data->{add_alert};
    my $update = FixMyStreet::DB->resultset('Comment')->find( { id => $update_id } );

    ok $update, 'found update in database';
    is $update->state, 'unconfirmed', 'update unconfirmed';
    is $update->user->email, $user->email, 'update email';
    is $update->text, 'Update from a user', 'update text';

    $mech->get_ok( $url );
    $mech->content_contains("/report/$report_id#update_$update_id");

    # User should have new name and password
    $user->discard_changes;
    ok $user->check_password( 'new_secret' ), 'password changed';
    is $user->name, 'New Name', 'name changed';

    $update->discard_changes;
    is $update->state, 'confirmed', 'update confirmed';
    $mech->delete_user( $user );
};

my $sample_file = file(__FILE__)->parent->file("sample.jpg")->stringify;
ok -e $sample_file, "sample file $sample_file exists";

for my $test (
    {
        desc => 'submit update for registered user',
        initial_values => {
            name => 'Test User',
            may_show_name => 1,
            add_alert => 1,
            photo1 => '',
            photo2 => '',
            photo3 => '',
            update => '',
            fixed => undef,
        },
        email  => 'test@example.com',
        fields => {
            submit_update => 1,
            update => 'update from a registered user',
            add_alert => undef,
            fixed => undef,
            photo1 => [ [ $sample_file, undef, Content_Type => 'image/jpeg' ], 1 ],
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
            photo1 => '',
            photo2 => '',
            photo3 => '',
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
            photo1 => '',
            photo2 => '',
            photo3 => '',
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
            photo1 => '',
            photo2 => '',
            photo3 => '',
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
            photo1 => '',
            photo2 => '',
            photo3 => '',
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

        my $user = $mech->log_in_ok( $test->{email} );
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

        my $update = $report->comments->first;
        ok $update, 'found update';

        $mech->content_contains("/photo/c/" . $update->id . ".0.jpeg") if $test->{fields}->{photo1};

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

        is $update->text, $results->{update}, 'update text';
        is $update->user->email, $user->email, 'update user';
        is $update->state, 'confirmed', 'update confirmed';
        is $update->anonymous, $test->{anonymous}, 'user anonymous';

        my $alert =
          FixMyStreet::DB->resultset('Alert')
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
            photo1 => '',
            photo2 => '',
            photo3 => '',
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
            photo1 => '',
            photo2 => '',
            photo3 => '',
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
            photo1 => '',
            photo2 => '',
            photo3 => '',
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
              FixMyStreet::DB->resultset('Questionnaire')->create(
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

        my $user = $mech->log_in_ok( $test->{email} );
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
        is $update->user->email, $user->email, 'update user';
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

            $questionnaire = FixMyStreet::DB->resultset( 'Questionnaire' )->find(
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
            username => $report->user->email,
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
            username => $report->user->email,
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
              FixMyStreet::DB->resultset('Questionnaire')->create(
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

        my $results = { %{ $test->{fields} }, %{ $test->{changed} }, };

        my $update = $report->comments->first;
        ok $update, 'found update';
        is $update->text, $results->{update}, 'update text';
        is $update->user->email, $test->{fields}->{username}, 'update user';
        is $update->state, 'unconfirmed', 'update confirmed';
        is $update->anonymous, $test->{anonymous}, 'user anonymous';

        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/confirm your update on/i, "Correct email text";

        my $url = $mech->get_link_from_email($email);
        my ($url_token) = $url =~ m{/C/(\S+)};
        ok $url, "extracted confirm url '$url'";

        my $token = FixMyStreet::DB->resultset('Token')->find(
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

            $questionnaire = FixMyStreet::DB->resultset( 'Questionnaire' )->find(
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
        initial_state => 'fixed - user',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 0,
        },
        end_state => 'fixed - user',
    },
    {
        desc => 'update unable to fix without marking as fixed leaves state unchanged',
        initial_state => 'unable to fix',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 0,
        },
        end_state => 'unable to fix',
    },
    {
        desc => 'update internal referral without marking as fixed leaves state unchanged',
        initial_state => 'internal referral',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 0,
        },
        end_state => 'internal referral',
    },
    {
        desc => 'update not responsible without marking as fixed leaves state unchanged',
        initial_state => 'not responsible',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 0,
        },
        end_state => 'not responsible',
    },
    {
        desc => 'update duplicate without marking as fixed leaves state unchanged',
        initial_state => 'duplicate',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 0,
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
        initial_state => 'fixed - user',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 1,
        },
        end_state => 'confirmed',
    },
    {
        desc => 'cannot mark unable to fix as fixed, can reopen',
        initial_state => 'unable to fix',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 1,
        },
        end_state => 'confirmed',
    },
    {
        desc => 'cannot mark internal referral as fixed, can reopen',
        initial_state => 'internal referral',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 1,
        },
        end_state => 'confirmed',
    },
    {
        desc => 'cannot mark not responsible as fixed, can reopen',
        initial_state => 'not responsible',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 1,
        },
        end_state => 'confirmed',
    },
    {
        desc => 'cannot mark duplicate as fixed, can reopen',
        initial_state => 'duplicate',
        expected_form_fields => {
            reopen => undef,
        },
        submitted_form_fields => {
            reopen => 1,
        },
        end_state => 'confirmed',
    },
) {
    subtest $test->{desc} => sub {
        $mech->log_in_ok( $report->user->email );

        my %standard_fields = (
            name => $report->user->name,
            update => 'update text',
            photo1 => '',
            photo2 => '',
            photo3 => '',
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

    $mech->get( "/questionnaire/submit?problem=$report_id&reported=Yes" );
    is $mech->res->code, 400, "got 400";

    $mech->content_contains( "I'm afraid we couldn't locate your problem in the database." )
};

subtest 'check cannot answer other user\'s creator fixed questionnaire' => sub {
    $mech->log_out_ok();
    $mech->log_in_ok( $user2->email );

    $mech->get( "/questionnaire/submit?problem=$report_id&reported=Yes" );
    is $mech->res->code, 400, "got 400";

    $mech->content_contains( "I'm afraid we couldn't locate your problem in the database." )
};

subtest 'updates can be provided' => sub {
    $mech->log_out_ok();
    $mech->get( "/report/$report_id" );
    $mech->content_contains("Provide an update");
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { 'noupdates' => '.' } ],
}, sub {
    subtest 'test cobrand updates_disallowed' => sub {
        $mech->log_out_ok();
        $mech->get( "/report/$report_id" );
        $mech->content_lacks("Provide an update");
    };
};

done_testing();
