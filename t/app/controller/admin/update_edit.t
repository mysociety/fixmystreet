use FixMyStreet::TestMech;
# avoid wide character warnings from the category change message
use open ':std', ':encoding(UTF-8)';

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $user2 = $mech->create_user_ok('test2@example.com', name => 'Test User 2');

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $user3 = FixMyStreet::DB->resultset('User')->create( { email => 'test3@example.com' } );

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
        bodies_str         => '2504',
        areas              => ',105255,11806,11828,2247,2504,',
        category           => 'Other',
        title              => 'Report to Edit',
        detail             => 'Detail for Report to Edit',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
        external_id        => '13',
        state              => 'confirmed',
        confirmed          => $dt->ymd . ' ' . $dt->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => '',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.5016605453401',
        longitude          => '-0.142497580865087',
        user_id            => $user->id,
        whensent           => $dt->ymd . ' ' . $dt->hms,
    }
);

$mech->log_in_ok( $superuser->email );

my $report_id = $report->id;
ok $report, "created test report - $report_id";

my $update = FixMyStreet::DB->resultset('Comment')->create(
    {
        text => 'this is an update',
        user => $user,
        state => 'confirmed',
        problem => $report,
        mark_fixed => 0,
        anonymous => 1,
    }
);

my $log_entries = FixMyStreet::DB->resultset('AdminLog')->search(
    {
        object_type => 'update',
        object_id   => $update->id
    },
    { 
        order_by => { -desc => 'id' },
    }
);

is $log_entries->count, 0, 'no admin log entries';

for my $test (
    {
        desc => 'edit update text',
        fields => {
            text => 'this is an update',
            state => 'confirmed',
            name => '',
            anonymous => 1,
            username => $update->user->email,
        },
        changes => {
            text => 'this is a changed update',
        },
        log_count => 1,
        log_entries => [qw/edit/],
    },
    {
        desc => 'edit update name',
        fields => {
            text => 'this is a changed update',
            state => 'confirmed',
            name => '',
            anonymous => 1,
            username => $update->user->email,
        },
        changes => {
            name => 'A User',
        },
        log_count => 2,
        log_entries => [qw/edit edit/],
    },
    {
        desc => 'edit update anonymous',
        fields => {
            text => 'this is a changed update',
            state => 'confirmed',
            name => 'A User',
            anonymous => 1,
            username => $update->user->email,
        },
        changes => {
            anonymous => 0,
        },
        log_count => 3,
        log_entries => [qw/edit edit edit/],
    },
    {
        desc => 'edit update user',
        fields => {
            text => 'this is a changed update',
            state => 'confirmed',
            name => 'A User',
            anonymous => 0,
            username => $update->user->email,
        },
        changes => {
            username => $user2->email,
        },
        log_count => 4,
        log_entries => [qw/edit edit edit edit/],
        user => $user2,
    },
    {
        desc => 'edit update state',
        fields => {
            text => 'this is a changed update',
            state => 'confirmed',
            name => 'A User',
            anonymous => 0,
            username => $user2->email,
        },
        changes => {
            state => 'unconfirmed',
        },
        log_count => 5,
        log_entries => [qw/state_change edit edit edit edit/],
    },
    {
        desc => 'edit update state and text',
        fields => {
            text => 'this is a changed update',
            state => 'unconfirmed',
            name => 'A User',
            anonymous => 0,
            username => $user2->email,
        },
        changes => {
            text => 'this is a twice changed update',
            state => 'confirmed',
        },
        log_count => 7,
        log_entries => [qw/edit state_change state_change edit edit edit edit/],
    },
) {
    subtest $test->{desc} => sub {
        $log_entries->reset;
        $mech->get_ok('/admin/update_edit/' . $update->id );

        is_deeply $mech->visible_form_values, $test->{fields}, 'initial form values';

        my $to_submit = {
            %{ $test->{fields} },
            %{ $test->{changes} }
        };

        $mech->submit_form_ok( { with_fields => $to_submit } );

        is_deeply $mech->visible_form_values, $to_submit, 'submitted form values';

        is $log_entries->count, $test->{log_count}, 'number of log entries';
        is $log_entries->next->action, $_, 'log action' for @{ $test->{log_entries} };

        $update->discard_changes;

        is $update->$_, $test->{changes}->{$_} for grep { $_ ne 'username' } keys %{ $test->{changes} };
        if ( $test->{changes}{state} && $test->{changes}{state} eq 'confirmed' ) {
            isnt $update->confirmed, undef;
        }

        if ( $test->{user} ) {
            is $update->user->id, $test->{user}->id, 'update user';
        }
    };
}

my $westminster = $mech->create_body_ok(2504, 'Westminster City Council');
$report->bodies_str($westminster->id);
$report->update;

