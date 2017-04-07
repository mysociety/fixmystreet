use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $user2 = $mech->create_user_ok('test2@example.com', name => 'Test User 2');

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council', id => 2237);
my $oxfordshirecontact = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Traffic lights', email => 'lights@example.com' );
my $oxfordshireuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxfordshire);

my $oxford = $mech->create_body_ok(2421, 'Oxford City Council');
$mech->create_contact_ok( body_id => $oxford->id, category => 'Graffiti', email => 'graffiti@example.net' );

my $bromley = $mech->create_body_ok(2482, 'Bromley Council', id => 2482);

my $user3 = $mech->create_user_ok('test3@example.com', name => 'Test User 2');

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

my $alert = FixMyStreet::App->model('DB::Alert')->find_or_create(
    {
        alert_type => 'area_problems',
        parameter => 2482,
        confirmed => 1,
        user => $user,
    },
);

$mech->log_in_ok( $superuser->email );

subtest 'check summary counts' => sub {
    my $problems = FixMyStreet::App->model('DB::Problem')->search( { state => { -in => [qw/confirmed fixed closed investigating planned/, 'in progress', 'fixed - user', 'fixed - council'] } } );

    ok $mech->host('www.fixmystreet.com');

    my $problem_count = $problems->count;
    $problems->update( { cobrand => '' } );

    FixMyStreet::App->model('DB::Problem')->search( { bodies_str => 2489 } )->update( { bodies_str => 1 } );

    my $q = FixMyStreet::App->model('DB::Questionnaire')->find_or_new( { problem => $report, });
    $q->whensent( \'current_timestamp' );
    $q->in_storage ? $q->update : $q->insert;

    my $alerts =  FixMyStreet::App->model('DB::Alert')->search( { confirmed => { '>' => 0 } } );
    my $a_count = $alerts->count;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
    }, sub {
        $mech->get_ok('/admin');
    };

    $mech->title_like(qr/Summary/);

    $mech->content_contains( "$problem_count</strong> live problems" );
    $mech->content_contains( "$a_count confirmed alerts" );

    my $questionnaires = FixMyStreet::App->model('DB::Questionnaire')->search( { whensent => { -not => undef } } );
    my $q_count = $questionnaires->count();

    $mech->content_contains( "$q_count questionnaires sent" );

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        ok $mech->host('oxfordshire.fixmystreet.com');

        $mech->get_ok('/admin');
        $mech->title_like(qr/Summary/);

        my ($num_live) = $mech->content =~ /(\d+)<\/strong> live problems/;
        my ($num_alerts) = $mech->content =~ /(\d+) confirmed alerts/;
        my ($num_qs) = $mech->content =~ /(\d+) questionnaires sent/;

        $report->bodies_str(2237);
        $report->cobrand('oxfordshire');
        $report->update;

        $alert->cobrand('oxfordshire');
        $alert->update;

        $mech->get_ok('/admin');

        $mech->content_contains( ($num_live+1) . "</strong> live problems" );
        $mech->content_contains( ($num_alerts+1) . " confirmed alerts" );
        $mech->content_contains( ($num_qs+1) . " questionnaires sent" );

        $report->bodies_str(2504);
        $report->cobrand('');
        $report->update;

        $alert->cobrand('');
        $alert->update;
    };

    FixMyStreet::App->model('DB::Problem')->search( { bodies_str => 1 } )->update( { bodies_str => 2489 } );
    ok $mech->host('www.fixmystreet.com');
};

