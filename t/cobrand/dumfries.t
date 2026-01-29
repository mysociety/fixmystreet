use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

use DateTime;
use FixMyStreet::TestMech;
use Catalyst::Test 'FixMyStreet::App';
use Test::More;
use Test::MockTime qw(:all);
use FixMyStreet::Cobrand::Dumfries;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

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
    subtest 'updates_disallowed - state not closed' => sub {
        $problem->update({
            state => 'confirmed',
            lastupdate => \"'2020-01-01 00:00:00'",
        });
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when state is not a closed state';
    };

    subtest 'updates_disallowed - no latest_inspection_time set' => sub {
        my $old = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'planned',
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
            state => 'planned',
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

    subtest 'updates_disallowed - closed state, inspection time less than 14 days' => sub {
        my $recent_inspection = DateTime->now->subtract(days => 10)->strftime('%Y-%m-%dT%H:%M:%S');
        my $old = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'closed',
            lastupdate => \"'$old'",
        });
        $problem->set_extra_metadata(latest_inspection_time => $recent_inspection);
        $problem->update;
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when less than 14 days have passed since inspection (closed state)';
    };

    subtest 'updates allowed - reporter on closed report with old inspection' => sub {
        my $old_inspection = DateTime->now->subtract(days => 15)->strftime('%Y-%m-%dT%H:%M:%S');
        my $old = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'duplicate',
            lastupdate => \"'$old'",
        });
        $problem->set_extra_metadata(latest_inspection_time => $old_inspection);
        $problem->update;
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, '',
            'Updates allowed when reporter updates their own report (duplicate, 14+ days since inspection)';
    };

    subtest 'updates allowed - staff on closed report with old inspection' => sub {
        my $old_inspection = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%dT%H:%M:%S');
        my $old = DateTime->now->subtract(days => 25)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'closed',
            lastupdate => \"'$old'",
        });
        $problem->set_extra_metadata(latest_inspection_time => $old_inspection);
        $problem->update;
        $problem->discard_changes;
        $c->user($staff_user);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, '',
            'Updates allowed when staff updates report (closed, 14+ days since inspection)';
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

    subtest 'uses Scotland bank holidays' => sub {
        use Test::MockModule;
        my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UK');
        $ukc->mock('_get_bank_holiday_json', sub {
            {
                "england-and-wales" => {
                    "events" => [
                        { "date" => "2024-08-26", "title" => "Summer bank holiday" }
                    ]
                },
                "scotland" => {
                    "events" => [
                        { "date" => "2024-01-02", "title" => "2nd January" },
                        { "date" => "2024-08-05", "title" => "Summer bank holiday" }
                    ]
                }
            }
        });

        my $cobrand = FixMyStreet::Cobrand::Dumfries->new;
        my $holidays = $cobrand->public_holidays();

        is_deeply $holidays, ['2024-01-02', '2024-08-05'], 'Dumfries uses Scotland bank holidays';
    };

    subtest 'latest_inspection_time stored on problem from update' => sub {
        my $comment = FixMyStreet::DB->resultset('Comment')->new({
            problem_id => $problem->id,
            user_id    => $staff_user->id,
            text       => 'Test update',
            state      => 'confirmed',
            confirmed  => DateTime->now,
        });

        # Mock request with latest_inspection_time in extras
        my $request = {
            extras => {
                latest_inspection_time => '2024-01-15T10:30:00',
            },
        };

        # Call the munging function
        $cobrand->open311_get_update_munging($comment, 'investigating', $request);

        # Check that the problem has the inspection time stored
        $problem->discard_changes;
        is $problem->get_extra_metadata('latest_inspection_time'), '2024-01-15T10:30:00',
            'latest_inspection_time stored on problem from update';

        # Test case where latest_inspection_time is not in extras
        # First clear the metadata from previous test
        $problem->unset_extra_metadata('latest_inspection_time');
        $problem->update;

        my $comment2 = FixMyStreet::DB->resultset('Comment')->new({
            problem_id => $problem->id,
            user_id    => $staff_user->id,
            text       => 'Test update without inspection time',
            state      => 'confirmed',
            confirmed  => DateTime->now,
        });

        # Mock request without latest_inspection_time
        my $request2 = {
            extras => {},
        };

        # Call the munging function - should not fail
        $cobrand->open311_get_update_munging($comment2, 'investigating', $request2);

        # Check that the problem doesn't have the inspection time
        $problem->discard_changes;
        is $problem->get_extra_metadata('latest_inspection_time'), undef,
            'No inspection time stored when not in extras';

        # Test case where latest_inspection_time is 'NOT COMPLETE' - should unset the metadata
        # First set an inspection time
        $problem->set_extra_metadata(latest_inspection_time => '2024-01-10T09:00:00');
        $problem->update;

        my $comment3 = FixMyStreet::DB->resultset('Comment')->new({
            problem_id => $problem->id,
            user_id    => $staff_user->id,
            text       => 'Test update with NOT COMPLETE',
            state      => 'confirmed',
            confirmed  => DateTime->now,
        });

        # Mock request with 'NOT COMPLETE'
        my $request3 = {
            extras => {
                latest_inspection_time => 'NOT COMPLETE',
            },
        };

        # Call the munging function - should unset the metadata
        $cobrand->open311_get_update_munging($comment3, 'investigating', $request3);

        # Check that the inspection time has been removed
        $problem->discard_changes;
        is $problem->get_extra_metadata('latest_inspection_time'), undef,
            'Inspection time unset when value is NOT COMPLETE';
    };

    subtest 'out-of-hours functionality uses Scotland bank holidays' => sub {
        use Test::MockModule;
        use Time::Piece;
        my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UK');
        $ukc->mock('_get_bank_holiday_json', sub {
            {
                "england-and-wales" => {
                    "events" => [
                        { "date" => "2024-08-26", "title" => "Summer bank holiday" }
                    ]
                },
                "scotland" => {
                    "events" => [
                        { "date" => "2024-01-02", "title" => "2nd January" },
                        { "date" => "2024-08-05", "title" => "Summer bank holiday" }
                    ]
                }
            }
        });

        my $cobrand = FixMyStreet::Cobrand::Dumfries->new;
        my $ooh = $cobrand->ooh_times($body);

        # Verify Scotland holidays are passed to OutOfHours object
        is_deeply [sort @{$ooh->holidays}], ['2024-01-02', '2024-08-05'],
            'OutOfHours object receives Scotland bank holidays';

        # Test holiday detection
        my $scotland_holiday = Time::Piece->strptime('2024-01-02', '%Y-%m-%d');
        is $ooh->is_public_holiday($scotland_holiday), 1,
            'Scottish 2nd January recognized as public holiday';

        my $england_holiday = Time::Piece->strptime('2024-08-26', '%Y-%m-%d');
        is $ooh->is_public_holiday($england_holiday), 0,
            'England/Wales-only Summer bank holiday not recognized';

        my $scotland_summer = Time::Piece->strptime('2024-08-05', '%Y-%m-%d');
        is $ooh->is_public_holiday($scotland_summer), 1,
            'Scottish Summer bank holiday recognized';
    };
};

$problem->delete;

done_testing();
