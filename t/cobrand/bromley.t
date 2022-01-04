use CGI::Simple;
use Test::MockModule;
use Test::MockTime qw(:all);
use Test::Warn;
use DateTime;
use Test::Output;
use FixMyStreet::TestMech;
use FixMyStreet::SendReport::Open311;
use FixMyStreet::Script::Reports;
use Open311::PostServiceRequestUpdates;
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });

# Create test data
my $user = $mech->create_user_ok( 'bromley@example.com', name => 'Bromley' );
my $body = $mech->create_body_ok( 2482, 'Bromley Council', {
    can_be_devolved => 1, send_extended_statuses => 1, comment_user => $user,
    send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1
});
my $staffuser = $mech->create_user_ok( 'staff@example.com', name => 'Staffie', from_body => $body );
my $role = FixMyStreet::DB->resultset("Role")->create({
    body => $body, name => 'Role A', permissions => ['moderate', 'user_edit', 'report_mark_private', 'report_inspect', 'contribute_as_body'] });
$staffuser->add_to_roles($role);
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Other',
    email => 'LIGHT',
);
$contact->set_extra_metadata(id_field => 'service_request_id_ext');
$contact->set_extra_fields(
    { code => 'easting', datatype => 'number', },
    { code => 'northing', datatype => 'number', },
    { code => 'service_request_id_ext', datatype => 'number', },
    { code => 'service_sub_code', values => [ { key => 'RED', name => 'Red' }, { key => 'BLUE', name => 'Blue' } ], },
);
$contact->update;
my $tfl = $mech->create_body_ok( 2482, 'TfL');
$mech->create_contact_ok(
    body_id => $tfl->id,
    category => 'Traffic Lights',
    email => 'tfl@example.org',
);

$mech->create_contact_ok(
    body => $body,
    category => 'Report missed collection',
    email => 'missed',
    send_method => 'Open311',
    endpoint => 'waste-endpoint',
    group => ['Waste'],
);

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    latitude => 51.402096,
    longitude => 0.015784,
    cobrand => 'bromley',
    areas => '2482,8141',
    user => $user,
    send_method_used => 'Open311',
    whensent => 'now()',
    external_id => '456',
    extra => {
        contributed_by => $staffuser->id,
    },
});
my $report = $reports[0];

for my $update ('in progress', 'unable to fix') {
    FixMyStreet::DB->resultset('Comment')->find_or_create( {
        problem_state => $update,
        problem_id => $report->id,
        user_id    => $user->id,
        name       => 'User',
        mark_fixed => 'f',
        text       => "This update marks it as $update",
        state      => 'confirmed',
        confirmed  => 'now()',
        anonymous  => 'f',
    } );
}

# Test Bromley special casing of 'unable to fix'
$mech->get_ok( '/report/' . $report->id );
$mech->content_contains( 'marks it as in progress' );
$mech->content_contains( 'State changed to: In progress' );
$mech->content_contains( 'marks it as unable to fix' );
$mech->content_contains( 'State changed to: No further action' );

subtest 'Check updates not sent for staff with no text' => sub {
    my $comment = FixMyStreet::DB->resultset('Comment')->find_or_create( {
        problem_state => 'unable to fix',
        problem_id => $report->id,
        user_id    => $staffuser->id,
        name       => 'User',
        mark_fixed => 'f',
        text       => "",
        state      => 'confirmed',
        confirmed  => 'now()',
        anonymous  => 'f',
    } );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
    }, sub {
        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;
    };

    $comment->discard_changes;
    is $comment->send_fail_count, 0, "comment sending not attempted";
    is $comment->get_extra_metadata('cobrand_skipped_sending'), 1, "skipped sending comment";
};

subtest 'Updates from staff with no text but with private comments are sent' => sub {
    my $comment = FixMyStreet::DB->resultset('Comment')->find_or_create( {
        problem_state => 'unable to fix',
        problem_id => $report->id,
        user_id    => $staffuser->id,
        name       => 'User',
        mark_fixed => 'f',
        text       => "",
        state      => 'confirmed',
        confirmed  => 'now()',
        anonymous  => 'f',
    } );
    $comment->unset_extra_metadata('cobrand_skipped_sending');
    $comment->set_extra_metadata(private_comments => 'This comment has secret notes');
    $comment->update;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
    }, sub {
        Open311->_inject_response('/servicerequestupdates.xml', '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>42</update_id></request_update></service_request_updates>');

        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;

        $comment->discard_changes;
        ok $comment->whensent, "comment was sent";
        ok !$comment->get_extra_metadata('cobrand_skipped_sending'), "didn't skip sending comment";

        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        like $c->param('description'), qr/Private comments: This comment has secret notes/, 'private comments included in update description';
    };
};

for my $test (
    {
        desc => 'testing special Open311 behaviour',
        updates => {},
        expected => {
          'attribute[easting]' => 540315,
          'attribute[northing]' => 168935,
          'attribute[service_request_id_ext]' => $report->id,
          'attribute[report_title]' => 'Test Test 1 for ' . $body->id . ' | ROLES: Role A',
          'jurisdiction_id' => 'FMS',
          address_id => undef,
        },
    },
    {
        desc => 'testing Open311 behaviour with no map click or postcode',
        updates => {
            used_map => 0,
            postcode => ''
        },
        expected => {
          'attribute[easting]' => 540315,
          'attribute[northing]' => 168935,
          'attribute[service_request_id_ext]' => $report->id,
          'jurisdiction_id' => 'FMS',
          'address_id' => '#NOTPINPOINTED#',
        },
    },
    {
        desc => 'asset ID',
        feature_id => '1234',
        expected => {
          'attribute[service_request_id_ext]' => $report->id,
          'attribute[report_title]' => 'Test Test 1 for ' . $body->id . ' | ID: 1234 | ROLES: Role A',
        },
    },
) {
    subtest $test->{desc}, sub {
        $report->$_($test->{updates}->{$_}) for keys %{$test->{updates}};
        $report->$_(undef) for qw/ whensent send_method_used external_id /;
        $report->set_extra_fields({ name => 'feature_id', value => $test->{feature_id} })
            if $test->{feature_id};
        $report->update;
        FixMyStreet::override_config {
            STAGING_FLAGS => { send_reports => 1 },
            ALLOWED_COBRANDS => [ 'fixmystreet', 'bromley' ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            FixMyStreet::Script::Reports::send();
        };
        $report->discard_changes;
        ok $report->whensent, 'Report marked as sent';
        is $report->send_method_used, 'Open311', 'Report sent via Open311';
        is $report->external_id, 248, 'Report has right external ID';

        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param($_), $test->{expected}->{$_}, "Request had correct $_"
            for keys %{$test->{expected}};
    };
}

subtest 'ensure private_comments are added to open311 description' => sub {
    $report->set_extra_metadata(private_comments => 'Secret notes go here');
    $report->whensent(undef);
    $report->update;

    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'fixmystreet', 'bromley' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        FixMyStreet::Script::Reports::send();
    };

    $report->discard_changes;
    ok $report->whensent, 'Report marked as sent';
    unlike $report->detail, qr/Private comments/, 'private comments not saved to report detail';

    my $req = Open311->test_req_used;
    my $c = CGI::Simple->new($req->content);
    like $c->param('description'), qr/Private comments: Secret notes go here/, 'private comments included in description';
};