# This override is wrapped around ALL the /admin/body tests
FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    MAPIT_TYPES => [ 'UTA' ],
    BASE_URL => 'http://www.example.org',
}, sub {

my $body = $mech->create_body_ok(2650, 'Aberdeen City Council');
$mech->get_ok('/admin/body/' . $body->id);
$mech->content_contains('Aberdeen City Council');
$mech->content_like(qr{AB\d\d});
$mech->content_contains("http://www.example.org/around");

subtest 'check contact creation' => sub {
    my $contact = FixMyStreet::App->model('DB::Contact')->search(
        { body_id => $body->id, category => [ 'test category', 'test/category' ] }
    );
    $contact->delete_all;

    my $history = FixMyStreet::App->model('DB::ContactsHistory')->search(
        { body_id => $body->id, category => [ 'test category', 'test/category' ] }
    );
    $history->delete_all;

    $mech->get_ok('/admin/body/' . $body->id);

    $mech->submit_form_ok( { with_fields => { 
        category   => 'test category',
        email      => 'test@example.com',
        note       => 'test note',
        non_public => undef,
        confirmed  => 0,
    } } );

    $mech->content_contains( 'test category' );
    $mech->content_contains( 'test@example.com' );
    $mech->content_contains( '<td>test note' );
    $mech->content_contains( 'Private:&nbsp;No' );

    $mech->submit_form_ok( { with_fields => { 
        category   => 'private category',
        email      => 'test@example.com',
        note       => 'test note',
        non_public => 'on',
    } } );

    $mech->content_contains( 'private category' );
    $mech->content_contains( 'Private:&nbsp;Yes' );

    $mech->submit_form_ok( { with_fields => {
        category => 'test/category',
        email    => 'test@example.com',
        note     => 'test/note',
        non_public => 'on',
    } } );
    $mech->get_ok('/admin/body/' . $body->id . '/test/category');

};

subtest 'check contact editing' => sub {
    $mech->get_ok('/admin/body/' . $body->id .'/test%20category');

    $mech->submit_form_ok( { with_fields => {
        email    => 'test2@example.com',
        note     => 'test2 note',
        non_public => undef,
    } } );

    $mech->content_contains( 'test category' );
    $mech->content_contains( 'test2@example.com' );
    $mech->content_contains( '<td>test2 note' );
    $mech->content_contains( 'Private:&nbsp;No' );

    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        email    => 'test2@example.com, test3@example.com',
        note     => 'test3 note',
    } } );

    $mech->content_contains( 'test2@example.com,test3@example.com' );

    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->content_contains( '<td><strong>test2@example.com,test3@example.com' );

    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        email    => 'test2@example.com',
        note     => 'test2 note',
        non_public => 'on',
    } } );

    $mech->content_contains( 'Private:&nbsp;Yes' );

    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->content_contains( '<td><strong>test2@example.com' );
};

subtest 'check contact updating' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->content_like(qr{test2\@example.com</strong>[^<]*</td>[^<]*<td>No}s);

    $mech->get_ok('/admin/body/' . $body->id);

    $mech->form_number( 1 );
    $mech->tick( 'confirmed', 'test category' );
    $mech->submit_form_ok({form_number => 1});

    $mech->content_like(qr'test2@example.com</td>[^<]*<td>\s*Confirmed:&nbsp;Yes's);
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->content_like(qr{test2\@example.com[^<]*</td>[^<]*<td><strong>Yes}s);
};

$body->update({ send_method => undef }); 

subtest 'check open311 configuring' => sub {
    $mech->get_ok('/admin/body/' . $body->id);
    $mech->content_lacks('Council contacts configured via Open311');

    $mech->form_number(3);
    $mech->submit_form_ok(
        {
            with_fields => {
                api_key      => 'api key',
                endpoint     => 'http://example.com/open311',
                jurisdiction => 'mySociety',
                send_comments => 0,
                send_method  => 'Open311',
            }
        }
    );
    $mech->content_contains('Council contacts configured via Open311');
    $mech->content_contains('Values updated');

    my $conf = FixMyStreet::App->model('DB::Body')->find( $body->id );
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
                send_comments => 0,
                send_method  => 'Open311',
            }
        }
    );

    $mech->content_contains('Values updated');

    $conf = FixMyStreet::App->model('DB::Body')->find( $body->id );
    is $conf->endpoint, 'http://example.org/open311', 'endpoint updated';
    is $conf->api_key, 'new api key', 'api key updated';
    is $conf->jurisdiction, 'open311', 'jurisdiction configures';
};

