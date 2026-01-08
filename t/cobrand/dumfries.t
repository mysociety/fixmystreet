use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

use DateTime;
use FixMyStreet::TestMech;
use Catalyst::Test 'FixMyStreet::App';
use Test::More;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

use_ok 'FixMyStreet::Cobrand::Dumfries';

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'dumfries' ],
    COBRAND_FEATURES => {
        contact_us_phone => {
            dumfries => '1234567',
        },
    }
}, sub {

        subtest 'Front page has correct wording' => sub {
            $mech->get_ok("/");
            $mech->content_contains("<h1>Report, view local roads and lighting problems</h1>");
            $mech->content_contains("(like potholes, blocked drains, broken paving, or street lighting)");
        };

        subtest 'faq contains contact_us_phone substitutions' => sub {
            $mech->get_ok("/faq");
            ok $mech->text =~ "For these types of issue, please call us on: 1234567", 'contact_us_phone sentence reads correctly';
        };

        subtest 'Privacy contains contact_us_phone substitutions' => sub {
            $mech->get_ok("/about/privacy");
            ok $mech->text =~ "Please call us on: 1234567 if you would like your details to be removed from our admin database sooner than that", 'contact_us_phone sentence reads correctly';
            ok $mech->text =~ "To exercise your right to object, you can call us on: 123456", 'contact_us_phone sentence reads correctly';
        };

    };


my $body = $mech->create_body_ok(2656, 'Dumfries and Galloway Council', {
    cobrand => 'dumfries'
});

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Potholes',
    email => 'potholes@dumgal.gov.uk'
);

my $reporter = $mech->create_user_ok('reporter@example.com', name => 'Reporter');
my $staff_user = $mech->create_user_ok('staff@dumgal.gov.uk', name => 'Staff User', from_body => $body);
my $other_user = $mech->create_user_ok('other@example.com', name => 'Other User');

# Create problem once and reuse it
my $problem = FixMyStreet::DB->resultset('Problem')->create({
    postcode           => 'DG1 1AA',
    bodies_str         => $body->id,
    areas              => ',2656,',
    category           => 'Potholes',
    title              => 'Test problem',
    detail             => 'Test detail',
    used_map           => 1,
    name               => 'Reporter',
    anonymous          => 0,
    state              => 'confirmed',
    confirmed          => DateTime->now,
    lastupdate         => DateTime->now->subtract(days => 20),
    latitude           => 55.0706,
    longitude          => -3.9568,
    user_id            => $reporter->id,
    cobrand            => 'dumfries',
});

