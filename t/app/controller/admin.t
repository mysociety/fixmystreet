use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $secret = FixMyStreet::App->model('DB::Secret')->search();

# don't explode if there's nothing in the secret table
if ( $secret == 0 ) {
    diag "You need to put an entry in the secret table for the admin tests to run";
    plan skip_all => 'No entry in secret table';
}

my $user =
  FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'test@example.com', name => 'Test User' } );
ok $user, "created test user";

my $user2 =
  FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'test2@example.com', name => 'Test User 2' } );
ok $user2, "created second test user";


my $user3 =
  FixMyStreet::App->model('DB::User')
  ->find( { email => 'test3@example.com', name => 'Test User 2' } );

if ( $user3 ) {
  $mech->delete_user( $user3 );
}

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
        title              => 'Report to Edit',
        detail             => 'Detail for Report to Edit',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
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

my $alert = FixMyStreet::App->model('DB::Alert')->find_or_create(
    {
        alert_type => 'new_updates',
        parameter => $report->id,
        confirmed => 1,
        user => $user,
    },
);

subtest 'check summary counts' => sub {
    my $problems = FixMyStreet::App->model('DB::Problem')->search( { state => { -in => [qw/confirmed fixed closed investigating planned/, 'in progress', 'fixed - user', 'fixed - council'] } } );

    my $problem_count = $problems->count;
    $problems->update( { cobrand => '' } );

    FixMyStreet::App->model('DB::Problem')->search( { council => 2489 } )->update( { council => 1 } );

    my $q = FixMyStreet::App->model('DB::Questionnaire')->find_or_new( { problem => $report, });
    $q->whensent( \'ms_current_timestamp()' );
    $q->in_storage ? $q->update : $q->insert;

    my $alerts =  FixMyStreet::App->model('DB::Alert')->search( { confirmed => { '>' => 0 } } );
    my $a_count = $alerts->count;

    $mech->get_ok('/admin');

    $mech->title_like(qr/Summary/);

    $mech->content_contains( "$problem_count</strong> live problems" );
    $mech->content_contains( "$a_count confirmed alerts" );

    my $questionnaires = FixMyStreet::App->model('DB::Questionnaire')->search( { whensent => { -not => undef } } );
    my $q_count = $questionnaires->count();

    $mech->content_contains( "$q_count questionnaires sent" );

    ok $mech->host('barnet.fixmystreet.com');

    $mech->get_ok('/admin');
    $mech->title_like(qr/Summary/);

    my ($num_live) = $mech->content =~ /(\d+)<\/strong> live problems/;
    my ($num_alerts) = $mech->content =~ /(\d+) confirmed alerts/;
    my ($num_qs) = $mech->content =~ /(\d+) questionnaires sent/;

    $report->council(2489);
    $report->cobrand('barnet');
    $report->update;

    $alert->cobrand('barnet');
    $alert->update;

    $mech->get_ok('/admin');

    $mech->content_contains( ($num_live+1) . "</strong> live problems" );
    $mech->content_contains( ($num_alerts+1) . " confirmed alerts" );
    $mech->content_contains( ($num_qs+1) . " questionnaires sent" );

    $report->council(2504);
    $report->cobrand('');
    $report->update;

    $alert->cobrand('');
    $alert->update;

    FixMyStreet::App->model('DB::Problem')->search( { council => 1 } )->update( { council => 2489 } );
    ok $mech->host('fixmystreet.com');
};

my $host = FixMyStreet->config('BASE_URL');
$mech->get_ok('/admin/council_contacts/2650');
$mech->content_contains('Aberdeen City Council');
$mech->content_like(qr{AB\d\d});
$mech->content_contains("$host/around");

