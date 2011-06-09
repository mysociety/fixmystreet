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

$mech->get_ok('/admin');
$mech->title_like(qr/Summary/);

$mech->get_ok('/admin/council_contacts/2650');
$mech->content_contains('Aberdeen City Council');
$mech->content_contains('AB15 8RN');

subtest 'check contact creation' => sub {
    my $contact = FixMyStreet::App->model('DB::Contact')->find(
        { area_id => 2650, category => 'test category' }
    );

    $contact->delete if $contact;

    my $history = FixMyStreet::App->model('DB::ContactsHistory')->search(
        { area_id => 2650, category => 'test category' }
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
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.5016605453401',
        longitude          => '-0.142497580865087',
        user_id            => $user->id,
        whensent           => $dt->ymd . ' ' . $dt->hms,
    }
);

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

$mech->delete_user( $user );
$mech->delete_user( $user2 );
$mech->delete_user( $user3 );

done_testing();
