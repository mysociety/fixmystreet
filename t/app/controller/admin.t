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
    my $problems = FixMyStreet::App->model('DB::Problem')->search( { state => { -in => [qw/confirmed fixed/] } } );

    my $problem_count = $problems->count;
    $problems->update( { cobrand => '' } );

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

    $mech->content_contains( "0</strong> live problems" );
    $mech->content_contains( "0 confirmed alerts" );
    $mech->content_contains( "0 questionnaires sent" );

    $report->council(2489);
    $report->cobrand('barnet');
    $report->update;

    $alert->cobrand('barnet');
    $alert->update;

    $mech->get_ok('/admin');

    $mech->content_contains( "1</strong> live problems" );
    $mech->content_contains( "1 confirmed alerts" );
    $mech->content_contains( "1 questionnaires sent" );

    $report->council(2504);
    $report->cobrand('');
    $report->update;

    $alert->cobrand('');
    $alert->update;

    ok $mech->host('fixmystreet.com');
};

my $host = FixMyStreet->config('BASE_URL');
$mech->get_ok('/admin/council_contacts/2650');
$mech->content_contains('Aberdeen City Council');
$mech->content_contains('AB15 8RN');
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
        description => 'edit report user email',
        fields => {
            title  => 'Edited Report',
            detail => 'Edited Detail',
            state  => 'confirmed',
            name   => 'Edited User',
            email  => $user->email,
            anonymous => 0,
        },
        changes => {
            email => $user2->email,
        },
        log_count => 4,
        log_entries => [ qw/edit edit edit edit/ ],
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
        },
        changes => {
            state => 'unconfirmed'
        },
        log_count => 5,
        log_entries => [ qw/state_change edit edit edit edit/ ],
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
        },
        changes => {
            state => 'confirmed'
        },
        log_count => 6,
        log_entries => [ qw/state_change state_change edit edit edit edit/ ],
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
        },
        changes => {
            state => 'fixed'
        },
        log_count => 7,
        log_entries => [ qw/state_change state_change state_change edit edit edit edit/ ],
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
        },
        changes => {
            state => 'hidden'
        },
        log_count => 8,
        log_entries => [ qw/state_change state_change state_change state_change edit edit edit edit/ ],
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
        },
        changes => {
            state => 'confirmed',
            anonymous => 1,
        },
        log_count => 10,
        log_entries => [ qw/edit state_change state_change state_change state_change state_change edit edit edit edit/ ],
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
        },
        changes => {
        },
        log_count => 11,
        log_entries => [ qw/resend edit state_change state_change state_change state_change state_change edit edit edit edit/ ],
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
            state => 'hidden',
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

        if ( $test->{user} ) {
            is $update->user->id, $test->{user}->id, 'update user';
        }
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
};

$mech->delete_user( $user );
$mech->delete_user( $user2 );
$mech->delete_user( $user3 );
$mech->delete_user( 'test4@example.com' );

done_testing();
