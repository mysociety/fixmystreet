use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

use DateTime;
use FixMyStreet::TestMech;
use Catalyst::Test 'FixMyStreet::App';
use Test::More;
use Test::MockTime qw(:all);
use FixMyStreet::Cobrand::Dumfries;

my $mech = FixMyStreet::TestMech->new;

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
my $superuser = $mech->create_user_ok('super@example.com', name => 'Superuser', is_superuser => 1);

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

subtest 'expand_external_status_code_for_template_match' => sub {
    my $cobrand = FixMyStreet::Cobrand::Dumfries->new;

    subtest 'three non-empty segments generates all 8 combinations' => sub {
        my $result = $cobrand->expand_external_status_code_for_template_match('aaa:bbb:ccc');
        my @sorted = sort @$result;
        is_deeply \@sorted, [
            '*:*:*',
            '*:*:ccc',
            '*:bbb:*',
            '*:bbb:ccc',
            'aaa:*:*',
            'aaa:*:ccc',
            'aaa:bbb:*',
            'aaa:bbb:ccc',
        ], 'All 8 wildcard combinations generated for 3 non-empty segments';
    };

    subtest 'empty segment stays empty, not replaced with wildcard' => sub {
        my $result = $cobrand->expand_external_status_code_for_template_match('aaa::ccc');
        my @sorted = sort @$result;
        is_deeply \@sorted, [
            '*::*',
            '*::ccc',
            'aaa::*',
            'aaa::ccc',
        ], 'Empty middle segment preserved in all combinations';
    };

    subtest 'trailing empty segment preserved' => sub {
        my $result = $cobrand->expand_external_status_code_for_template_match('aaa:bbb:');
        my @sorted = sort @$result;
        is_deeply \@sorted, [
            '*:*:',
            '*:bbb:',
            'aaa:*:',
            'aaa:bbb:',
        ], 'Trailing empty segment preserved';
    };

    subtest 'all empty segments returns single result' => sub {
        my $result = $cobrand->expand_external_status_code_for_template_match('::');
        is_deeply $result, ['::'], 'All empty segments returns only exact match';
    };

    subtest 'single segment generates two combinations' => sub {
        my $result = $cobrand->expand_external_status_code_for_template_match('abc');
        my @sorted = sort @$result;
        is_deeply \@sorted, ['*', 'abc'], 'Single segment generates exact and wildcard';
    };
};

subtest 'response_template_for with wildcard matching' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['dumfries'],
    }, sub {
        # Create a new problem for these tests
        my $test_problem = FixMyStreet::DB->resultset('Problem')->create({
            postcode           => 'DG1 1AA',
            bodies_str         => $body->id,
            areas              => ',2656,',
            category           => 'Potholes',
            title              => 'Template test problem',
            detail             => 'Test detail',
            used_map           => 1,
            name               => 'Reporter',
            anonymous          => 0,
            state              => 'confirmed',
            confirmed          => DateTime->now,
            lastupdate         => DateTime->now,
            latitude           => 55.0706,
            longitude          => -3.9568,
            user_id            => $reporter->id,
            cobrand            => 'dumfries',
        });

        # Create response templates with various external_status_codes
        my $template_exact = FixMyStreet::DB->resultset('ResponseTemplate')->create({
            body_id => $body->id,
            title => 'Exact Match Template',
            text => 'Exact match response',
            auto_response => 1,
            state => '',
            external_status_code => 'status1:outcome1:priority1',
        });

        my $template_wildcard_one = FixMyStreet::DB->resultset('ResponseTemplate')->create({
            body_id => $body->id,
            title => 'One Wildcard Template',
            text => 'One wildcard response',
            auto_response => 1,
            state => '',
            external_status_code => 'status1:outcome1:*',
        });

        my $template_wildcard_two = FixMyStreet::DB->resultset('ResponseTemplate')->create({
            body_id => $body->id,
            title => 'Two Wildcard Template',
            text => 'Two wildcard response',
            auto_response => 1,
            state => '',
            external_status_code => 'status1:*:*',
        });

        my $template_all_wildcard = FixMyStreet::DB->resultset('ResponseTemplate')->create({
            body_id => $body->id,
            title => 'All Wildcard Template',
            text => 'All wildcard response',
            auto_response => 1,
            state => '',
            external_status_code => '*:*:*',
        });

        my $template_empty_segments = FixMyStreet::DB->resultset('ResponseTemplate')->create({
            body_id => $body->id,
            title => 'Empty Segments Template',
            text => 'Empty segments response',
            auto_response => 1,
            state => '',
            external_status_code => 'status1::',
        });

        subtest 'exact match beats wildcards' => sub {
            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'status1:outcome1:priority1', ''
            );
            is $template->title, 'Exact Match Template',
                'Exact match template selected over wildcards';
        };

        subtest 'more specific wildcard beats less specific' => sub {
            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'status1:outcome1:priorityX', ''
            );
            is $template->title, 'One Wildcard Template',
                'One wildcard template beats two wildcard template';
        };

        subtest 'two wildcards beats three wildcards' => sub {
            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'status1:outcomeX:priorityX', ''
            );
            is $template->title, 'Two Wildcard Template',
                'Two wildcard template beats all wildcard template';
        };

        subtest 'all wildcards matches when nothing more specific' => sub {
            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'statusX:outcomeX:priorityX', ''
            );
            is $template->title, 'All Wildcard Template',
                'All wildcard template matches when no better match';
        };

        subtest 'empty segments do not match wildcards' => sub {
            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'status1::', ''
            );
            is $template->title, 'Empty Segments Template',
                'Empty segments match empty template, not wildcard';
        };

        subtest 'wildcard does not match empty segment' => sub {
            # Delete the empty segments template so it can't match
            $template_empty_segments->delete;

            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'status1::', ''
            );
            is $template, undef,
                'No template matches when segments are empty and no exact match exists';
        };

        subtest 'no match when external_status_code unchanged' => sub {
            $test_problem->set_extra_metadata(external_status_code => 'status1:outcome1:priority1');
            $test_problem->update;

            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'status1:outcome1:priority1', 'status1:outcome1:priority1'
            );
            is $template, undef,
                'No template when external_status_code has not changed';
        };

        # Cleanup
        $template_exact->delete;
        $template_wildcard_one->delete;
        $template_wildcard_two->delete;
        $template_all_wildcard->delete;
        $test_problem->delete;
    };
};