subtest 'check contact creation' => sub {
    my $contact = FixMyStreet::App->model('DB::Contact')->search(
        { area_id => 2650, category => [ 'test category', 'test/category' ] }
    );
    $contact->delete_all;

    my $history = FixMyStreet::App->model('DB::ContactsHistory')->search(
        { area_id => 2650, category => [ 'test category', 'test/category' ] }
    );
    $history->delete_all;

    $mech->get_ok('/admin/council_contacts/2650');

    $mech->submit_form_ok( { with_fields => { 
        category => 'test category',
        email    => 'test@example.com',
        note     => 'test note',
    } } );

    $mech->content_contains( 'test category' );
    $mech->content_contains( '<td>test@example.com' );
    $mech->content_contains( '<td>test note' );

    $mech->submit_form_ok( { with_fields => {
        category => 'test/category',
        email    => 'test@example.com',
        note     => 'test/note',
    } } );
    $mech->get_ok('/admin/council_edit/2650/test/category');

};

subtest 'check contact editing' => sub {
    $mech->get_ok('/admin/council_edit/2650/test%20category');

    $mech->submit_form_ok( { with_fields => { 
        email    => 'test2@example.com',
        note     => 'test2 note',
    } } );

    $mech->content_contains( 'test category' );
    $mech->content_contains( '<td>test2@example.com' );
    $mech->content_contains( '<td>test2 note' );

    $mech->get_ok('/admin/council_edit/2650/test%20category');
    $mech->content_contains( '<td><strong>test2@example.com' );
};

subtest 'check contact updating' => sub {
    $mech->get_ok('/admin/council_edit/2650/test%20category');
    $mech->content_like(qr{test2\@example.com</strong>[^<]*</td>[^<]*<td>No}s);

    $mech->get_ok('/admin/council_contacts/2650');

    $mech->form_number( 1 );
    $mech->tick( 'confirmed', 'test category' );
    $mech->submit_form_ok({form_number => 1});

    $mech->content_like(qr'test2@example.com</td>[^<]*<td>Yes's);
    $mech->get_ok('/admin/council_edit/2650/test%20category');
    $mech->content_like(qr{test2\@example.com[^<]*</td>[^<]*<td><strong>Yes}s);
};

my $open311 =
  FixMyStreet::App->model('DB::Open311Conf')->search( { area_id => 2650 } );
$open311->delete if $open311;

subtest 'check open311 configuring' => sub {
    $mech->get_ok('/admin/council_contacts/2650/');
    $mech->content_lacks('Council contacts configured via Open311');

    $mech->form_number(3);
    $mech->submit_form_ok(
        {
            with_fields => {
                api_key      => 'api key',
                endpoint     => 'http://example.com/open311',
                jurisdiction => 'mySociety',
            }
        }
    );
    $mech->content_contains('Council contacts configured via Open311');
    $mech->content_contains('Configuration updated - contacts will be generated automatically later');

    $open311 =
      FixMyStreet::App->model('DB::Open311Conf')->search( { area_id => 2650 } );

    is $open311->count, 1, 'only one configuration';
    my $conf = $open311->first;
    is $conf->endpoint, 'http://example.com/open311', 'endpoint configured';
    is $conf->api_key, 'api key', 'api key configured';
    is $conf->jurisdiction, 'mySociety', 'jurisdiction configures';

    $mech->form_number(3);
    $mech->submit_form_ok(
        {
            with_fields => {
                api_key      => 'new api key',
                endpoint     => 'http://example.org/open311',
                jurisdiction => 'open311',
            }
        }
    );

    $mech->content_contains('Configuration updated');

    $open311 =
      FixMyStreet::App->model('DB::Open311Conf')->search( { area_id => 2650 } );

    is $open311->count, 1, 'only one configuration';
    $conf = $open311->first;
    is $conf->endpoint, 'http://example.org/open311', 'endpoint updated';
    is $conf->api_key, 'new api key', 'api key updated';
    is $conf->jurisdiction, 'open311', 'jurisdiction configures';
};

subtest 'check text output' => sub {
    $mech->get_ok('/admin/council_contacts/2650?text=1');
    is $mech->content_type, 'text/plain';
    $mech->content_contains('test category');
};