subtest 'test waste duplicate' => sub {
    my $sender = FixMyStreet::SendReport::Open311->new(
        bodies => [ $body ], body_config => { $body->id => $body },
    );
    Open311->_inject_response('/requests.xml', '<?xml version="1.0" encoding="utf-8"?><errors><error><code></code><description>Missed Collection event already open for the property</description></error></errors>', 500);
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
    }, sub {
        $sender->send($report, {
            easting => 1,
            northing => 2,
            url => 'http://example.org/',
        });
    };
    is $report->state, 'duplicate', 'State updated';
};

subtest 'test DD taking so long it expires' => sub {
    my $title = $report->title;
    $report->update({ title => "Garden Subscription - Renew" });
    my $sender = FixMyStreet::SendReport::Open311->new(
        bodies => [ $body ], body_config => { $body->id => $body },
    );
    Open311->_inject_response('/requests.xml', '<?xml version="1.0" encoding="utf-8"?><errors><error><code></code><description>Cannot renew this property, a new request is required</description></error></errors>', 500);
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
    }, sub {
        $sender->send($report, {
            easting => 1,
            northing => 2,
            url => 'http://example.org/',
        });
    };
    is $report->get_extra_field_value("Subscription_Type"), 1, 'Type updated';
    is $report->title, "Garden Subscription - New";
    $report->update({ title => $title });
};

subtest 'Private comments on updates are added to open311 description' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['bromley', 'tfl'],
    }, sub {
        $report->comments->delete;

        Open311->_inject_response('/servicerequestupdates.xml', '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>42</update_id></request_update></service_request_updates>');

        $mech->log_out_ok;
        $mech->log_in_ok($staffuser->email);
        $mech->host('bromley.fixmystreet.com');

        $mech->get_ok('/report/' . $report->id);

        $mech->submit_form_ok( {
                with_fields => {
                    submit_update => 1,
                    update => 'Test',
                    private_comments => 'Secret update notes',
                    fms_extra_title => 'DR',
                    first_name => 'Bromley',
                    last_name => 'Council',
                },
            },
            'update form submitted'
        );

        is $report->comments->count, 1, 'comment was added';
        my $comment = $report->comments->first;
        is $comment->get_extra_metadata('private_comments'), 'Secret update notes', 'private comments saved to comment';

        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;

        $comment->discard_changes;
        ok $comment->whensent, 'Comment marked as sent';
        unlike $comment->text, qr/Private comments/, 'private comments not saved to update text';

        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        like $c->param('description'), qr/Private comments: Secret update notes/, 'private comments included in update description';
    };
};

for my $test (
    {
        cobrand => 'bromley',
        fields => {
            submit_update   => 1,
            username_register => 'unregistered@example.com',
            update          => 'Update from an unregistered user',
            add_alert       => undef,
            first_name            => 'Unreg',
            last_name            => 'User',
            fms_extra_title => 'DR',
            may_show_name   => undef,
        }
    },
    {
        cobrand => 'fixmystreet',
        fields => {
            submit_update   => 1,
            username_register => 'unregistered@example.com',
            update          => 'Update from an unregistered user',
            add_alert       => undef,
            name            => 'Unreg User',
            fms_extra_title => 'DR',
            may_show_name   => undef,
        }
    },
)
{
    subtest 'check Bromley update emails via ' . $test->{cobrand} . ' cobrand are correct' => sub {
        $mech->log_out_ok();
        $mech->clear_emails_ok();

        my $report_id = $report->id;

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ $test->{cobrand} ],
        }, sub {
            $mech->get_ok("/report/$report_id");
            $mech->submit_form_ok(
                {
                    with_fields => $test->{fields}
                },
                'submit update'
            );
        };
        $mech->content_contains('Nearly done! Now check your email');

        my $body = $mech->get_text_body_from_email;
        like $body, qr/This update will be sent to Bromley Council/i, "Email indicates problem will be sent to Bromley";
        unlike $body, qr/Note that we do not send updates to/i, "Email does not say updates aren't sent to Bromley";

        my $unreg_user = FixMyStreet::DB->resultset('User')->find( { email => 'unregistered@example.com' } );

        ok $unreg_user, 'found user';

        $mech->delete_user( $unreg_user );
    };
}

subtest 'check display of TfL and waste reports' => sub {
    $mech->create_problems_for_body( 1, $tfl->id, 'TfL Test', {
        latitude => 51.402096,
        longitude => 0.015784,
        cobrand => 'bromley',
        user => $user,
    });
    $mech->get_ok( '/report/' . $report->id );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->follow_link_ok({ text_regex => qr/Back to all reports/i });
    };
    $mech->content_like(qr{<a title="TfL Test[^>]*www.example.org[^>]*><img[^>]*grey});
    $mech->content_like(qr{<a title="Test Test[^>]*href="/[^>]*><img[^>]*yellow});
    $mech->content_lacks('Report missed collection');
};

subtest 'check staff can filter on waste reports' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['bromley', 'tfl'],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->host('bromley.fixmystreet.com');
        $mech->get_ok( '/reports/Bromley');
        $mech->content_lacks('<optgroup label="Waste"');

        $mech->log_in_ok($staffuser->email);
        $mech->get_ok( '/reports/Bromley');
        $mech->content_contains('<optgroup label="Waste"');
        $mech->get_ok( '/report/' . $report->id );
        $mech->content_contains('<option value="Report missed collection">');
    };
};

subtest 'check geolocation overrides' => sub {
    my $cobrand = FixMyStreet::Cobrand::Bromley->new;
    foreach my $test (
        { query => 'Main Rd, BR1', town => 'Bromley', string => 'Main Rd' },
        { query => 'Main Rd, BR3', town => 'Beckenham', string => 'Main Rd' },
        { query => 'Main Rd, BR4', town => 'West Wickham', string => 'Main Rd' },
        { query => 'Main Rd, BR5', town => 'Orpington', string => 'Main Rd' },
        { query => 'Main Rd, BR7', town => 'Chislehurst', string => 'Main Rd' },
        { query => 'Main Rd, BR8', town => 'Swanley', string => 'Main Rd' },
        { query => 'Old Priory Avenue', town => 'BR6 0PL', string => 'Old Priory Avenue' },
    ) {
        my $res = $cobrand->disambiguate_location($test->{query});
        is $res->{town}, $test->{town}, "Town matches $test->{town}";
        is $res->{string}, $test->{string}, "String matches $test->{string}";
    }
};