subtest 'check text output' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '?text=1');
    is $mech->content_type, 'text/plain';
    $mech->content_contains('test category');
};


}; # END of override wrap


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
        fields      => {
            title      => 'Report to Edit',
            detail     => 'Detail for Report to Edit',
            state      => 'confirmed',
            name       => 'Test User',
            email      => $user->email,
            anonymous  => 0,
            flagged    => undef,
            non_public => undef,
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
            email      => $user->email,
            anonymous  => 0,
            flagged    => undef,
            non_public => undef,
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
            email      => $user->email,
            anonymous  => 0,
            flagged    => undef,
            non_public => undef,
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
            email      => $user->email,
            anonymous  => 0,
            flagged    => undef,
            non_public => undef,
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
            email      => $user->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
        },
        changes     => { email => $user2->email, },
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
            email      => $user2->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
        },
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
            email      => $user2->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
        },
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
            email      => $user2->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
        },
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
            email      => $user2->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
        },
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
            email      => $user2->email,
            anonymous  => 0,
            flagged    => 'on',
            non_public => undef,
        },
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
            email      => $user2->email,
            anonymous  => 1,
            flagged    => 'on',
            non_public => undef,
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
            email      => $user2->email,
            anonymous  => 1,
            flagged    => 'on',
            non_public => undef,
        },
        changes     => {
            non_public => 'on',
        },
        log_entries => [
            qw/edit resend edit state_change edit state_change edit state_change edit state_change edit state_change edit edit edit edit edit/
        ],
        resend => 0,
    },
  )
{
    subtest $test->{description} => sub {
        $log_entries->reset;
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

        $test->{changes}->{flagged} = 1 if $test->{changes}->{flagged};
        $test->{changes}->{non_public} = 1 if $test->{changes}->{non_public};

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
        email  => $report->user->email,
        category => 'Other',
        anonymous => 1,
        flagged => 'on',
        non_public => 'on',
        external_id => '13',
        external_body => '',
        external_team => '',
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

    $report->state('fixed - user');
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

    $mech->get_ok('/admin/reports');
    $mech->get_ok('/admin/reports?search=' . $report->id );

    $mech->content_contains( $report->title );
    my $r_id = $report->id;
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id"[^>]*>$r_id</a>} );

    $mech->get_ok('/admin/reports?search=' . $report->external_id);
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id"[^>]*>$r_id</a>} );

    $mech->get_ok('/admin/reports?search=ref:' . $report->external_id);
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id"[^>]*>$r_id</a>} );

    $mech->get_ok('/admin/reports?search=' . $report->user->email);

    my $u_id = $update->id;
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id"[^>]*>$r_id</a>} );
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id#update_$u_id"[^>]*>$u_id</a>} );

    $update->state('hidden');
    $update->update;

    $mech->get_ok('/admin/reports?search=' . $report->user->email);
    $mech->content_like( qr{<tr [^>]*hidden[^>]*> \s* <td> \s* $u_id \s* </td>}xs );

    $report->state('hidden');
    $report->update;

    $mech->get_ok('/admin/reports?search=' . $report->user->email);
    $mech->content_like( qr{<tr [^>]*hidden[^>]*> \s* <td[^>]*> \s* $r_id \s* </td>}xs );

    $report->state('fixed - user');
    $report->update;

    $mech->get_ok('/admin/reports?search=' . $report->user->email);
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id"[^>]*>$r_id</a>} );
};

subtest 'search abuse' => sub {
    $mech->get_ok( '/admin/users?search=example' );
    $mech->content_like(qr{test4\@example.com.*</td>\s*<td>.*?</td>\s*<td>\(Email in abuse table}s);
};

subtest 'show flagged entries' => sub {
    $report->flagged( 1 );
    $report->update;

    $user->flagged( 1 );
    $user->update;

    $mech->get_ok('/admin/flagged');
    $mech->content_contains( $report->title );
    $mech->content_contains( $user->email );
};

my $haringey = $mech->create_body_ok(2509, 'Haringey Borough Council');

subtest 'user search' => sub {
    $mech->get_ok('/admin/users');
    $mech->get_ok('/admin/users?search=' . $user->name);

    $mech->content_contains( $user->name);
    my $u_id = $user->id;
    $mech->content_like( qr{user_edit/$u_id">Edit</a>} );

    $mech->get_ok('/admin/users?search=' . $user->email);

    $mech->content_like( qr{user_edit/$u_id">Edit</a>} );

    $user->from_body($haringey->id);
    $user->update;
    $mech->get_ok('/admin/users?search=' . $haringey->id );
    $mech->content_contains('Haringey');
};

subtest 'search does not show user from another council' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $mech->get_ok('/admin/users');
        $mech->get_ok('/admin/users?search=' . $user->name);

        $mech->content_contains( "Searching found no users." );

        $mech->get_ok('/admin/users?search=' . $user->email);
        $mech->content_contains( "Searching found no users." );
    };
};

subtest 'user_edit does not show user from another council' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $mech->get('/admin/user_edit/' . $user->id);
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
    };
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

my $southend = $mech->create_body_ok(2607, 'Southend-on-Sea Borough Council');

my %default_perms = (
    "permissions[moderate]" => undef,
    "permissions[planned_reports]" => undef,
    "permissions[report_edit]" => undef,
    "permissions[report_edit_category]" => undef,
    "permissions[report_edit_priority]" => undef,
    "permissions[report_inspect]" => undef,
    "permissions[report_instruct]" => undef,
    "permissions[contribute_as_another_user]" => undef,
    "permissions[contribute_as_body]" => undef,
    "permissions[view_body_contribute_details]" => undef,
    "permissions[user_edit]" => undef,
    "permissions[user_manage_permissions]" => undef,
    "permissions[user_assign_body]" => undef,
    "permissions[user_assign_areas]" => undef,
    "permissions[template_edit]" => undef,
    "permissions[responsepriority_edit]" => undef,
    "permissions[category_edit]" => undef,
    trusted_bodies => undef,
);

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    for my $test (
        {
            desc => 'edit user name',
            fields => {
                name => 'Test User',
                email => 'test@example.com',
                body => $haringey->id,
                phone => '',
                flagged => undef,
                is_superuser => undef,
                area_id => '',
                %default_perms,
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
                body => $haringey->id,
                phone => '',
                flagged => undef,
                is_superuser => undef,
                area_id => '',
                %default_perms,
            },
            changes => {
                email => 'changed@example.com',
            },
            log_count => 2,
            log_entries => [qw/edit edit/],
        },
        {
            desc => 'edit user body',
            fields => {
                name => 'Changed User',
                email => 'changed@example.com',
                body => $haringey->id,
                phone => '',
                flagged => undef,
                is_superuser => undef,
                area_id => '',
                %default_perms,
            },
            changes => {
                body => $southend->id,
            },
            log_count => 3,
            log_entries => [qw/edit edit edit/],
        },
        {
            desc => 'edit user flagged',
            fields => {
                name => 'Changed User',
                email => 'changed@example.com',
                body => $southend->id,
                phone => '',
                flagged => undef,
                is_superuser => undef,
                area_id => '',
                %default_perms,
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
                body => $southend->id,
                phone => '',
                flagged => 'on',
                is_superuser => undef,
                area_id => '',
                %default_perms,
            },
            changes => {
                flagged => undef,
            },
            log_count => 4,
            log_entries => [qw/edit edit edit edit/],
        },
        {
            desc => 'edit user add is_superuser',
            fields => {
                name => 'Changed User',
                email => 'changed@example.com',
                body => $southend->id,
                phone => '',
                flagged => undef,
                is_superuser => undef,
                area_id => '',
                %default_perms,
            },
            changes => {
                is_superuser => 'on',
            },
            removed => [
                keys %default_perms,
            ],
            log_count => 5,
            log_entries => [qw/edit edit edit edit edit/],
        },
        {
            desc => 'edit user remove is_superuser',
            fields => {
                name => 'Changed User',
                email => 'changed@example.com',
                body => $southend->id,
                phone => '',
                flagged => undef,
                is_superuser => 'on',
                area_id => '',
            },
            changes => {
                is_superuser => undef,
            },
            added => {
                %default_perms,
            },
            log_count => 5,
            log_entries => [qw/edit edit edit edit edit/],
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

            # Some actions cause visible fields to be added/removed
            foreach my $x (@{ $test->{removed} }) {
                delete $expected->{$x};
            }
            if ( $test->{added} ) {
                $expected = {
                    %$expected,
                    %{ $test->{added} }
                };
            }

            $visible = $mech->visible_form_values;
            is_deeply $visible, $expected, 'user updated';

            $mech->content_contains( 'Updated!' );
        };
    }
};

subtest "Test setting a report from unconfirmed to something else doesn't cause a front end error" => sub {
    $report->update( { confirmed => undef, state => 'unconfirmed', non_public => 0 } );
    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->submit_form_ok( { with_fields => { state => 'investigating' } } );
    $report->discard_changes;
    ok( $report->confirmed, 'report has a confirmed timestamp' );
    $mech->get_ok("/report/$report_id");
};

subtest "Check admin_base_url" => sub {
    my $rs = FixMyStreet::App->model('DB::Problem');
    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($report->cobrand)->new();

    is ($report->admin_url($cobrand),
        (sprintf 'http://www.example.org/admin/report_edit/%d', $report_id),
        'get_admin_url OK');
};

# Finished with the superuser tests
$mech->log_out_ok;

subtest "Users without from_body can't access admin" => sub {
    $user->from_body( undef );
    $user->update;

    $mech->log_in_ok( $user->email );

    ok $mech->get('/admin');
    is $mech->res->code, 403, "got 403";

    $mech->log_out_ok;
};

subtest "Users with from_body can access their own council's admin" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $mech->log_in_ok( $oxfordshireuser->email );

        $mech->get_ok('/admin');
        $mech->content_contains( 'FixMyStreet admin:' );

        $mech->log_out_ok;
    };
};