my $log_entries = FixMyStreet::App->model('DB::AdminLog')->search(
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
        fields => {
            title  => 'Report to Edit',
            detail => 'Detail for Report to Edit',
            state  => 'confirmed',
            name   => 'Test User',
            email  => $user->email,
            anonymous => 0,
            flagged => undef,
        },
        changes => {
            title => 'Edited Report',
        },
        log_count => 1,
        log_entries => [ qw/edit/ ],
        resend => 0,
    },
    {
        description => 'edit report description',
        fields => {
            title  => 'Edited Report',
            detail => 'Detail for Report to Edit',
            state  => 'confirmed',
            name   => 'Test User',
            email  => $user->email,
            anonymous => 0,
            flagged => undef,
        },
        changes => {
            detail => 'Edited Detail',
        },
        log_count => 2,
        log_entries => [ qw/edit edit/ ],
        resend => 0,
    },
    {
        description => 'edit report user name',
        fields => {
            title  => 'Edited Report',
            detail => 'Edited Detail',
            state  => 'confirmed',
            name   => 'Test User',
            email  => $user->email,
            anonymous => 0,
            flagged => undef,
        },
        changes => {
            name => 'Edited User',
        },
        log_count => 3,
        log_entries => [ qw/edit edit edit/ ],
        resend => 0,
        user => $user,
    },
    {
        description => 'edit report set flagged true',
        fields => {
            title  => 'Edited Report',
            detail => 'Edited Detail',
            state  => 'confirmed',
            name   => 'Edited User',
            email  => $user->email,
            anonymous => 0,
            flagged => undef,
        },
        changes => {
            flagged => 'on',
        },
        log_count => 4,
        log_entries => [ qw/edit edit edit edit/ ],
        resend => 0,
        user => $user,
    },
    {
        description => 'edit report user email',
        fields => {
            title  => 'Edited Report',
            detail => 'Edited Detail',
            state  => 'confirmed',
            name   => 'Edited User',
            email  => $user->email,
            anonymous => 0,
            flagged => 'on',
        },
        changes => {
            email => $user2->email,
        },
        log_count => 5,
        log_entries => [ qw/edit edit edit edit edit/ ],
        resend => 0,
        user => $user2,
    },
    {
        description => 'change state to unconfirmed',
        fields => {
            title  => 'Edited Report',
            detail => 'Edited Detail',
            state  => 'confirmed',
            name   => 'Edited User',
            email  => $user2->email,
            anonymous => 0,
            flagged => 'on',
        },
        changes => {
            state => 'unconfirmed'
        },
        log_count => 6,
        log_entries => [ qw/state_change edit edit edit edit edit/ ],
        resend => 0,
    },
    {
        description => 'change state to confirmed',
        fields => {
            title  => 'Edited Report',
            detail => 'Edited Detail',
            state  => 'unconfirmed',
            name   => 'Edited User',
            email  => $user2->email,
            anonymous => 0,
            flagged => 'on',
        },
        changes => {
            state => 'confirmed'
        },
        log_count => 7,
        log_entries => [ qw/state_change state_change edit edit edit edit edit/ ],
        resend => 0,
    },
    {
        description => 'change state to fixed',
        fields => {
            title  => 'Edited Report',
            detail => 'Edited Detail',
            state  => 'confirmed',
            name   => 'Edited User',
            email  => $user2->email,
            anonymous => 0,
            flagged => 'on',
        },
        changes => {
            state => 'fixed'
        },
        log_count => 8,
        log_entries => [ qw/state_change state_change state_change edit edit edit edit edit/ ],
        resend => 0,
    },
    {
        description => 'change state to hidden',
        fields => {
            title  => 'Edited Report',
            detail => 'Edited Detail',
            state  => 'fixed',
            name   => 'Edited User',
            email  => $user2->email,
            anonymous => 0,
            flagged => 'on',
        },
        changes => {
            state => 'hidden'
        },
        log_count => 9,
        log_entries => [ qw/state_change state_change state_change state_change edit edit edit edit edit/ ],
        resend => 0,
    },
    {
        description => 'edit and change state',
        fields => {
            title  => 'Edited Report',
            detail => 'Edited Detail',
            state  => 'hidden',
            name   => 'Edited User',
            email  => $user2->email,
            anonymous => 0,
            flagged => 'on',
        },
        changes => {
            state => 'confirmed',
            anonymous => 1,
        },
        log_count => 11,
        log_entries => [ qw/edit state_change state_change state_change state_change state_change edit edit edit edit edit/ ],
        resend => 0,
    },
    {
        description => 'resend',
        fields => {
            title  => 'Edited Report',
            detail => 'Edited Detail',
            state  => 'confirmed',
            name   => 'Edited User',
            email  => $user2->email,
            anonymous => 1,
            flagged => 'on',
        },
        changes => {
        },
        log_count => 12,
        log_entries => [ qw/resend edit state_change state_change state_change state_change state_change edit edit edit edit edit/ ],
        resend => 1,
    },
) {
    subtest $test->{description} => sub {
        $log_entries->reset;
        $mech->get_ok("/admin/report_edit/$report_id");

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
        is $log_entries->count, $test->{log_count}, 'log entry count';
        is $log_entries->next->action, $_, 'log entry added' for @{ $test->{log_entries} };

        $report->discard_changes;

        if ( $report->state eq 'confirmed' ) {
            $mech->content_contains( 'type="submit" name="resend"', 'no resend button' );
        } else {
            $mech->content_lacks( 'type="submit" name="resend"', 'no resend button' );
        }

        $test->{changes}->{flagged} = 1 if $test->{changes}->{flagged};
        is $report->$_, $test->{changes}->{$_}, "$_ updated" for grep { $_ ne 'email' } keys %{ $test->{changes} };

        if ( $test->{user} ) {
            is $report->user->id, $test->{user}->id, 'user changed';
        }

        if ( $test->{resend} ) {
            $mech->content_contains( 'That problem will now be resent' );
            is $report->whensent, undef, 'mark report to resend';
        }
    };
}