subtest 'check special subcategories in admin' => sub {
    $mech->create_user_ok('superuser@example.com', is_superuser => 1, name => "Super User");
    $mech->log_in_ok('superuser@example.com');
    $user->update({ from_body => $body->id });
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/admin/templates/' . $body->id . '/new');
        $mech->get_ok('/admin/users/' . $user->id);
        $mech->submit_form_ok({ with_fields => { 'contacts['.$contact->id.']' => 1, 'contacts[BLUE]' => 1 } });
    };
    $user->discard_changes;
    is_deeply $user->get_extra_metadata('categories'), [ $contact->id ];
    is_deeply $user->get_extra_metadata('subcategories'), [ 'BLUE' ];
    $user->unset_extra_metadata('categories');
    $user->unset_extra_metadata('subcategories');
    $user->update;
};

subtest 'check title field on report page for staff' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['bromley', 'tfl'],
    }, sub {
        $mech->get_ok( '/report/' . $report->id );
        $mech->content_contains('MRS');
    };
};

subtest 'check heatmap page' => sub {
    $user->update({ area_ids => [ 60705 ] });
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => { category_groups => { bromley => 1 }, heatmap => { bromley => 1 } },
    }, sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/dashboard/heatmap?end_date=2018-12-31');
        $mech->content_contains('Report missed collection');
        $mech->get_ok('/dashboard/heatmap?filter_category=RED&ajax=1');
    };
    $user->update({ area_ids => undef });
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bromley',
    COBRAND_FEATURES => {
        payment_gateway => { bromley => { ggw_cost => 1000 } },
        echo => { bromley => { sample_data => 1 } },
        waste => { bromley => 1 }
    },
}, sub {
    subtest 'test open enquiries' => sub {
        set_fixed_time('2020-05-19T12:00:00Z'); # After sample food waste collection
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('every other Tuesday');
        $mech->content_like(qr/Mixed Recycling.*?Next collection<\/dt>\s*<dd[^>]*>\s*Wednesday, 20th May\s+\(this collection has been adjusted/s);
        $mech->follow_link_ok({ text => 'Report a problem with a food waste collection' });
        $mech->content_contains('Waste spillage');
        $mech->content_lacks('Gate not closed');
        restore_time();
    };

    subtest 'test crew reported issue' => sub {
        set_fixed_time('2020-05-21T12:00:00Z'); # After sample container mix
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr/Mixed Recycling.*?Last collection<\/dt>\s*<dd[^>]*>\s*Wednesday, 20th May\s+\(this collection was adjusted/s);
        $mech->content_contains('A missed collection cannot be reported, please see the last collection status above.');
        $mech->content_lacks('Report a mixed recycling ');
        restore_time();
    };

    subtest 'test reporting before/after completion' => sub {
        set_fixed_time('2020-05-27T11:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr/Non-Recyclable Refuse.*?Last collection<\/dt>\s*<dd[^>]*>\s*Wednesday, 27th May, at 10:00am\s*<p>\s*Wrong Bin Out/s);
        $mech->content_like(qr/Paper &amp; Cardboard.*?Next collection<\/dt>\s*<dd[^>]*>\s*Wednesday, 27th May\s+\(In progress\)/s);
        $mech->follow_link_ok({ text => 'Report a problem with a paper & cardboard collection' });
        $mech->content_lacks('Waste spillage');

        set_fixed_time('2020-05-27T19:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr/Non-Recyclable Refuse.*?Last collection<\/dt>\s*<dd[^>]*>\s*Wednesday, 27th May, at 10:00am\s*<p>\s*Wrong Bin Out/s);
        $mech->content_like(qr/Paper &amp; Cardboard.*?Last collection<\/dt>\s*<dd[^>]*>\s*Wednesday, 27th May\s*<\/dd>/s);
        $mech->follow_link_ok({ text => 'Report a problem with a paper & cardboard collection' });
        $mech->content_contains('Waste spillage');
    };

    subtest 'test template creation' => sub {
        $mech->log_in_ok('superuser@example.com');
        $mech->get_ok('/admin/templates/' . $body->id . '/new');
        $mech->submit_form_ok({ with_fields => {
            title => 'Wrong bin',
            text => 'We could not collect your waste as it was not correctly presented.',
            resolution_code => 187,
            task_type => 3216,
            task_state => 'Completed',
        } });
        $mech->log_out_ok;
    };

    subtest 'test reporting before/after completion' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('May, at 10:00am');
        $mech->content_contains('We could not collect your waste as it was not correctly presented.');
        $mech->content_lacks('Report a paper &amp; cardboard collection');
        $mech->content_contains('Report a non-recyclable refuse collection');
        set_fixed_time('2020-05-28T12:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a non-recyclable refuse collection');
        set_fixed_time('2020-05-29T12:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a non-recyclable refuse collection');
        set_fixed_time('2020-05-30T12:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Report a non-recyclable refuse collection');
        restore_time();
    };

    subtest 'test requesting garden waste' => sub {
		my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', sub {
            return [ {
                Id => 1005,
                ServiceId => 545,
                ServiceName => 'Garden waste collection',
                ServiceTasks => { ServiceTask => {
                    Id => 405,
                    Data => { ExtensibleDatum => [ { DatatypeName => 'LBB - GW Container', ChildData => { ExtensibleDatum => { DatatypeName => 'Quantity', Value => 1, } }, } ] },
                    ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                        StartDate => { DateTime => '2019-04-01T23:00:00Z' },
                        EndDate => { DateTime => '2050-05-14T23:00:00Z' },
                        LastInstance => { OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' }, CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' }, Ref => { Value => { anyType => [ 567, 890 ] } }, },
                        NextInstance => undef,
                    } ] },
                } },
            } ]
        } );
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Request a replacement garden waste container');
    };

    subtest 'test pending garden event' => sub {
		my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetEventsForObject', sub { [
            {
                Id => 123,
                ServiceId => '545', # Garden waste
                EventStateId => '14795', # Allocated to crew
                EventTypeId => '2106', # Garden subscription
            },
        ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_contains('You have a pending Garden Subscription');
        $mech->content_lacks('Subscribe to Green Garden Waste');
    };

};

