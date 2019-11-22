use FixMyStreet::TestMech;
# avoid wide character warnings from the category change message
use open ':std', ':encoding(UTF-8)';

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');
my $user2 = $mech->create_user_ok('test2@example.com', name => 'Test User 2');
my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $oxfordshirecontact = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Traffic lights', email => 'lights@example.com' );

my $oxford = $mech->create_body_ok(2421, 'Oxford City Council');
$mech->create_contact_ok( body_id => $oxford->id, category => 'Graffiti', email => 'graffiti@example.net' );

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

my $log_entries = FixMyStreet::DB->resultset('AdminLog')->search(
    {
        object_type => 'problem',
        object_id   => $report->id
    },
    { 
        order_by => { -desc => 'id' },
    }
);

is $log_entries->count, 0, 'no admin log entries';

my $report_id = $report->id;
ok $report, "created test report - $report_id";

foreach my $test (
    {
        description => 'edit report title',
        fields      => {
            title      => 'Report to Edit',
            detail     => 'Detail for Report to Edit',
            state      => 'confirmed',
            name       => 'Test User',
            username => $user->email,
            anonymous  => 0,
            flagged    => undef,
            non_public => undef,
            closed_updates => undef,
        },
        changes     => { title => 'Edited Report', },
        log_entries => [qw/edit/],
        resend      => 0,
    },
    {
        description => 'edit report description',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Detail for Report to Edit',
            state      => 'confirmed',
            name       => 'Test User',
            username => $user->email,
            anonymous  => 0,
            flagged    => undef,
            non_public => undef,
            closed_updates => undef,
        },
        changes     => { detail => 'Edited Detail', },
        log_entries => [qw/edit edit/],
        resend      => 0,
    },
    {
        description => 'edit report user name',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'confirmed',
            name       => 'Test User',
            username => $user->email,
            anonymous  => 0,
            flagged    => undef,
            non_public => undef,
            closed_updates => undef,
        },
        changes     => { name => 'Edited User', },
        log_entries => [qw/edit edit edit/],
        resend      => 0,
        user        => $user,
    },
    {
        description => 'edit report set flagged true',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'confirmed',
            name       => 'Edited User',
            username => $user->email,
            anonymous  => 0,
            flagged    => undef,
            non_public => undef,
            closed_updates => undef,
        },
        changes => {
            flagged    => 'on',
        },
        log_entries => [qw/edit edit edit edit/],
        resend      => 0,
        user        => $user,
    },
    {
        description => 'edit report user email',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'confirmed',
            name       => 'Edited User',
            username => $user->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
            closed_updates => undef,
        },
        changes     => { username => $user2->email, },
        log_entries => [qw/edit edit edit edit edit/],
        resend      => 0,
        user        => $user2,
    },
    {
        description => 'change state to unconfirmed',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'confirmed',
            name       => 'Edited User',
            username => $user2->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
            closed_updates => undef,
        },
        expect_comment => 1,
        changes   => { state => 'unconfirmed' },
        log_entries => [qw/edit state_change edit edit edit edit edit/],
        resend      => 0,
    },
    {
        description => 'change state to confirmed',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'unconfirmed',
            name       => 'Edited User',
            username => $user2->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
            closed_updates => undef,
        },
        expect_comment => 1,
        changes   => { state => 'confirmed' },
        log_entries => [qw/edit state_change edit state_change edit edit edit edit edit/],
        resend      => 0,
    },
    {
        description => 'change state to fixed',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'confirmed',
            name       => 'Edited User',
            username => $user2->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
            closed_updates => undef,
        },
        expect_comment => 1,
        changes   => { state => 'fixed' },
        log_entries =>
          [qw/edit state_change edit state_change edit state_change edit edit edit edit edit/],
        resend => 0,
    },
    {
        description => 'change state to hidden',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'fixed',
            name       => 'Edited User',
            username => $user2->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
            closed_updates => undef,
        },
        expect_comment => 1,
        changes     => { state => 'hidden' },
        log_entries => [
            qw/edit state_change edit state_change edit state_change edit state_change edit edit edit edit edit/
        ],
        resend => 0,
    },
    {
        description => 'edit and change state',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'hidden',
            name       => 'Edited User',
            username => $user2->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
            closed_updates => undef,
        },
        expect_comment => 1,
        changes => {
            state     => 'confirmed',
            anonymous => 1,
        },
        log_entries => [
            qw/edit state_change edit state_change edit state_change edit state_change edit state_change edit edit edit edit edit/
        ],
        resend => 0,
    },
    {
        description => 'resend',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'confirmed',
            name       => 'Edited User',
            username => $user2->email,
            anonymous  => 1,
            flagged    => 'on',
            non_public => undef,
            closed_updates => undef,
        },
        changes     => {},
        log_entries => [
            qw/resend edit state_change edit state_change edit state_change edit state_change edit state_change edit edit edit edit edit/
        ],
        resend => 1,
    },
    {
        description => 'non public',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'confirmed',
            name       => 'Edited User',
            username => $user2->email,
            anonymous  => 1,
            flagged    => 'on',
            non_public => undef,
            closed_updates => undef,
        },
        changes     => {
            non_public => 'on',
        },
        log_entries => [
            qw/edit resend edit state_change edit state_change edit state_change edit state_change edit state_change edit edit edit edit edit/
        ],
        resend => 0,
    },
    {
        description => 'close to updates',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'confirmed',
            name       => 'Edited User',
            username   => $user2->email,
            anonymous  => 1,
            flagged    => 'on',
            non_public => 'on',
            closed_updates => undef,
        },
        changes => { closed_updates => 'on' },
        log_entries => [
            qw/edit edit resend edit state_change edit state_change edit state_change edit state_change edit state_change edit edit edit edit edit/
        ],
    },
    {
        description => 'change state to investigating as body superuser',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'confirmed',
            name       => 'Edited User',
            username   => $user2->email,
            anonymous  => 1,
            flagged    => 'on',
            non_public => 'on',
            closed_updates => undef,
        },
        expect_comment => 1,
        user_body => $oxfordshire,
        changes   => { state => 'investigating' },
        log_entries => [
            qw/edit state_change edit edit resend edit state_change edit state_change edit state_change edit state_change edit state_change edit edit edit edit edit/
        ],
        resend => 0,
    },
    {
        description => 'change state to in progess and change category as body superuser',
        fields      => {
            title      => 'Edited Report',
            detail     => 'Edited Detail',
            state      => 'investigating',
            name       => 'Edited User',
            username   => $user2->email,
            anonymous  => 1,
            flagged    => 'on',
            non_public => 'on',
            closed_updates => undef,
        },
        expect_comment => 1,
        expected_text => '*Category changed from ‘Other’ to ‘Potholes’*',
        user_body => $oxfordshire,
        changes   => { state => 'in progress', category => 'Potholes' },
        log_entries => [
            qw/edit state_change category_change edit state_change edit edit resend edit state_change edit state_change edit state_change edit state_change edit state_change edit edit edit edit edit/
        ],
        resend => 0,
    },
  )
{
    subtest $test->{description} => sub {
        $report->comments->delete;
        $log_entries->reset;

        if ( $test->{user_body} ) {
            $superuser->from_body( $test->{user_body}->id );
            $superuser->update;
        }

        $mech->get_ok("/admin/report_edit/$report_id");

        @{$test->{fields}}{'external_id', 'external_body', 'external_team', 'category'} = (13, "", "", "Other");
        is_deeply( $mech->visible_form_values(), $test->{fields}, 'initial form values' );

        my $new_fields = {
            %{ $test->{fields} },
            %{ $test->{changes} },
        };

        if ( $test->{resend} ) {
            $mech->click_ok( 'resend' );
        } else {
            $mech->submit_form_ok( { with_fields => $new_fields }, 'form_submitted' );
        }

        is_deeply( $mech->visible_form_values(), $new_fields, 'changed form values' );
        is $log_entries->count, scalar @{$test->{log_entries}}, 'log entry count';
        is $log_entries->next->action, $_, 'log entry added' for @{ $test->{log_entries} };

        $report->discard_changes;

        if ($report->state eq 'confirmed' && $report->whensent) {
            $mech->content_contains( 'type="submit" name="resend"', 'resend button' );
        } else {
            $mech->content_lacks( 'type="submit" name="resend"', 'no resend button' );
        }

        if ($report->state eq 'fixed') {
            $mech->content_contains('pin-green');
        }

        $test->{changes}->{flagged} = 1 if $test->{changes}->{flagged};
        $test->{changes}->{non_public} = 1 if $test->{changes}->{non_public};

        if ($test->{changes}->{closed_updates}) {
            is $report->get_extra_metadata('closed_updates'), 1, "closed_updates updated";
            $mech->get_ok("/report/$report_id");
            $mech->content_lacks('Provide an update');
            $report->unset_extra_metadata('closed_updates');
            $report->update;
            delete $test->{changes}->{closed_updates};
        }

        if ($test->{changes}{title} || $test->{changes}{detail} || $test->{changes}{anonymous}) {
            $mech->get_ok("/report/$report_id");
            $mech->content_contains("Anonymous: <del style='background-color:#fcc'>No</del><ins style='background-color:#cfc'>Yes</ins>") if $test->{changes}{anonymous};
            $mech->content_contains("Details: <ins style='background-color:#cfc'>Edited </ins>Detail<del style='background-color:#fcc'> for Report to Edit</del>") if $test->{changes}{detail};
            $mech->content_contains("Subject: <ins style='background-color:#cfc'>Edited </ins>Repor<del style='background-color:#fcc'>t to Edi</del>") if $test->{changes}{title};
        }

        is $report->$_, $test->{changes}->{$_}, "$_ updated" for grep { $_ ne 'username' } keys %{ $test->{changes} };

        if ( $test->{user} ) {
            is $report->user->id, $test->{user}->id, 'user changed';
        }

        if ( $test->{resend} ) {
            $mech->content_contains( 'That problem will now be resent' );
            is $report->whensent, undef, 'mark report to resend';
        }

        if ( $test->{expect_comment} ) {
            my $comment = $report->comments->first;
            ok $comment, 'report status change creates comment';
            is $report->comments->count, 1, 'report only has one comment';
            if ($test->{expected_text}) {
                is $comment->text, $test->{expected_text}, 'comment has expected text';
            } else {
                is $comment->text, '', 'comment has no text';
            }
            if ( $test->{user_body} ) {
                ok $comment->get_extra_metadata('is_body_user'), 'body user metadata set';
                ok !$comment->get_extra_metadata('is_superuser'), 'superuser metadata not set';
                is $comment->name, $test->{user_body}->name, 'comment name is body name';
            } else {
                ok !$comment->get_extra_metadata('is_body_user'), 'body user metadata not set';
                ok $comment->get_extra_metadata('is_superuser'), 'superuser metadata set';
                is $comment->name, _('an administrator'), 'comment name is admin';
            }
        } else {
            is $report->comments->count, 0, 'report has no comments';
        }

        $superuser->from_body(undef);
        $superuser->update;
    };
}

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {

subtest 'change report category' => sub {
    my ($ox_report) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Unsure', {
        category => 'Potholes',
        areas => ',2237,2421,', # Cached used by categories_for_point...
        latitude => 51.7549262252,
        longitude => -1.25617899435,
        whensent => \'current_timestamp',
    });
    $mech->get_ok("/admin/report_edit/" . $ox_report->id);

    $mech->submit_form_ok( { with_fields => { category => 'Traffic lights' } }, 'form_submitted' );
    $ox_report->discard_changes;
    is $ox_report->category, 'Traffic lights';
    isnt $ox_report->whensent, undef;
    is $ox_report->comments->count, 1, "Comment created for update";
    is $ox_report->comments->first->text, '*Category changed from ‘Potholes’ to ‘Traffic lights’*', 'Comment text correct';

    $mech->submit_form_ok( { with_fields => { category => 'Graffiti' } }, 'form_submitted' );
    $ox_report->discard_changes;
    is $ox_report->category, 'Graffiti';
    is $ox_report->whensent, undef;
};

};