subtest 'change email to new user' => sub {
    $log_entries->delete;
    $mech->get_ok("/admin/report_edit/$report_id");
    my $fields = {
        title  => $report->title,
        detail => $report->detail,
        state  => $report->state,
        name   => $report->name,
        email  => $report->user->email,
        anonymous => 1,
        flagged => 'on',
    };

    is_deeply( $mech->visible_form_values(), $fields, 'initial form values' );

    my $changes = {
        email => 'test3@example.com'
    };

    $user3 =
      FixMyStreet::App->model('DB::User')
      ->find( { email => 'test3@example.com', name => 'Test User 2' } );

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

    $user3 =
      FixMyStreet::App->model('DB::User')
      ->find( { email => 'test3@example.com', name => 'Test User 2' } );

    $report->discard_changes;

    ok $user3, 'new user created';
    is $report->user_id, $user3->id, 'user changed to new user';
};

subtest 'adding email to abuse list from report page' => sub {
    my $email = $report->user->email;

    my $abuse = FixMyStreet::App->model('DB::Abuse')->find( { email => $email } );
    $abuse->delete if $abuse;

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains('Ban email address');

    $mech->click_ok('banuser');

    $mech->content_contains('Email added to abuse list');
    $mech->content_contains('<small>(Email in abuse table)</small>');

    $abuse = FixMyStreet::App->model('DB::Abuse')->find( { email => $email } );
    ok $abuse, 'entry created in abuse table';

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains('<small>(Email in abuse table)</small>');
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

$log_entries->delete;

my $update = FixMyStreet::App->model('DB::Comment')->create(
    {
        text => 'this is an update',
        user => $user,
        state => 'confirmed',
        problem => $report,
        mark_fixed => 0,
        anonymous => 1,
    }
);

$log_entries = FixMyStreet::App->model('DB::AdminLog')->search(
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
            email => 'test@example.com',
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
            email => 'test@example.com',
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
            email => 'test@example.com',
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
            email => $update->user->email,
            email => 'test@example.com',
        },
        changes => {
            email => 'test2@example.com',
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
            email => 'test2@example.com',
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
            email => 'test2@example.com',
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

        is $update->$_, $test->{changes}->{$_} for grep { $_ ne 'email' } keys %{ $test->{changes} };
        if ( $test->{changes}{state} && $test->{changes}{state} eq 'confirmed' ) {
            isnt $update->confirmed, undef;
        }

        if ( $test->{user} ) {
            is $update->user->id, $test->{user}->id, 'update user';
        }
    };
}