subtest 'test waste max-per-day' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        COBRAND_FEATURES => {
            echo => { bromley => {
                sample_data => 1
            } },
            payment_gateway => { bromley => { ggw_cost => 1000 } },
            waste_features => { bromley => {
                max_requests_per_day => 3,
                max_properties_per_day => 1,
            } },
            waste => { bromley => 1 }
        },
    }, sub {
        SKIP: {
            skip( "No memcached", 7 ) unless Memcached::set('waste-prop-test', 1);
            Memcached::delete("waste-prop-test");
            Memcached::delete("waste-req-test");
            $mech->get_ok('/waste/12345');
            $mech->get_ok('/waste/12345');
            $mech->get('/waste/12346');
            is $mech->res->code, 403, 'Now forbidden, another property';
            $mech->content_contains('limited the number');
            $mech->get('/waste/12345');
            is $mech->res->code, 403, 'Now forbidden, too many views';
            $mech->log_in_ok('superuser@example.com');
            $mech->get_ok('/waste/12345');
        }
    };

};

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

subtest 'updating of waste reports' => sub {
    my $integ = Test::MockModule->new('SOAP::Lite');
    $integ->mock(call => sub {
        my ($cls, @args) = @_;
        my $method = $args[0]->name;
        if ($method eq 'GetEvent') {
            my ($key, $type, $value) = ${$args[3]->value}->value;
            my $external_id = ${$value->value}->value->value;
            my ($waste, $event_state_id, $resolution_code) = split /-/, $external_id;
            return SOAP::Result->new(result => {
                EventStateId => $event_state_id,
                EventTypeId => '2104',
                LastUpdatedDate => { OffsetMinutes => 60, DateTime => '2020-06-24T14:00:00Z' },
                ResolutionCodeId => $resolution_code,
            });
        } elsif ($method eq 'GetEventType') {
            return SOAP::Result->new(result => {
                Workflow => { States => { State => [
                    { CoreState => 'New', Name => 'New', Id => 15001 },
                    { CoreState => 'Pending', Name => 'Unallocated', Id => 15002 },
                    { CoreState => 'Pending', Name => 'Allocated to Crew', Id => 15003 },
                    { CoreState => 'Closed', Name => 'Completed', Id => 15004,
                      ResolutionCodes => { StateResolutionCode => [
                        { ResolutionCodeId => 201, Name => '' },
                        { ResolutionCodeId => 202, Name => 'Spillage on Arrival' },
                      ] } },
                    { CoreState => 'Closed', Name => 'Not Completed', Id => 15005,
                      ResolutionCodes => { StateResolutionCode => [
                        { ResolutionCodeId => 203, Name => 'Nothing Found' },
                        { ResolutionCodeId => 204, Name => 'Too Heavy' },
                        { ResolutionCodeId => 205, Name => 'Inclement Weather' },
                      ] } },
                    { CoreState => 'Closed', Name => 'Rejected', Id => 15006,
                      ResolutionCodes => { StateResolutionCode => [
                        { ResolutionCodeId => 206, Name => 'Out of Time' },
                        { ResolutionCodeId => 207, Name => 'Duplicate' },
                      ] } },
                ] } },
            });
        } else {
            is $method, 'UNKNOWN';
        }
    });

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        COBRAND_FEATURES => {
            echo => { bromley => { url => 'https://www.example.org/' } },
            waste => { bromley => 1 }
        },
    }, sub {
        $body->response_templates->create({
            title => 'Allocated title', text => 'This has been allocated',
            'auto_response' => 1, state => 'action scheduled',
        });

        @reports = $mech->create_problems_for_body(2, $body->id, 'Report missed collection', {
            category => 'Report missed collection',
            cobrand_data => 'waste',
        });
        $reports[1]->update({ external_id => 'something-else' }); # To test loop
        $report = $reports[0];
        my $cobrand = FixMyStreet::Cobrand::Bromley->new;

        $report->update({ external_id => 'waste-15001-' });
        stdout_like {
            $cobrand->waste_fetch_events(1);
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, 0, 'No new update';
        is $report->state, 'confirmed', 'No state change';

        $report->update({ external_id => 'waste-15003-' });
        stdout_like {
            $cobrand->waste_fetch_events(1);
        } qr/Updating report to state action scheduled, Allocated to Crew/;
        $report->discard_changes;
        is $report->comments->count, 1, 'A new update';
        my $update = $report->comments->first;
        is $update->text, 'This has been allocated';
        is $report->state, 'action scheduled', 'A state change';

        $report->update({ external_id => 'waste-15003-' });
        stdout_like {
            $cobrand->waste_fetch_events(1);
        } qr/Latest update matches fetched state/;
        $report->discard_changes;
        is $report->comments->count, 1, 'No new update';
        is $report->state, 'action scheduled', 'State unchanged';

        $report->update({ external_id => 'waste-15004-201' });
        stdout_like {
            $cobrand->waste_fetch_events(1);
        } qr/Updating report to state fixed - council, Completed/;
        $report->discard_changes;
        is $report->comments->count, 2, 'A new update';
        is $report->state, 'fixed - council', 'Changed to fixed';

        $reports[1]->update({ state => 'fixed - council' });
        stdout_like {
            $cobrand->waste_fetch_events(1);
        } qr/^$/, 'No open reports';

        $report->update({ external_id => 'waste-15005-205', state => 'confirmed' });
        stdout_like {
            $cobrand->waste_fetch_events(1);
        } qr/Updating report to state unable to fix, Inclement Weather/;
        $report->discard_changes;
        is $report->comments->count, 3, 'A new update';
        is $report->state, 'unable to fix', 'A state change';
    };

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        COBRAND_FEATURES => {
            echo => { bromley => {
                url => 'https://www.example.org/',
                receive_action => 'action',
                receive_username => 'un',
                receive_password => 'password',
            } },
            waste => { bromley => 1 }
        },
    }, sub {
        FixMyStreet::App->log->disable('info');

        $mech->get('/waste/echo');
        is $mech->res->code, 405, 'Cannot GET';

        $mech->post('/waste/echo', Content_Type => 'text/xml');
        is $mech->res->code, 400, 'No body';

        my $in = '<Envelope><Header><Action>bad-action</Action></Header><Body></Body></Envelope>';
        $mech->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $mech->res->code, 400, 'Bad action';

        $in = '<Envelope><Header><Action>action</Action><Security><UsernameToken><Username></Username><Password></Password></UsernameToken></Security></Header><Body></Body></Envelope>';
        $mech->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $mech->res->code, 400, 'Bad auth';

        $in = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<Envelope>
  <Header>
    <Action>action</Action>
    <Security><UsernameToken><Username>un</Username><Password>password</Password></UsernameToken></Security>
  </Header>
  <Body>
    <NotifyEventUpdated>
      <event>
        <Guid>waste-15005-XXX</Guid>
        <EventTypeId>2104</EventTypeId>
        <EventStateId>15006</EventStateId>
        <ResolutionCodeId>207</ResolutionCodeId>
      </event>
    </NotifyEventUpdated>
  </Body>
</Envelope>
EOF

        $mech->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $mech->res->code, 200, 'OK response, even though event does not exist';
        is $report->comments->count, 3, 'No new update';

        $in = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<Envelope>
  <Header>
    <Action>action</Action>
    <Security><UsernameToken><Username>un</Username><Password>password</Password></UsernameToken></Security>
  </Header>
  <Body>
    <NotifyEventUpdated>
      <event>
        <Guid>waste-15005-205</Guid>
        <EventTypeId>2104</EventTypeId>
        <EventStateId>15006</EventStateId>
        <ResolutionCodeId>207</ResolutionCodeId>
      </event>
    </NotifyEventUpdated>
  </Body>
</Envelope>
EOF
        $mech->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        #$report->update({ external_id => 'waste-15005-205', state => 'confirmed' });
        is $report->comments->count, 4, 'A new update';
        $report->discard_changes;
        is $report->state, 'closed', 'A state change';

        FixMyStreet::App->log->enable('info');
    };
};