for my $test (
    {
        desc          => 'user is problem owner',
        problem_user  => $user,
        update_user   => $user,
        update_fixed  => 0,
        update_reopen => 0,
        update_state  => undef,
        user_body     => undef,
        content       => 'user is problem owner',
    },
    {
        desc          => 'user is body user',
        problem_user  => $user,
        update_user   => $user2,
        update_fixed  => 0,
        update_reopen => 0,
        update_state  => undef,
        user_body     => $westminster->id,
        content       => 'user is from same council as problem - ' . $westminster->id,
    },
    {
        desc          => 'update changed problem state',
        problem_user  => $user,
        update_user   => $user2,
        update_fixed  => 0,
        update_reopen => 0,
        update_state  => 'planned',
        user_body     => $westminster->id,
        content       => 'Update changed problem state to planned',
    },
    {
        desc          => 'update marked problem as fixed',
        problem_user  => $user,
        update_user   => $user3,
        update_fixed  => 1,
        update_reopen => 0,
        update_state  => undef,
        user_body     => undef,
        content       => 'Update marked problem as fixed',
    },
    {
        desc          => 'update reopened problem',
        problem_user  => $user,
        update_user   => $user,
        update_fixed  => 0,
        update_reopen => 1,
        update_state  => undef,
        user_body     => undef,
        content       => 'Update reopened problem',
    },
) {
    subtest $test->{desc} => sub {
        $report->user( $test->{problem_user} );
        $report->update;

        $update->user( $test->{update_user} );
        $update->problem_state( $test->{update_state} );
        $update->mark_fixed( $test->{update_fixed} );
        $update->mark_open( $test->{update_reopen} );
        $update->update;

        $test->{update_user}->from_body( $test->{user_body} );
        $test->{update_user}->update;

        $mech->get_ok('/admin/update_edit/' . $update->id );
        $mech->content_contains( $test->{content} );
    };
}

subtest 'editing update email creates new user if required' => sub {
    my $user = FixMyStreet::DB->resultset('User')->find( { email => 'test4@example.com' } );

    $user->delete if $user;

    my $fields = {
            text => 'this is a changed update',
            state => 'confirmed',
            name => 'A User',
            anonymous => 0,
            username => 'test4@example.com',
    };

    $mech->submit_form_ok( { with_fields => $fields } );

    $user = FixMyStreet::DB->resultset('User')->find( { email => 'test4@example.com' } );

    is_deeply $mech->visible_form_values, $fields, 'submitted form values';

    ok $user, 'new user created';

    $update->discard_changes;
    is $update->user->id, $user->id, 'update set to new user';
};

subtest 'adding email to abuse list from update page' => sub {
    my $email = $update->user->email;

    my $abuse = FixMyStreet::DB->resultset('Abuse')->find( { email => $email } );
    $abuse->delete if $abuse;

    $mech->get_ok( '/admin/update_edit/' . $update->id );
    $mech->content_contains('Ban user');

    $mech->click_ok('banuser');

    $mech->content_contains('User added to abuse list');
    $mech->content_contains('<small>User in abuse table</small>');

    $abuse = FixMyStreet::DB->resultset('Abuse')->find( { email => $email } );
    ok $abuse, 'entry created in abuse table';

    $mech->get_ok( '/admin/update_edit/' . $update->id );
    $mech->content_contains('<small>User in abuse table</small>');
};

subtest 'flagging user from update page' => sub {
    $update->user->flagged(0);
    $update->user->update;

    $mech->get_ok( '/admin/update_edit/' . $update->id );
    $mech->content_contains('Flag user');

    $mech->click_ok('flaguser');

    $mech->content_contains('User flagged');
    $mech->content_contains('Remove flag');

    $update->discard_changes;
    ok $update->user->flagged, 'user flagged';

    $mech->get_ok( '/admin/update_edit/' . $update->id );
    $mech->content_contains('Remove flag');
};

subtest 'unflagging user from update page' => sub {
    $update->user->flagged(1);
    $update->user->update;

    $mech->get_ok( '/admin/update_edit/' . $update->id );
    $mech->content_contains('Remove flag');

    $mech->click_ok('removeuserflag');

    $mech->content_contains('User flag removed');
    $mech->content_contains('Flag user');

    $update->discard_changes;
    ok !$update->user->flagged, 'user not flagged';

    $mech->get_ok( '/admin/update_edit/' . $update->id );
    $mech->content_contains('Flag user');
};

subtest 'hiding comment marked as fixed reopens report' => sub {
    $update->mark_fixed( 1 );
    $update->update;

    $report->state('fixed - user');
    $report->update;

    my $fields = {
            text => 'this is a changed update',
            state => 'hidden',
            name => 'A User',
            anonymous => 0,
            username => 'test2@example.com',
    };

    $mech->submit_form_ok( { with_fields => $fields } );

    $report->discard_changes;
    is $report->state, 'confirmed', 'report reopened';
    $mech->content_contains('Problem marked as open');
};

done_testing();