subtest 'change email to new user' => sub {
    $log_entries->delete;
    $mech->get_ok("/admin/report_edit/$report_id");
    my $fields = {
        title  => $report->title,
        detail => $report->detail,
        state  => $report->state,
        name   => $report->name,
        username => $report->user->email,
        category => 'Potholes',
        anonymous => 1,
        flagged => 'on',
        non_public => 'on',
        closed_updates => undef,
        external_id => '13',
        external_body => '',
        external_team => '',
    };

    is_deeply( $mech->visible_form_values(), $fields, 'initial form values' );

    my $changes = {
        username => 'test3@example.com'
    };

    my $user3 = FixMyStreet::DB->resultset('User')->find( { email => 'test3@example.com' } );

    ok !$user3, 'user not in database';

    my $new_fields = {
        %{ $fields },
        %{ $changes },
    };

    $mech->submit_form_ok(
        {
            with_fields => $new_fields,
        }
    );

    is $log_entries->count, 1, 'created admin log entries';
    is $log_entries->first->action, 'edit', 'log action';
    is_deeply( $mech->visible_form_values(), $new_fields, 'changed form values' );

    $user3 = FixMyStreet::DB->resultset('User')->find( { email => 'test3@example.com' } );

    $report->discard_changes;

    ok $user3, 'new user created';
    is $report->user_id, $user3->id, 'user changed to new user';
};