# Create context and cobrand once
my ($res, $c) = ctx_request('/');
my $cobrand = FixMyStreet::Cobrand::Dumfries->new({ c => $c });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['dumfries'],
}, sub {
    subtest 'updates_disallowed - state not open' => sub {
        $problem->update({
            state => 'closed',
            lastupdate => \"'2020-01-01 00:00:00'",
        });
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when state is not an open state';
    };

    subtest 'updates_disallowed - no latest_inspection_time set' => sub {
        my $old = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'confirmed',
            lastupdate => \"'$old'",
        });
        $problem->unset_extra_metadata('latest_inspection_time');
        $problem->update;
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when no latest_inspection_time is set';
    };

    subtest 'updates_disallowed - latest_inspection_time less than 14 days ago' => sub {
        my $recent_inspection = DateTime->now->subtract(days => 7)->strftime('%Y-%m-%dT%H:%M:%S');
        my $old = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'confirmed',
            lastupdate => \"'$old'",
        });
        $problem->set_extra_metadata(latest_inspection_time => $recent_inspection);
        $problem->update;
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when less than 14 days have passed since inspection';
    };

    subtest 'updates_disallowed - open state, inspection time less than 14 days' => sub {
        my $recent_inspection = DateTime->now->subtract(days => 10)->strftime('%Y-%m-%dT%H:%M:%S');
        my $old = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'confirmed',
            lastupdate => \"'$old'",
        });
        $problem->set_extra_metadata(latest_inspection_time => $recent_inspection);
        $problem->update;
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when less than 14 days have passed since inspection (open state)';
    };

    subtest 'updates allowed - reporter on open report with old inspection' => sub {
        my $old_inspection = DateTime->now->subtract(days => 15)->strftime('%Y-%m-%dT%H:%M:%S');
        my $old = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'investigating',
            lastupdate => \"'$old'",
        });
        $problem->set_extra_metadata(latest_inspection_time => $old_inspection);
        $problem->update;
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, '',
            'Updates allowed when reporter updates their own report (investigating, 14+ days since inspection)';
    };

    subtest 'updates disallowed - staff on open report with old inspection' => sub {
        my $old_inspection = DateTime->now->subtract(days => 15)->strftime('%Y-%m-%dT%H:%M:%S');
        my $old = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'investigating',
            lastupdate => \"'$old'",
        });
        $problem->set_extra_metadata(latest_inspection_time => $old_inspection);
        $problem->update;
        $problem->discard_changes;
        $c->user($staff_user);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when staff tries to update open report (investigating, 14+ days since inspection)';
    };

    subtest 'updates disallowed - other user on closed report with old inspection' => sub {
        my $old_inspection = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%dT%H:%M:%S');
        my $old = DateTime->now->subtract(days => 25)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'duplicate',
            lastupdate => \"'$old'",
        });
        $problem->set_extra_metadata(latest_inspection_time => $old_inspection);
        $problem->update;
        $problem->discard_changes;
        $c->user($other_user);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when other user (not staff/reporter) tries to update';
    };

    subtest 'updates disallowed - not logged in user' => sub {
        my $old_inspection = DateTime->now->subtract(days => 15)->strftime('%Y-%m-%dT%H:%M:%S');
        my $old = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'closed',
            lastupdate => \"'$old'",
        });
        $problem->set_extra_metadata(latest_inspection_time => $old_inspection);
        $problem->update;
        $problem->discard_changes;
        $c->user(undef);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when not logged in';
    };

    subtest 'latest_inspection_time stored on problem when present in update' => sub {
        my $comment = FixMyStreet::DB->resultset('Comment')->new({
            problem_id => $problem->id,
            user_id    => $staff_user->id,
            text       => 'Test update',
            state      => 'confirmed',
            confirmed  => DateTime->now,
        });

        my $request = {
            extras => {
                latest_inspection_time => '2024-01-15T10:30:00',
            },
        };

        $cobrand->open311_get_update_munging($comment, 'investigating', $request);

        $problem->discard_changes;
        is $problem->get_extra_metadata('latest_inspection_time'), '2024-01-15T10:30:00',
            'latest_inspection_time stored on problem from update';
    };

    subtest 'latest_inspection_time cleared from problem when "NOT COMPLETE" in update' => sub {
        $problem->set_extra_metadata(latest_inspection_time => '2024-01-10T09:00:00');
        $problem->update;

        my $comment = FixMyStreet::DB->resultset('Comment')->new({
            problem_id => $problem->id,
            user_id    => $staff_user->id,
            text       => 'Test update with NOT COMPLETE',
            state      => 'confirmed',
            confirmed  => DateTime->now,
        });

        my $request = {
            extras => {
                latest_inspection_time => 'NOT COMPLETE',
            },
        };

        $cobrand->open311_get_update_munging($comment, 'investigating', $request);

        $problem->discard_changes;
        is $problem->get_extra_metadata('latest_inspection_time'), undef,
            'Inspection time unset when value is NOT COMPLETE';
    };

    subtest 'latest_inspection_time not cleared from problem when absent from update' => sub {
        $problem->set_extra_metadata(latest_inspection_time => '2024-01-10T09:00:00');
        $problem->update;

        my $comment = FixMyStreet::DB->resultset('Comment')->new({
            problem_id => $problem->id,
            user_id    => $staff_user->id,
            text       => 'Test update without inspection time',
            state      => 'confirmed',
            confirmed  => DateTime->now,
        });

        my $request = {
            extras => {},
        };

        $cobrand->open311_get_update_munging($comment, 'investigating', $request);

        $problem->discard_changes;
        is $problem->get_extra_metadata('latest_inspection_time'), '2024-01-10T09:00:00',
            'Inspection time not cleared when not in extras';
    };
};

$problem->delete;

done_testing();