subtest "Users with from_body can't access another council's admin" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'bristol' ],
    }, sub {
        $mech->log_in_ok( $oxfordshireuser->email );

        ok $mech->get('/admin');
        is $mech->res->code, 403, "got 403";

        $mech->log_out_ok;
    };
};

subtest "Users with from_body can't access fixmystreet.com admin" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
    }, sub {
        $mech->log_in_ok( $oxfordshireuser->email );

        ok $mech->get('/admin');
        is $mech->res->code, 403, "got 403";

        $mech->log_out_ok;
    };
};

subtest "response templates can be added" => sub {
    is $oxfordshire->response_templates->count, 0, "No response templates yet";
    $mech->log_in_ok( $superuser->email );
    $mech->get_ok( "/admin/templates/" . $oxfordshire->id . "/new" );

    my $fields = {
        title => "Report acknowledgement",
        text => "Thank you for your report. We will respond shortly.",
        auto_response => undef,
        "contacts[".$oxfordshirecontact->id."]" => 1,
    };
    $mech->submit_form_ok( { with_fields => $fields } );

     is $oxfordshire->response_templates->count, 1, "Response template was added";
};

subtest "response templates are included on page" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $report->update({ category => $oxfordshirecontact->category, bodies_str => $oxfordshire->id });
        $mech->log_in_ok( $oxfordshireuser->email );

        $mech->get_ok("/report/" . $report->id);
        $mech->content_contains( $oxfordshire->response_templates->first->text );

        $mech->log_out_ok;
    };
};