subtest 'adding email to abuse list from report page' => sub {
    my $email = $report->user->email;

    my $abuse = FixMyStreet::DB->resultset('Abuse')->find( { email => $email } );
    $abuse->delete if $abuse;

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains('Ban user');

    $mech->click_ok('banuser');

    $mech->content_contains('User added to abuse list');
    $mech->content_contains('<small>User in abuse table</small>');

    $abuse = FixMyStreet::DB->resultset('Abuse')->find( { email => $email } );
    ok $abuse, 'entry created in abuse table';

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains('<small>User in abuse table</small>');
};

subtest 'flagging user from report page' => sub {
    $report->user->flagged(0);
    $report->user->update;

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains('Flag user');

    $mech->click_ok('flaguser');

    $mech->content_contains('User flagged');
    $mech->content_contains('Remove flag');

    $report->discard_changes;
    ok $report->user->flagged, 'user flagged';

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains('Remove flag');
};

subtest 'unflagging user from report page' => sub {
    $report->user->flagged(1);
    $report->user->update;

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains('Remove flag');

    $mech->click_ok('removeuserflag');

    $mech->content_contains('User flag removed');
    $mech->content_contains('Flag user');

    $report->discard_changes;
    ok !$report->user->flagged, 'user not flagged';

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains('Flag user');
};