subtest 'admin template external_status_code validation' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['dumfries'],
    }, sub {
        $mech->log_in_ok($superuser->email);

        subtest 'valid external_status_code is accepted' => sub {
            $mech->get_ok('/admin/templates/' . $body->id . '/new');
            $mech->submit_form_ok({
                with_fields => {
                    title => 'Valid Template',
                    text => 'Template text',
                    auto_response => 'on',
                    external_status_code => 'abc:def:ghi',
                }
            });
            # Should redirect on success
            is $mech->uri->path, '/admin/templates/' . $body->id, 'Redirected after valid submission';

            # Cleanup
            $mech->delete_response_template($_) for $body->response_templates->search({ title => 'Valid Template' });
        };

        subtest 'wildcard external_status_code is accepted' => sub {
            $mech->get_ok('/admin/templates/' . $body->id . '/new');
            $mech->submit_form_ok({
                with_fields => {
                    title => 'Wildcard Template',
                    text => 'Template text',
                    auto_response => 'on',
                    external_status_code => 'abc:*:*',
                }
            });
            is $mech->uri->path, '/admin/templates/' . $body->id, 'Redirected after valid wildcard submission';

            $mech->delete_response_template($_) for $body->response_templates->search({ title => 'Wildcard Template' });
        };

        subtest 'invalid segment count is rejected' => sub {
            $mech->get_ok('/admin/templates/' . $body->id . '/new');
            $mech->submit_form_ok({
                with_fields => {
                    title => 'Invalid Template',
                    text => 'Template text',
                    auto_response => 'on',
                    external_status_code => 'abc:def',
                }
            });
            is $mech->uri->path, '/admin/templates/' . $body->id . '/new', 'Not redirected on error';
            $mech->content_contains('exactly 3', 'Error message shown for wrong segment count');
        };

        subtest 'mixed wildcard is rejected' => sub {
            $mech->get_ok('/admin/templates/' . $body->id . '/new');
            $mech->submit_form_ok({
                with_fields => {
                    title => 'Mixed Wildcard Template',
                    text => 'Template text',
                    auto_response => 'on',
                    external_status_code => 'abc*:def:ghi',
                }
            });
            is $mech->uri->path, '/admin/templates/' . $body->id . '/new', 'Not redirected on error';
            $mech->content_contains('cannot be mixed', 'Error message shown for mixed wildcard');
        };

        $mech->log_out_ok;
    };
};

subtest 'validate_response_template_external_status_code' => sub {
    my $cobrand = FixMyStreet::Cobrand::Dumfries->new;

    subtest 'valid codes return undef' => sub {
        is $cobrand->validate_response_template_external_status_code('abc:def:ghi'), undef,
            'Three non-empty segments is valid';
        is $cobrand->validate_response_template_external_status_code('abc:*:*'), undef,
            'Wildcards in segments is valid';
        is $cobrand->validate_response_template_external_status_code('abc::'), undef,
            'Empty segments is valid';
        is $cobrand->validate_response_template_external_status_code('abc:*:'), undef,
            'Mix of value, wildcard, and empty is valid';
    };

    subtest 'must have at least one concrete value' => sub {
        like $cobrand->validate_response_template_external_status_code('*:*:*'), qr/at least one concrete/,
            'All wildcards returns error';
        like $cobrand->validate_response_template_external_status_code('::'), qr/at least one concrete/,
            'All empty segments returns error';
        like $cobrand->validate_response_template_external_status_code('*::'), qr/at least one concrete/,
            'Wildcard and empty returns error';
        like $cobrand->validate_response_template_external_status_code(':*:'), qr/at least one concrete/,
            'Empty wildcard empty returns error';
    };

    subtest 'empty/undef codes return undef (no validation needed)' => sub {
        is $cobrand->validate_response_template_external_status_code(''), undef,
            'Empty string returns undef';
        is $cobrand->validate_response_template_external_status_code(undef), undef,
            'Undef returns undef';
    };

    subtest 'wrong number of segments returns error' => sub {
        like $cobrand->validate_response_template_external_status_code('abc'), qr/exactly 3/,
            'Single segment returns error';
        like $cobrand->validate_response_template_external_status_code('abc:def'), qr/exactly 3/,
            'Two segments returns error';
        like $cobrand->validate_response_template_external_status_code('abc:def:ghi:jkl'), qr/exactly 3/,
            'Four segments returns error';
    };

    subtest 'mixed wildcard and text returns error' => sub {
        like $cobrand->validate_response_template_external_status_code('abc*:def:ghi'), qr/cannot be mixed/,
            'Wildcard mixed with text at start returns error';
        like $cobrand->validate_response_template_external_status_code('abc:d*f:ghi'), qr/cannot be mixed/,
            'Wildcard in middle of text returns error';
        like $cobrand->validate_response_template_external_status_code('abc:def:ghi*'), qr/cannot be mixed/,
            'Wildcard at end of text returns error';
        like $cobrand->validate_response_template_external_status_code('abc:**:ghi'), qr/cannot be mixed/,
            'Double wildcard returns error';
    };
};

done_testing();