$mech->log_in_ok( $superuser->email );

subtest "response priorities can be added" => sub {
    is $oxfordshire->response_priorities->count, 0, "No response priorities yet";
    $mech->get_ok( "/admin/responsepriorities/" . $oxfordshire->id . "/new" );

    my $fields = {
        name => "Cat 1A",
        description => "Fixed within 24 hours",
        deleted => undef,
        "contacts[".$oxfordshirecontact->id."]" => 1,
    };
    $mech->submit_form_ok( { with_fields => $fields } );

     is $oxfordshire->response_priorities->count, 1, "Response template was added to body";
     is $oxfordshirecontact->response_priorities->count, 1, "Response template was added to contact";
};

subtest "response priorities can be listed" => sub {
    $mech->get_ok( "/admin/responsepriorities/" . $oxfordshire->id );

    $mech->content_contains( $oxfordshire->response_priorities->first->name );
    $mech->content_contains( $oxfordshire->response_priorities->first->description );
};

subtest "response priorities are limited by body" => sub {
    my $bromleypriority = $bromley->response_priorities->create( {
        deleted => 0,
        name => "Bromley Cat 0",
    } );

     is $bromley->response_priorities->count, 1, "Response template was added to Bromley";
     is $oxfordshire->response_priorities->count, 1, "Response template wasn't added to Oxfordshire";

     $mech->get_ok( "/admin/responsepriorities/" . $oxfordshire->id );
     $mech->content_lacks( $bromleypriority->name );

     $mech->get_ok( "/admin/responsepriorities/" . $bromley->id );
     $mech->content_contains( $bromleypriority->name );
};

$mech->log_out_ok;

subtest "response priorities can't be viewed across councils" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $oxfordshireuser->user_body_permissions->create({
            body => $oxfordshire,
            permission_type => 'responsepriority_edit',
        });
        $mech->log_in_ok( $oxfordshireuser->email );
        $mech->get_ok( "/admin/responsepriorities/" . $oxfordshire->id );
        $mech->content_contains( $oxfordshire->response_priorities->first->name );


        $mech->get( "/admin/responsepriorities/" . $bromley->id );
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";

        my $bromley_priority_id = $bromley->response_priorities->first->id;
        $mech->get( "/admin/responsepriorities/" . $bromley->id . "/" . $bromley_priority_id );
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
    };
};

END {
    $mech->delete_user( $user );
    $mech->delete_user( $user2 );
    $mech->delete_user( $user3 );
    $mech->delete_user( $superuser );
    $mech->delete_user( 'test4@example.com' );
    $mech->delete_body( $oxfordshire );
    $mech->delete_body( $oxford );
    $mech->delete_body( $bromley );
    $mech->delete_body( $westminster );
    done_testing();
}