subtest 'Dashboard CSV extra columns' => sub {
    $mech->log_in_ok($staffuser->email);
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'bromley',
    }, sub {
        $mech->get_ok('/dashboard?export=1');
    };
    $mech->content_contains('"Reported As","Staff User","Staff Role"');
    $mech->content_like(qr/bromley,,[^,]*staff\@example.com,"Role A"/);
};


my $bromley_parks = Test::MockModule->new('BromleyParks');
$bromley_parks->mock('_db_results', sub {
    my ($search) = @_;

    if ($search eq 'Alexandra Rec') {
        return [{ northing => 170901, easting => 535688 }];
    } elsif ($search eq 'The Green') {
        return [{ northing => 162175, easting => 547189 }];
    }
});

subtest 'parks lookup' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk',
    }, sub {
        $mech->log_out_ok;

        $mech->get_ok('/');
        $mech->submit_form_ok({ with_fields => { pc => 'Alexandra Rec' } });
        $mech->content_contains('51.4208');

        $mech->get_ok('/');
        $mech->submit_form_ok({ with_fields => { pc => 'The Green' } });
        $mech->content_contains('51.3396');
    };
};

subtest 'check_within_days' => sub {
    for my $test (
        {
            today => '2021-03-19',
            check => '2021-03-18',
            days => 1,
            is_true => 1,
            name => 'tomorrow',
        },
        {
            today => '2021-03-19',
            check => '2021-03-17',
            days => 1,
            is_true => 0,
            name => 'day after tomorrow',
        },
        {
            today => '2021-03-22',
            check => '2021-03-19',
            days => 1,
            is_true => 1,
            name => 'over weekend',
        },
        {
            today => '2021-03-23',
            check => '2021-03-19',
            days => 1,
            is_true => 0,
            name => 'tuesday',
        },
        {
            today => '2021-03-23',
            check => '2021-03-19',
            days => 1,
            is_true => 1,
            name => 'tuesday future',
            future => 1,
        },
        {
            today => '2021-03-18',
            check => '2021-03-17',
            days => 2,
            is_true => 0,
            name => 'day after tomorrow future',
            future => 1,
        },
        {
            today => '2021-03-20',
            check => '2021-03-19',
            days => 1,
            is_true => 0,
            name => 'saturday not ahead of friday',
            future => 1,
        },
    ) {
        subtest $test->{name} => sub {
            set_fixed_time($test->{today} . 'T12:00:00Z');
            my $date = DateTime::Format::W3CDTF->parse_datetime($test->{check});

            if ( $test->{is_true} ) {
                ok FixMyStreet::Cobrand::Bromley::within_working_days($date, $test->{days}, $test->{future});
            } else {
                ok !FixMyStreet::Cobrand::Bromley::within_working_days($date, $test->{days}, $test->{future});
            }

        };
    }
};

subtest 'check pro-rata calculation' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        COBRAND_FEATURES => {
            payment_gateway => {
                bromley => {
                    ggw_cost => 2000,
                    pro_rata_weekly => 86,
                    pro_rata_minimum => 1586,
                }
            }
        },
    }, sub {
        my $c = FixMyStreet::Cobrand::Bromley->new;

        my $start = DateTime->new(
            year => 2021,
            month => 02,
            day => 19
        );

        for my $test (
            {
                year => 2021,
                month => 2,
                day => 23,
                expected => 1586,
                desc => '4 days remaining',
            },
            {
                year => 2021,
                month => 2,
                day => 26,
                expected => 1586,
                desc => 'one week remaining',
            },
            {
                year => 2021,
                month => 3,
                day => 5,
                expected => 1672,
                desc => 'two weeks remaining',
            },
            {
                year => 2021,
                month => 3,
                day => 8,
                expected => 1672,
                desc => 'two and a half weeks remaining',
            },
            {
                year => 2021,
                month => 8,
                day => 19,
                expected => 3650,
                desc => '25 weeks remaining',
            },
            {
                year => 2022,
                month => 2,
                day => 14,
                expected => 5886,
                desc => '51 weeks remaining',
            },
        ) {

            my $end = DateTime->new(
                year => $test->{year},
                month => $test->{month},
                day => $test->{day},
            );

            is $c->waste_get_pro_rata_bin_cost($end, $start), $test->{expected}, $test->{desc};
        }
    };
};

