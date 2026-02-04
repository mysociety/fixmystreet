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

subtest 'response_template_external_status_code_regex_match' => sub {
    my $cobrand = FixMyStreet::Cobrand::Dumfries->new;

    subtest 'returns sql, bind, and order' => sub {
        my $result = $cobrand->response_template_external_status_code_regex_match('aaa:bbb:ccc');
        ok $result->{sql}, 'SQL clause returned';
        is_deeply $result->{bind}, ['aaa:bbb:ccc'], 'Bind parameters include the ext_code';
        ok $result->{order}, 'Order clause returned';
    };

    # Test the regex patterns by simulating what PostgreSQL would do
    sub pattern_matches {
        my ($template_pattern, $update_code) = @_;
        # Convert template pattern to Perl regex (same logic as SQL)
        my $regex = $template_pattern;
        $regex =~ s/\*/[^:]*/g;
        $regex =~ s/\+/[^:]+/g;
        return $update_code =~ /^$regex$/;
    }

    subtest 'star wildcard matches empty and non-empty' => sub {
        ok pattern_matches('aaa:*:*', 'aaa:bbb:ccc'), 'Star matches non-empty';
        ok pattern_matches('aaa:*:*', 'aaa::ccc'), 'Star matches empty middle';
        ok pattern_matches('aaa:*:*', 'aaa:bbb:'), 'Star matches empty end';
        ok pattern_matches('aaa:*:*', 'aaa::'), 'Star matches both empty';
        ok !pattern_matches('aaa:*:*', 'xxx:bbb:ccc'), 'Exact part must match';
    };

    subtest 'plus wildcard matches non-empty only' => sub {
        ok pattern_matches('aaa:+:+', 'aaa:bbb:ccc'), 'Plus matches non-empty';
        ok !pattern_matches('aaa:+:+', 'aaa::ccc'), 'Plus does not match empty middle';
        ok !pattern_matches('aaa:+:+', 'aaa:bbb:'), 'Plus does not match empty end';
        ok !pattern_matches('aaa:+:+', 'aaa::'), 'Plus does not match both empty';
    };

    subtest 'mixed wildcards work correctly' => sub {
        ok pattern_matches('aaa:*:+', 'aaa:bbb:ccc'), 'Mixed: both non-empty';
        ok pattern_matches('aaa:*:+', 'aaa::ccc'), 'Mixed: star matches empty, plus matches non-empty';
        ok !pattern_matches('aaa:*:+', 'aaa:bbb:'), 'Mixed: star ok but plus fails on empty';
        ok !pattern_matches('aaa:+:*', 'aaa::ccc'), 'Mixed: plus fails on empty';
        ok pattern_matches('aaa:+:*', 'aaa:bbb:'), 'Mixed: plus matches non-empty, star matches empty';
    };

    subtest 'exact match requires exact values' => sub {
        ok pattern_matches('aaa:bbb:ccc', 'aaa:bbb:ccc'), 'Exact match works';
        ok !pattern_matches('aaa:bbb:ccc', 'aaa:bbb:xxx'), 'Exact match fails on different value';
        ok !pattern_matches('aaa:bbb:ccc', 'aaa:bbb:'), 'Exact match fails on empty';
    };

    subtest 'empty segments match only empty' => sub {
        ok pattern_matches('aaa::', 'aaa::'), 'Empty pattern matches empty';
        ok !pattern_matches('aaa::', 'aaa:bbb:ccc'), 'Empty pattern does not match non-empty';
        ok !pattern_matches('aaa::', 'aaa::ccc'), 'Empty pattern does not match partial non-empty';
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

        subtest 'exact empty segments match beats star wildcards' => sub {
            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'status1::', ''
            );
            is $template->title, 'Empty Segments Template',
                'Exact empty segments template beats wildcard';
        };

        subtest 'star wildcard matches empty segment when no exact match' => sub {
            # Delete the empty segments template so it can't match
            $template_empty_segments->delete;

            # Now the 'status1:*:*' template should match since * matches empty
            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'status1::', ''
            );
            is $template->title, 'Two Wildcard Template',
                'Star wildcard matches empty segments';
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

subtest 'response_template_for with plus wildcard matching' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['dumfries'],
    }, sub {
        my $test_problem = FixMyStreet::DB->resultset('Problem')->create({
            postcode           => 'DG1 1AA',
            bodies_str         => $body->id,
            areas              => ',2656,',
            category           => 'Potholes',
            title              => 'Plus wildcard test problem',
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

        # Template with + wildcards (requires non-empty values)
        my $template_plus = FixMyStreet::DB->resultset('ResponseTemplate')->create({
            body_id => $body->id,
            title => 'Plus Wildcard Template',
            text => 'Plus wildcard response',
            auto_response => 1,
            state => '',
            external_status_code => 'status1:+:+',
        });

        # Template with * wildcards (matches anything including empty)
        my $template_star = FixMyStreet::DB->resultset('ResponseTemplate')->create({
            body_id => $body->id,
            title => 'Star Wildcard Template',
            text => 'Star wildcard response',
            auto_response => 1,
            state => '',
            external_status_code => 'status1:*:*',
        });

        subtest 'plus wildcard matches non-empty segments' => sub {
            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'status1:outcome1:priority1', ''
            );
            # Plus is more specific than star, so plus template should win
            is $template->title, 'Plus Wildcard Template',
                'Plus wildcard template matches when segments are non-empty';
        };

        subtest 'plus wildcard does not match empty segments' => sub {
            # Delete the plus template to see star behavior
            $template_plus->delete;

            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'status1::', ''
            );
            # Star matches empty, so star template should match
            is $template->title, 'Star Wildcard Template',
                'Star wildcard matches empty segments';
        };

        subtest 'recreate plus template and verify it does not match empty' => sub {
            $template_plus = FixMyStreet::DB->resultset('ResponseTemplate')->create({
                body_id => $body->id,
                title => 'Plus Wildcard Template 2',
                text => 'Plus wildcard response',
                auto_response => 1,
                state => '',
                external_status_code => 'status1:+:+',
            });

            my $template = $test_problem->response_template_for(
                $body, 'investigating', 'confirmed',
                'status1::', ''
            );
            # Plus does NOT match empty, star does - so star wins
            is $template->title, 'Star Wildcard Template',
                'Plus wildcard does not match empty segments, star does';

            $template_plus->delete;
        };

        # Cleanup
        $template_star->delete;
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

        subtest 'star wildcard external_status_code is accepted' => sub {
            $mech->get_ok('/admin/templates/' . $body->id . '/new');
            $mech->submit_form_ok({
                with_fields => {
                    title => 'Star Wildcard Template',
                    text => 'Template text',
                    auto_response => 'on',
                    external_status_code => 'abc:*:*',
                }
            });
            is $mech->uri->path, '/admin/templates/' . $body->id, 'Redirected after valid star wildcard submission';

            $mech->delete_response_template($_) for $body->response_templates->search({ title => 'Star Wildcard Template' });
        };

        subtest 'plus wildcard external_status_code is accepted' => sub {
            $mech->get_ok('/admin/templates/' . $body->id . '/new');
            $mech->submit_form_ok({
                with_fields => {
                    title => 'Plus Wildcard Template',
                    text => 'Template text',
                    auto_response => 'on',
                    external_status_code => 'abc:+:+',
                }
            });
            is $mech->uri->path, '/admin/templates/' . $body->id, 'Redirected after valid plus wildcard submission';

            $mech->delete_response_template($_) for $body->response_templates->search({ title => 'Plus Wildcard Template' });
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

        subtest 'mixed star wildcard is rejected' => sub {
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
            $mech->content_contains('cannot be mixed', 'Error message shown for mixed star wildcard');
        };

        subtest 'mixed plus wildcard is rejected' => sub {
            $mech->get_ok('/admin/templates/' . $body->id . '/new');
            $mech->submit_form_ok({
                with_fields => {
                    title => 'Mixed Plus Wildcard Template',
                    text => 'Template text',
                    auto_response => 'on',
                    external_status_code => 'abc+:def:ghi',
                }
            });
            is $mech->uri->path, '/admin/templates/' . $body->id . '/new', 'Not redirected on error';
            $mech->content_contains('cannot be mixed', 'Error message shown for mixed plus wildcard');
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
            'Star wildcards in segments is valid';
        is $cobrand->validate_response_template_external_status_code('abc:+:+'), undef,
            'Plus wildcards in segments is valid';
        is $cobrand->validate_response_template_external_status_code('abc:*:+'), undef,
            'Mix of star and plus wildcards is valid';
        is $cobrand->validate_response_template_external_status_code('abc::'), undef,
            'Empty segments is valid';
        is $cobrand->validate_response_template_external_status_code('abc:*:'), undef,
            'Mix of value, star wildcard, and empty is valid';
        is $cobrand->validate_response_template_external_status_code('abc:+:'), undef,
            'Mix of value, plus wildcard, and empty is valid';
    };

    subtest 'must have at least one concrete value' => sub {
        like $cobrand->validate_response_template_external_status_code('*:*:*'), qr/at least one concrete/,
            'All star wildcards returns error';
        like $cobrand->validate_response_template_external_status_code('+:+:+'), qr/at least one concrete/,
            'All plus wildcards returns error';
        like $cobrand->validate_response_template_external_status_code('*:+:*'), qr/at least one concrete/,
            'Mix of star and plus wildcards only returns error';
        like $cobrand->validate_response_template_external_status_code('::'), qr/at least one concrete/,
            'All empty segments returns error';
        like $cobrand->validate_response_template_external_status_code('*::'), qr/at least one concrete/,
            'Star wildcard and empty returns error';
        like $cobrand->validate_response_template_external_status_code('+::'), qr/at least one concrete/,
            'Plus wildcard and empty returns error';
        like $cobrand->validate_response_template_external_status_code(':*:'), qr/at least one concrete/,
            'Empty star wildcard empty returns error';
        like $cobrand->validate_response_template_external_status_code(':+:'), qr/at least one concrete/,
            'Empty plus wildcard empty returns error';
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