for my $test (
    {
        desc          => 'user is problem owner',
        problem_user  => $user,
        update_user   => $user,
        update_fixed  => 0,
        update_reopen => 0,
        update_state  => undef,
        user_council  => undef,
        content       => 'user is problem owner',
    },
    {
        desc          => 'user is council user',
        problem_user  => $user,
        update_user   => $user2,
        update_fixed  => 0,
        update_reopen => 0,
        update_state  => undef,
        user_council  => 2504,
        content       => 'user is from same council as problem - 2504',
    },
    {
        desc          => 'update changed problem state',
        problem_user  => $user,
        update_user   => $user2,
        update_fixed  => 0,
        update_reopen => 0,
        update_state  => 'planned',
        user_council  => 2504,
        content       => 'Update changed problem state to planned',
    },
    {
        desc          => 'update marked problem as fixed',
        problem_user  => $user,
        update_user   => $user3,
        update_fixed  => 1,
        update_reopen => 0,
        update_state  => undef,
        user_council  => undef,
        content       => 'Update marked problem as fixed',
    },
    {
        desc          => 'update reopened problem',
        problem_user  => $user,
        update_user   => $user,
        update_fixed  => 0,
        update_reopen => 1,
        update_state  => undef,
        user_council  => undef,
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

        $test->{update_user}->from_council( $test->{user_council} );
        $test->{update_user}->update;

        $mech->get_ok('/admin/update_edit/' . $update->id );
        $mech->content_contains( $test->{content} );
    };
}

subtest 'editing update email creates new user if required' => sub {
    my $user = FixMyStreet::App->model('DB::User')->find(
        { email => 'test4@example.com' } 
    );

    $user->delete if $user;

    my $fields = {
            text => 'this is a changed update',
            state => 'hidden',
            name => 'A User',
            anonymous => 0,
            email => 'test4@example.com',
    };

    $mech->submit_form_ok( { with_fields => $fields } );

    $user = FixMyStreet::App->model('DB::User')->find(
        { email => 'test4@example.com' } 
    );

    is_deeply $mech->visible_form_values, $fields, 'submitted form values';

    ok $user, 'new user created';

    $update->discard_changes;
    is $update->user->id, $user->id, 'update set to new user';
};

subtest 'adding email to abuse list from update page' => sub {
    my $email = $update->user->email;

    my $abuse = FixMyStreet::App->model('DB::Abuse')->find( { email => $email } );
    $abuse->delete if $abuse;

    $mech->get_ok( '/admin/update_edit/' . $update->id );
    $mech->content_contains('Ban email address');

    $mech->click_ok('banuser');

    $mech->content_contains('Email added to abuse list');
    $mech->content_contains('<small>(Email in abuse table)</small>');

    $abuse = FixMyStreet::App->model('DB::Abuse')->find( { email => $email } );
    ok $abuse, 'entry created in abuse table';

    $mech->get_ok( '/admin/update_edit/' . $update->id );
    $mech->content_contains('<small>(Email in abuse table)</small>');
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

    $report->state('fixed');
    $report->update;


    my $fields = {
            text => 'this is a changed update',
            state => 'hidden',
            name => 'A User',
            anonymous => 0,
            email => 'test2@example.com',
    };

    $mech->submit_form_ok( { with_fields => $fields } );

    $report->discard_changes;
    is $report->state, 'confirmed', 'report reopened';
    $mech->content_contains('Problem marked as open');
};

$log_entries->delete;

subtest 'report search' => sub {
    $update->state('confirmed');
    $update->user($report->user);
    $update->update;

    $mech->get_ok('/admin/search_reports');
    $mech->get_ok('/admin/search_reports?search=' . $report->id );

    $mech->content_contains( $report->title );
    my $r_id = $report->id;
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id/">$r_id</a>} );

    $mech->get_ok('/admin/search_reports?search=' . $report->user->email);

    my $u_id = $update->id;
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id/">$r_id</a>} );
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id/#update_$u_id">$u_id</a>} );

    $update->state('hidden');
    $update->update;

    $mech->get_ok('/admin/search_reports?search=' . $report->user->email);
    $mech->content_like( qr{<tr [^>]*hidden[^>]*> \s* <td> \s* $u_id \s* </td>}xs );

    $report->state('hidden');
    $report->update;

    $mech->get_ok('/admin/search_reports?search=' . $report->user->email);
    $mech->content_like( qr{<tr [^>]*hidden[^>]*> \s* <td> \s* $r_id \s* </td>}xs );

    $report->state('fixed - user');
    $report->update;

    $mech->get_ok('/admin/search_reports?search=' . $report->user->email);
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id/">$r_id</a>} );
};