subtest "Test setting a report from unconfirmed to something else doesn't cause a front end error" => sub {
    $report->update( { confirmed => undef, state => 'unconfirmed', non_public => 0 } );
    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->submit_form_ok( { with_fields => { state => 'investigating' } } );
    $report->discard_changes;
    ok( $report->confirmed, 'report has a confirmed timestamp' );
    $mech->get_ok("/report/$report_id");
};

subtest "Test display of report extra data" => sub {
    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('Extra data: No');
    $report->set_extra_metadata('extra_field', 'this is extra data');
    $report->update;
    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('extra_field</strong>: this is extra data');
};

subtest "Test alert count display" => sub {
    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('Alerts: 0');

    my $alert = FixMyStreet::DB->resultset('Alert')->find_or_create(
        {
            alert_type => 'new_updates',
            parameter => $report_id,
            user => $user,
        }
    );

    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('Alerts: 0', 'does not include unconfirmed reports');

    $alert->update( { confirmed => 1 } );
    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('Alerts: 1');

    $alert->update( { whendisabled => \"now()" } );
    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('Alerts: 0');

    $alert->delete;
};

my $report2 = FixMyStreet::DB->resultset('Problem')->find_or_create(
    {
        postcode           => 'SW1A 1AA',
        bodies_str         => '2504',
        areas              => ',105255,11806,11828,2247,2504,',
        category           => 'Other',
        title              => 'Report to Duplicate Edit',
        detail             => 'Detail for Duplicate Report to Edit',
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

subtest "Test display of report duplicates extra data" => sub {
    $report->update( { extra => undef } );
    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('Extra data: No');

    $report2->set_duplicate_of($report_id);
    $report2->update;

    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('Duplicates</strong>: ' . $report2->id);
};

subtest "Test display of fields extra data" => sub {
    $report->unset_extra_metadata( 'duplicates' );
    $report->update;
    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('Extra data: No');

    $report->push_extra_fields( {
        name => 'report_url',
        value => 'http://example.com',
    });
    $report->update;

    $report->discard_changes;

    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('report_url</strong>: http://example.com');

    $report->set_extra_fields( {
        description => 'Report URL',
        name => 'report_url',
        value => 'http://example.com',
    });
    $report->update;

    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('Report URL (report_url)</strong>: http://example.com');
};

done_testing();