subtest 'check direct debit reconcilliation' => sub {
    set_fixed_time('2021-03-19T12:00:00Z'); # After sample food waste collection
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('GetServiceUnitsForObject' => sub {
        my ($self, $id) = @_;

        if ( $id == 54321 ) {
            return [ {
                Id => 1005,
                ServiceId => 545,
                ServiceName => 'Garden waste collection',
                ServiceTasks => { ServiceTask => {
                    Id => 405,
                    ScheduleDescription => 'every other Monday',
                    Data => { ExtensibleDatum => [ {
                        DatatypeName => 'LBB - GW Container',
                        ChildData => { ExtensibleDatum => {
                            DatatypeName => 'Quantity',
                            Value => 2,
                        } },
                    } ] },
                    ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                        EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                        LastInstance => {
                            OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                            CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                        },
                    }, {
                        EndDate => { DateTime => '2021-03-30T00:00:00Z' },
                        NextInstance => {
                            CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                            OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                        },
                        LastInstance => {
                            OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                            CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                            Ref => { Value => { anyType => [ 567, 890 ] } },
                        },
                    }
                ] }
            } } } ];
        }
        if ( $id == 54322 || $id == 54324 || $id == 84324 || $id == 154323 ) {
            return [ {
                Id => 1005,
                ServiceId => 545,
                ServiceName => 'Garden waste collection',
                ServiceTasks => { ServiceTask => {
                    Id => 405,
                    ScheduleDescription => 'every other Monday',
                    Data => { ExtensibleDatum => [ {
                        DatatypeName => 'LBB - GW Container',
                        ChildData => { ExtensibleDatum => {
                            DatatypeName => 'Quantity',
                            Value => 1,
                        } },
                    } ] },
                    ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                        EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                        LastInstance => {
                            OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                            CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                        },
                    }, {
                        EndDate => { DateTime => '2021-03-30T00:00:00Z' },
                        NextInstance => {
                            CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                            OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                        },
                        LastInstance => {
                            OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                            CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                            Ref => { Value => { anyType => [ 567, 890 ] } },
                        },
                    }
                ] }
            } } } ];
        }
    });

    my $ad_hoc_orig = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54325',
        'uprn' => '654325',
    });
    $ad_hoc_orig->set_extra_metadata('dd_date', '01/01/2021');
    $ad_hoc_orig->update;

    my $ad_hoc = setup_dd_test_report({
        'Subscription_Type' => 3,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54325',
        'uprn' => '654325',
    });
    $ad_hoc->state('unconfirmed');
    $ad_hoc->update;

    my $ad_hoc_processed = setup_dd_test_report({
        'Subscription_Type' => 3,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54426',
        'uprn' => '654326',
    });
    $ad_hoc_processed->set_extra_metadata('dd_date' => '16/03/2021');
    $ad_hoc_processed->update;

    my $ad_hoc_skipped = setup_dd_test_report({
        'Subscription_Type' => 3,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '94325',
        'uprn' => '954325',
    });
    $ad_hoc_skipped->state('unconfirmed');
    $ad_hoc_skipped->update;

    my $hidden = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54399',
        'uprn' => '554399',
    });
    $hidden->state('hidden');
    $hidden->update;

    my $cc_to_ignore = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'credit_card',
        'property_id' => '54399',
        'uprn' => '554399',
    });
    $cc_to_ignore->state('unconfirmed');
    $cc_to_ignore->update;

    my $integ = Test::MockModule->new('Integrations::Pay360');
    $integ->mock('config', sub { return { dd_sun => 'sun', dd_client_id => 'client' }; } );
    $integ->mock('call', sub {
        my ($self, $method) = @_;

        if ( $method eq 'GetPaymentHistoryAllPayersWithDates' ) {
        return {
            GetPaymentHistoryAllPayersWithDatesResponse => {
            GetPaymentHistoryAllPayersWithDatesResult => {
                AuthStatus => "true",
                OverallStatus => "true",
                StatusCode => "SA",
                StatusMessage => "Success: Payments retrieved",
                Payments => {
                    PaymentAPI => [
                        {   # new sub
                            AlternateKey => "",
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "16/03/2021",
                            DueDate => "16/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW654321",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "First Time",
                        },
                        {   # unhandled new sub
                            AlternateKey => "",
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "16/03/2021",
                            DueDate => "16/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW554321",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "First Time",
                        },
                        {   # hidden new sub
                            AlternateKey => "",
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "16/03/2021",
                            DueDate => "16/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW554399",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "First Time",
                        },
                        {   # ad hoc already processed
                            AlternateKey => "",
                            YourRef => $ad_hoc_processed->id,
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "16/03/2021",
                            DueDate => "16/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW654326",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Regular",
                        },
                        {   # renewal
                            AlternateKey => "",
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "16/03/2021",
                            DueDate => "16/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW654322",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Regular",
                        },
                        {   # renewal already handled
                            AlternateKey => "",
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "16/03/2021",
                            DueDate => "16/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW654324",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Regular",
                        },
                        {   # renewal but payment too new
                            AlternateKey => "",
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "18/03/2021",
                            DueDate => "19/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW654329",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Regular",
                        },
                        {   # renewal but nothing in echo
                            AlternateKey => "",
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "16/03/2021",
                            DueDate => "16/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW754322",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Payment: 17",
                        },
                        {   # renewal but nothing in fms
                            AlternateKey => "",
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "16/03/2021",
                            DueDate => "16/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW854324",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Regular",
                        },
                        {   # subsequent renewal from a cc sub
                            AlternateKey => "",
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "16/03/2021",
                            DueDate => "16/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW3654321",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Regular",
                        },
                        {   # renewal from cc payment
                            AlternateKey => "",
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "27/02/2021",
                            DueDate => "15/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW1654321",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Payment: 01",
                        },
                        {   # ad hoc
                            AlternateKey => "",
                            YourRef => $ad_hoc->id,
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "14/03/2021",
                            DueDate => "16/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW654325",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Regular",
                        },
                        {   # unhandled new sub, ad hoc with same uprn
                            AlternateKey => "",
                            Amount => 10.00,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "16/03/2021",
                            DueDate => "16/03/2021",
                            PayerAccountHoldersName => "A Payer",
                            PayerAccountNumber => 123,
                            PayerName => "A Payer",
                            PayerReference => "GGW954325",
                            PayerSortCode => "12345",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "First Time",
                        },
                    ]
                }
            }}};
        } elsif ( $method eq 'GetCancelledPayerReport' ) {
            return => {
                GetCancelledPayerReportResponse => {
                    GetCancelledPayerReportResult => {
                        StatusCode => 'SA',
                        OverallStatus => 'true',
                        StatusMessage => "Success: cancelled payers retrieved",
                        CancelledPayerRecords => {
                            CancelledPayerRecordAPI => [
                                {   # cancel
                                    AlternateKey => "",
                                    Amount => 10.00,
                                    ClientName => "London Borough of Bromley",
                                    CollectionDate => "26/02/2021",
                                    CancelledDate => "26/02/2021",
                                    PayerAccountHoldersName => "A Payer",
                                    PayerAccountNumber => 123,
                                    PayerName => "A Payer",
                                    Reference => "GGW654323",
                                    PayerSortCode => "12345",
                                    ProductName => "Garden Waste",
                                    Status => "Processed",
                                    Type => "AUDDIS: 0C",
                                },
                                {   # unhandled cancel
                                    AlternateKey => "",
                                    Amount => 10.00,
                                    ClientName => "London Borough of Bromley",
                                    CollectionDate => "21/02/2021",
                                    CancelledDate => "26/02/2021",
                                    PayerAccountHoldersName => "A Payer",
                                    PayerAccountNumber => 123,
                                    PayerName => "A Payer",
                                    Reference => "GGW954326",
                                    PayerSortCode => "12345",
                                    ProductName => "Garden Waste",
                                    Status => "Processed",
                                    Type => "AUDDIS: 0C",
                                },
                                {   # unprocessed cancel
                                    AlternateKey => "",
                                    Amount => 10.00,
                                    ClientName => "London Borough of Bromley",
                                    CollectionDate => "21/02/2021",
                                    CancelledDate => "21/02/2021",
                                    PayerAccountHoldersName => "A Payer",
                                    PayerAccountNumber => 123,
                                    PayerName => "A Payer",
                                    Reference => "GGW854325",
                                    PayerSortCode => "12345",
                                    ProductName => "Garden Waste",
                                    Status => "Processed",
                                    Type => "AUDDIS: 0C",
                                },
                                {   # cancel nothing in echo
                                    AlternateKey => "",
                                    Amount => 10.00,
                                    ClientName => "London Borough of Bromley",
                                    CollectionDate => "21/02/2021",
                                    CancelledDate => "26/02/2021",
                                    PayerAccountHoldersName => "A Payer",
                                    PayerAccountNumber => 123,
                                    PayerName => "A Payer",
                                    Reference => "GGW954324",
                                    PayerSortCode => "12345",
                                    ProductName => "Garden Waste",
                                    Status => "Processed",
                                    Type => "AUDDIS: 0C",
                                },
                                {   # cancel no extended data
                                    AlternateKey => "",
                                    Amount => 10.00,
                                    ClientName => "London Borough of Bromley",
                                    CollectionDate => "26/02/2021",
                                    CancelledDate => "26/02/2021",
                                    PayerAccountHoldersName => "A Payer",
                                    PayerAccountNumber => 123,
                                    PayerName => "A Payer",
                                    Reference => "GGW6654326",
                                    PayerSortCode => "12345",
                                    ProductName => "Garden Waste",
                                    Status => "Processed",
                                    Type => "AUDDIS: 0C",
                                },
                            ]
                        }
                    }
                }
            };
        }
    });

    my $contact = $mech->create_contact_ok(body => $body, category => 'Garden Subscription', email => 'garden@example.com');
    $contact->set_extra_fields(
            { name => 'uprn', required => 1, automated => 'hidden_field' },
            { name => 'property_id', required => 1, automated => 'hidden_field' },
            { name => 'service_id', required => 0, automated => 'hidden_field' },
            { name => 'Subscription_Type', required => 1, automated => 'hidden_field' },
            { name => 'Subscription_Details_Quantity', required => 1, automated => 'hidden_field' },
            { name => 'Subscription_Details_Container_Type', required => 1, automated => 'hidden_field' },
            { name => 'Container_Instruction_Quantity', required => 1, automated => 'hidden_field' },
            { name => 'Container_Instruction_Action', required => 1, automated => 'hidden_field' },
            { name => 'Container_Instruction_Container_Type', required => 1, automated => 'hidden_field' },
            { name => 'current_containers', required => 1, automated => 'hidden_field' },
            { name => 'new_containers', required => 1, automated => 'hidden_field' },
            { name => 'payment_method', required => 1, automated => 'hidden_field' },
            { name => 'pro_rata', required => 0, automated => 'hidden_field' },
            { name => 'payment', required => 1, automated => 'hidden_field' },
            { name => 'client_reference', required => 1, automated => 'hidden_field' },
    );
    $contact->update;

    my $sub_for_renewal = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54321',
        'uprn' => '654322',
    });

    my $sub_for_cancel = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54322',
        'uprn' => '654323',
    });

    # e.g if they tried to create a DD but the process failed
    my $failed_new_sub = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54323',
        'uprn' => '654321',
    });
    $failed_new_sub->state('unconfirmed');
    $failed_new_sub->created(\" created - interval '2' second");
    $failed_new_sub->update;

    my $new_sub = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54323',
        'uprn' => '654321',
    });
    $new_sub->state('unconfirmed');
    $new_sub->update;

    my $renewal_from_cc_sub = setup_dd_test_report({
        'Subscription_Type' => 2,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '154323',
        'uprn' => '1654321',
    });
    $renewal_from_cc_sub->state('unconfirmed');
    $renewal_from_cc_sub->set_extra_metadata('payerReference' => 'GGW1654321');
    $renewal_from_cc_sub->update;

    my $sub_for_subsequent_renewal_from_cc_sub = setup_dd_test_report({
        'Subscription_Type' => 2,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '154323',
        'uprn' => '3654321',
    });
    $sub_for_subsequent_renewal_from_cc_sub->set_extra_metadata('payerReference' => 'GGW3654321');
    $sub_for_subsequent_renewal_from_cc_sub->update;

    my $sub_for_unprocessed_cancel = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '84324',
        'uprn' => '854325',
    });
    my $unprocessed_cancel = setup_dd_test_report({
        'payment_method' => 'direct_debit',
        'property_id' => '84324',
        'uprn' => '854325',
    });
    $unprocessed_cancel->state('unconfirmed');
    $unprocessed_cancel->category('Cancel Garden Subscription');
    $unprocessed_cancel->update;

    my $sub_for_processed_cancel = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54324',
        'uprn' => '654324',
    });
    my $processed_renewal = setup_dd_test_report({
        'Subscription_Type' => 2,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54324',
        'uprn' => '654324',
    });
    $processed_renewal->set_extra_metadata('dd_date' => '16/03/2021');
    $processed_renewal->update;

    my $renewal_nothing_in_echo = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '74321',
        'uprn' => '754322',
    });

    my $sub_for_cancel_nothing_in_echo = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '94324',
        'uprn' => '954324',
    });

    my $cancel_nothing_in_echo = setup_dd_test_report({
        'payment_method' => 'direct_debit',
        'property_id' => '94324',
        'uprn' => '954324',
    });
    $cancel_nothing_in_echo->state('unconfirmed');
    $cancel_nothing_in_echo->category('Cancel Garden Subscription');
    $cancel_nothing_in_echo->update;

    my $c = FixMyStreet::Cobrand::Bromley->new;
    warnings_are {
        $c->waste_reconcile_direct_debits;
    } [
        "no matching record found for Garden Subscription payment with id GGW554321\n",
        "no matching record found for Garden Subscription payment with id GGW554399\n",
        "no matching service to renew for GGW754322\n",
        "no matching record found for Garden Subscription payment with id GGW854324\n",
        "no matching record found for Garden Subscription payment with id GGW954325\n",
    ], "warns if no matching record";

    $new_sub->discard_changes;
    is $new_sub->state, 'confirmed', "New report confirmed";
    is $new_sub->get_extra_metadata('payerReference'), "GGW654321", "payer reference set";
    is $new_sub->get_extra_field_value('PaymentCode'), "GGW654321", 'correct echo payment code field';
    is $new_sub->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';

    $renewal_from_cc_sub->discard_changes;
    is $renewal_from_cc_sub->state, 'confirmed', "Renewal report confirmed";
    is $renewal_from_cc_sub->get_extra_field_value('PaymentCode'), "GGW1654321", 'correct echo payment code field';
    is $renewal_from_cc_sub->get_extra_field_value('Subscription_Type'), 2, 'Renewal has correct type';
    is $renewal_from_cc_sub->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';

    my $subsequent_renewal_from_cc_sub = FixMyStreet::DB->resultset('Problem')->search({
            extra => { like => '%uprn,T5:value,I7:3654321%' }
        },
        {
            order_by => { -desc => 'id' }
        }
    );
    is $subsequent_renewal_from_cc_sub->count, 2, "two record for subsequent renewal property";
    $subsequent_renewal_from_cc_sub = $subsequent_renewal_from_cc_sub->first;
    is $subsequent_renewal_from_cc_sub->state, 'confirmed', "Renewal report confirmed";
    is $subsequent_renewal_from_cc_sub->get_extra_field_value('PaymentCode'), "GGW3654321", 'correct echo payment code field';
    is $subsequent_renewal_from_cc_sub->get_extra_field_value('Subscription_Type'), 2, 'Renewal has correct type';
    is $subsequent_renewal_from_cc_sub->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';
    is $subsequent_renewal_from_cc_sub->get_extra_field_value('payment_method'), 'direct_debit', 'correctly marked as direct debit';

    $ad_hoc_orig->discard_changes;
    is $ad_hoc_orig->get_extra_metadata('dd_date'), "01/01/2021", "dd date unchanged ad hoc orig";

    $ad_hoc->discard_changes;
    is $ad_hoc->state, 'confirmed', "ad hoc report confirmed";
    is $ad_hoc->get_extra_metadata('dd_date'), "16/03/2021", "dd date set for ad hoc";
    is $ad_hoc->get_extra_field_value('PaymentCode'), "GGW654325", 'correct echo payment code field';
    is $ad_hoc->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';

    $ad_hoc_skipped->discard_changes;
    is $ad_hoc_skipped->state, 'unconfirmed', "ad hoc report not confirmed";

    $hidden->discard_changes;
    is $hidden->state, 'hidden', "hidden report not confirmed";

    $cc_to_ignore->discard_changes;
    is $cc_to_ignore->state, 'unconfirmed', "cc payment not confirmed";

    $cancel_nothing_in_echo->discard_changes;
    is $cancel_nothing_in_echo->state, 'hidden', 'hide already cancelled report';

    my $renewal = FixMyStreet::DB->resultset('Problem')->search({
            extra => { like => '%uprn,T5:value,I6:654322%' }
        },
        {
            order_by => { -desc => 'id' }
        }
    );

    is $renewal->count, 2, "two records for renewal property";
    my $p = $renewal->first;
    ok $p->id != $sub_for_renewal->id, "not the original record";
    is $p->get_extra_field_value('Subscription_Type'), 2, "renewal has correct type";
    is $p->get_extra_field_value('Subscription_Details_Quantity'), 2, "renewal has correct number of bins";
    is $p->get_extra_field_value('Subscription_Type'), 2, "renewal has correct type";
    is $p->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';
    is $p->state, 'confirmed';

    my $renewal_too_recent = FixMyStreet::DB->resultset('Problem')->search({
            extra => { like => '%uprn,T5:value,I6:654329%' }
        },
        {
            order_by => { -desc => 'id' }
        }
    );
    is $renewal_too_recent->count, 0, "ignore payments less that three days old";

    my $cancel = FixMyStreet::DB->resultset('Problem')->search({ extra => { like => '%uprn,T5:value,I6:654323%' } }, { order_by => { -desc => 'id' } });
    is $cancel->count, 1, "one record for cancel property";
    is $cancel->first->id, $sub_for_cancel->id, "only record is the original one, no cancellation report created";

    my $processed = FixMyStreet::DB->resultset('Problem')->search({
            extra => { like => '%uprn,T5:value,I6:654324%' }
        },
        {
            order_by => { -desc => 'id' }
        }
    );
    is $processed->count, 2, "two records for processed renewal property";

    my $ad_hoc_processed_rs = FixMyStreet::DB->resultset('Problem')->search({
            extra => { like => '%uprn,T5:value,I6:654326%' }
        },
        {
            order_by => { -desc => 'id' }
        }
    );
    is $ad_hoc_processed_rs->count, 1, "one records for processed ad hoc property";

    $unprocessed_cancel->discard_changes;
    is $unprocessed_cancel->state, 'confirmed', 'Unprocessed cancel is confirmed';
    ok $unprocessed_cancel->confirmed, "confirmed is not null";
    is $unprocessed_cancel->get_extra_metadata('dd_date'), "21/02/2021", "dd date set for unprocessed cancelled";

    $failed_new_sub->discard_changes;
    is $failed_new_sub->state, 'hidden', 'failed sub not hidden';

    warnings_are {
        $c->waste_reconcile_direct_debits;
    } [
        "no matching record found for Garden Subscription payment with id GGW554321\n",
        "no matching record found for Garden Subscription payment with id GGW554399\n",
        "no matching service to renew for GGW754322\n",
        "no matching record found for Garden Subscription payment with id GGW854324\n",
        "no matching record found for Garden Subscription payment with id GGW954325\n",
    ], "warns if no matching record";

    $failed_new_sub->discard_changes;
    is $failed_new_sub->state, 'hidden', 'failed sub still hidden on second run';
    $ad_hoc_skipped->discard_changes;
    is $ad_hoc_skipped->state, 'unconfirmed', "ad hoc report not confirmed on second run";
};

sub setup_dd_test_report {
    my $extras = shift;
    my ($report) = $mech->create_problems_for_body( 1, $body->id, 'Test', {
        category => 'Garden Subscription',
        latitude => 51.402096,
        longitude => 0.015784,
        cobrand => 'bromley',
        areas => '2482,8141',
        user => $user,
    });
    my @extras = map { { name => $_, value => $extras->{$_} } } keys %$extras;
    $report->set_extra_fields( @extras );
    $report->update;

    return $report;
}

done_testing();