subtest 'search abuse' => sub {
    $mech->get_ok( '/admin/search_abuse?search=example' );

    $mech->content_contains('test4@example.com');
};

subtest 'show flagged entries' => sub {
    $report->flagged( 1 );
    $report->update;

    $user->flagged( 1 );
    $user->update;

    $mech->get_ok('/admin/list_flagged');
    $mech->content_contains( $report->title );
    $mech->content_contains( $user->email );
};

subtest 'user search' => sub {
    $mech->get_ok('/admin/search_users');
    $mech->get_ok('/admin/search_users?search=' . $user->name);

    $mech->content_contains( $user->name);
    my $u_id = $user->id;
    $mech->content_like( qr{user_edit/$u_id">Edit</a>} );

    $mech->get_ok('/admin/search_users?search=' . $user->email);

    $mech->content_like( qr{user_edit/$u_id">Edit</a>} );

    $user->from_council(2509);
    $user->update;
    $mech->get_ok('/admin/search_users?search=2509' );
    $mech->content_contains(2509);
};

$log_entries = FixMyStreet::App->model('DB::AdminLog')->search(
    {
        object_type => 'user',
        object_id   => $user->id
    },
    { 
        order_by => { -desc => 'id' },
    }
);

is $log_entries->count, 0, 'no admin log entries';

$user->flagged( 0 );
$user->update;

for my $test (
    {
        desc => 'edit user name',
        fields => {
            name => 'Test User',
            email => 'test@example.com',
            council => 2509,
            flagged => undef,
        },
        changes => {
            name => 'Changed User',
        },
        log_count => 1,
        log_entries => [qw/edit/],
    },
    {
        desc => 'edit user email',
        fields => {
            name => 'Changed User',
            email => 'test@example.com',
            council => 2509,
            flagged => undef,
        },
        changes => {
            email => 'changed@example.com',
        },
        log_count => 2,
        log_entries => [qw/edit edit/],
    },
    {
        desc => 'edit user council',
        fields => {
            name => 'Changed User',
            email => 'changed@example.com',
            council => 2509,
            flagged => undef,
        },
        changes => {
            council => 2607,
        },
        log_count => 3,
        log_entries => [qw/edit edit edit/],
    },
    {
        desc => 'edit user flagged',
        fields => {
            name => 'Changed User',
            email => 'changed@example.com',
            council => 2607,
            flagged => undef,
        },
        changes => {
            flagged => 'on',
        },
        log_count => 4,
        log_entries => [qw/edit edit edit edit/],
    },
    {
        desc => 'edit user remove flagged',
        fields => {
            name => 'Changed User',
            email => 'changed@example.com',
            council => 2607,
            flagged => 'on',
        },
        changes => {
            flagged => undef,
        },
        log_count => 4,
        log_entries => [qw/edit edit edit edit/],
    },
) {
    subtest $test->{desc} => sub {
        $mech->get_ok( '/admin/user_edit/' . $user->id );

        my $visible = $mech->visible_form_values;
        is_deeply $visible, $test->{fields}, 'expected user';

        my $expected = {
            %{ $test->{fields} },
            %{ $test->{changes} }
        };

        $mech->submit_form_ok( { with_fields => $expected } );

        $visible = $mech->visible_form_values;
        is_deeply $visible, $expected, 'user updated';

        $mech->content_contains( 'Updated!' );
    };
}

$mech->delete_user( $user );
$mech->delete_user( $user2 );
$mech->delete_user( $user3 );
$mech->delete_user( 'test4@example.com' );

done_testing();
