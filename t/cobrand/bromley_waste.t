use CGI::Simple;
use JSON::MaybeXS;
use Test::MockModule;
use Test::MockTime qw(:all);
use Test::Warn;
use DateTime;
use Test::Output;
use FixMyStreet::TestMech;
use FixMyStreet::SendReport::Open311;
use FixMyStreet::Script::Alerts;
use Open311::PostServiceRequestUpdates;
use List::Util 'any';
use Regexp::Common 'URI';
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Create test data
my $user = $mech->create_user_ok( 'bromley@example.com', name => 'Bromley' );
my $body = $mech->create_body_ok( 2482, 'Bromley Council', {
    can_be_devolved => 1, send_extended_statuses => 1, comment_user => $user,
    send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1,
    cobrand => 'bromley'
});
$mech->create_user_ok('superuser@example.com', is_superuser => 1, name => "Super User");
my $staffuser = $mech->create_user_ok( 'staff@example.com', name => 'Staffie', from_body => $body );
my $role = FixMyStreet::DB->resultset("Role")->create({
    body => $body, name => 'Role A', permissions => ['moderate', 'user_edit', 'report_mark_private', 'report_inspect', 'contribute_as_body'] });
$staffuser->add_to_roles($role);

my $pothole = $mech->create_contact_ok(
    body => $body,
    category => 'Pothole',
    email => 'pothole',
    send_method => 'Open311',
    endpoint => 'pothole-endpoint',
);

my $missed = $mech->create_contact_ok(
    body => $body,
    category => 'Report missed collection',
    email => 'missed',
    send_method => 'Open311',
    endpoint => 'waste-endpoint',
    extra => { type => 'waste' },
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
    category => 'Report missed collection',
    extra => {
        contributed_by => $staffuser->id,
    },
});
my $report = $reports[0];


subtest 'check footer is powered by SocietyWorks' => sub {

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        COBRAND_FEATURES => {
            waste => { bromley => 1 },
        }
    }, sub {
        $mech->get_ok('/waste');
        $mech->content_contains('href="https://www.societyworks.org/services/waste/">SocietyWorks', "Footer links to SocietyWorks when bulky waste not enabled");
    };

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        COBRAND_FEATURES => {
            waste => { bromley => 1 },
            waste_features => {
                bromley => { bulky_enabled => 1 }
            }
        }
    }, sub {
        $mech->get_ok('/waste');
        $mech->content_contains('href="https://www.societyworks.org/services/waste/">SocietyWorks', "Footer links to SocietyWorks when bulky waste enabled");
    };
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

subtest 'Updates on waste reports still have munged params' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['bromley', 'tfl'],
    }, sub {
        $report->comments->delete;

        Open311->_inject_response('/servicerequestupdates.xml', '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>43</update_id></request_update></service_request_updates>');

        $mech->log_in_ok($staffuser->email);
        $mech->host('bromley.fixmystreet.com');

        $mech->get_ok('/report/' . $report->id);

        $mech->submit_form_ok( {
                with_fields => {
                    submit_update => 1,
                    update => 'Test',
                    fms_extra_title => 'DR',
                    first_name => 'Bromley',
                    last_name => 'Council',
                },
            },
            'update form submitted'
        );

        is $report->comments->count, 1, 'comment was added';
        my $comment = $report->comments->first;
        $comment->set_extra_metadata(
            'fms_extra_resolution_code' => 207,
            'fms_extra_event_status' => 'Rejected',
        );
        $comment->update;

        $report->update({ cobrand_data => 'waste' });
        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;

        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('update_id'), undef;
        is $c->param('update_id_ext'), $comment->id;
        is $c->param('service_request_id_ext'), $report->id;
        is $c->param('public_anonymity_required'), 'FALSE';
        is $c->param('email_alerts_requested'), undef;
        is $c->param('attribute[resolution_code]'), 207;
        is $c->param('attribute[event_status]'), 'Rejected';

        $report->update({ cobrand_data => '' });
        $mech->log_out_ok;
    };
};

subtest 'check display of waste reports' => sub {
$report->update({ category => 'Other' });
    $mech->get_ok( '/report/' . $report->id );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->follow_link_ok({ text_regex => qr/Back to all reports/i });
    };
    $mech->content_like(qr{<a title="Test Test[^>]*href="/[^>]*><img[^>]*grey});
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

subtest 'check heatmap page' => sub {
    $user->update({ area_ids => [ 60705 ] });
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => { category_groups => { bromley => 1 }, heatmap => { bromley => 1 } },
    }, sub {
        $user->update({ from_body => $body->id });
        $mech->log_in_ok($user->email);
        $mech->get_ok('/dashboard/heatmap?end_date=2018-12-31');
        $mech->content_contains('Report missed collection');
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
        $mech->content_contains('A missed collection cannot be reported;');
        $mech->content_contains('please see the last collection status above.');
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
            title => 'Wrong bin (generic)',
            text => 'We could not collect your waste as it was not correctly presented.',
            resolution_code => 187,
            task_state => 'Completed',
        } });
        $mech->get_ok('/admin/templates/' . $body->id . '/new');
        $mech->submit_form_ok({ with_fields => {
            title => 'Wrong bin (refuse)',
            text => 'We could not collect your refuse waste as it was not correctly presented.',
            resolution_code => 187,
            'contacts[' . $missed->id . ']' => 1,
            task_type => 3216,
            task_state => 'Completed',
        } });
        $mech->log_out_ok;
    };

    subtest 'test reporting before/after completion' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('May, at 10:00am');
        $mech->content_contains('We could not collect your refuse waste as it was not correctly presented.');
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

    subtest 'test not using different backend template' => sub {
        my $templates = FixMyStreet::DB->resultset("ResponseTemplate")->search({ title => [ 'Wrong bin (generic)', 'Wrong bin (refuse)' ] });
        my @templates = $templates->all;
        @templates = map { $_->id } @templates;
        FixMyStreet::DB->resultset("ContactResponseTemplate")->search({ response_template_id => \@templates })->delete;
        $templates->delete;
        $mech->log_in_ok('superuser@example.com');
        $mech->get_ok('/admin/templates/' . $body->id . '/new');
        $mech->submit_form_ok({ with_fields => {
            title => 'Not repaired',
            text => 'We have decided not to repair this at this time, but will monitor.',
            resolution_code => 187,
            'contacts[' . $pothole->id . ']' => 1,
        } });
        $mech->log_out_ok;
        $mech->get_ok('/waste/12345');
        $mech->content_contains('May, at 10:00am');
        $mech->content_lacks('We have decided not to repair');
    };

    subtest 'test reporting with an existing closed event' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetEventsForObject', sub { [
            {
                ServiceId => '542',
                EventDate => { DateTime => '2020-05-18T17:00:00Z' },
                ResolvedDate => { DateTime => '2020-05-18T19:00:00Z' },
                EventTypeId => '2100',
            },
        ] } );
        set_fixed_time('2020-05-18T20:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A food waste collection has been reported as missed');
        $mech->content_lacks('Report a food waste collection');
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
        $mech->content_contains('You have a pending garden subscription');
        $mech->content_lacks('Subscribe to Green Garden Waste');
    };
};

subtest 'Checking correct renewal prices' => sub {
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('GetServiceUnitsForObject', sub {
        return [
            {
                Id => 1005,
                ServiceId => 545,
                ServiceName => 'Garden waste collection',
                ServiceTasks => { ServiceTask => {
                    Id => 405,
                    Data => { ExtensibleDatum => [ {
                        DatatypeName => 'LBB - GW Container',
                        ChildData => { ExtensibleDatum => [ {
                            DatatypeName => 'Quantity',
                            Value => 1,
                        }, {
                            DatatypeName => 'Container',
                            Value => 44,
                        } ] },
                    } ] },
                    ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                        ScheduleDescription => 'every other Monday',
                        StartDate => { DateTime => '2021-06-14T23:00:00Z' },
                        EndDate => { DateTime => '2021-07-14T23:00:00Z' },
                        NextInstance => {
                            CurrentScheduledDate => { DateTime => '2021-07-05T06:00:00Z' },
                            OriginalScheduledDate => { DateTime => '2021-07-04T23:00:00' },
                        },
                        LastInstance => {
                            OriginalScheduledDate => { DateTime => '2021-06-20T23:00:00Z' },
                            CurrentScheduledDate => { DateTime => '2021-06-21T06:00:00Z' },
                            Ref => { Value => { anyType => [ 567, 890 ] } },
                        }
                    }, {
                        StartDate => { DateTime => '2020-11-01T00:00:00Z' },
                        EndDate => { DateTime => '2021-06-15T22:59:59Z' },
                        LastInstance => {
                            OriginalScheduledDate => { DateTime => '2021-06-20T23:00:00Z' },
                            CurrentScheduledDate => { DateTime => '2021-06-21T06:00:00Z' },
                            Ref => { Value => { anyType => [ 567, 890 ] } },
                        },
                        NextInstance => {
                            CurrentScheduledDate => { DateTime => '2021-07-05T06:00:00Z' },
                            OriginalScheduledDate => { DateTime => '2021-07-04T23:00:00' },
                        },
                    } ] },
                } },
            }
        ];
    });
    set_fixed_time('2021-06-10T12:00:00Z');

    for my $test (
    {
        config => { start_date => '2020-01-29 00:00'},
        data => {
            renewal_text => '£20.00 per bin per year',
            test_text => 'Renewal price picks up higher cost when renewal date after price rise day',
        },
    },
    {
        config => { start_date => '2021-07-14 00:00'},
        data => {
            renewal_text => '£20.00 per bin per year',
            test_text => 'Renewal price picks up higher cost when renewal date on price rise day',
        },
    },
    {
        config => { start_date => '2021-07-15 00:00'},
        data => {
            renewal_text => '£10.00 per bin per year',
            test_text => 'Renewal price picks up lower cost when renewal date before price rise day',
        },
    }) {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'bromley',
            COBRAND_FEATURES => {
                payment_gateway => { bromley => { ggw_cost => [
                    { start_date => '2019-02-27 00:00', cost => 1000 },
                    { start_date => $test->{config}->{start_date}, cost => 2000 },
                    ]}},
                echo => { bromley => { sample_data => 1 } },
                waste => { bromley => 1 }
            },
        }, sub {
            subtest $test->{data}{test_text} => sub {
                $mech->get_ok('/waste/12345/garden_renew');
                $mech->content_contains($test->{data}->{renewal_text}, $test->{data}->{test_text});
            };
        };
    }
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
            my ($waste, $event_state_id, $resolution_code, $event_type_id) = split /-/, $external_id;
            return SOAP::Result->new(result => {
                EventStateId => $event_state_id,
                EventTypeId => $event_type_id || '2104',
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
                    { CoreState => 'Closed', Name => 'Closed', Id => 15007 },
                ] } },
            });
        } else {
            is $method, 'UNKNOWN';
        }
    });

    my $comment_count = 0;
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
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, $comment_count, 'No new update';
        is $report->state, 'confirmed', 'No state change';

        # Test general enquiry closed
        $report->update({ external_id => 'waste-15007--2148' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, ++$comment_count, 'No new update';
        is $report->state, 'closed', 'State change to fixed';
        $report->update({ state => 'confirmed' }); # Reset back

        $report->update({ external_id => 'waste-15003-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, $comment_count, 'No new update';
        is $report->state, 'confirmed', 'No state change';

        $report->update({ external_id => 'waste-15003-123' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state action scheduled, Allocated to Crew/;
        $report->discard_changes;
        is $report->comments->count, ++$comment_count, 'A new update';
        my $update = FixMyStreet::DB->resultset('Comment')->order_by('-id')->first;
        is $update->text, 'This has been allocated';
        is $report->state, 'action scheduled', 'A state change';

        $report->update({ external_id => 'waste-15003-123' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Latest update matches fetched state/;
        $report->discard_changes;
        is $report->comments->count, $comment_count, 'No new update';
        is $report->state, 'action scheduled', 'State unchanged';

        $report->update({ external_id => 'waste-15004-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state fixed - council, Completed/;
        $report->discard_changes;
        is $report->comments->count, ++$comment_count, 'A new update';
        is $report->state, 'fixed - council', 'Changed to fixed';

        $report->update({ state => 'action scheduled', external_id => 'waste-15004-201' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state fixed - council, Completed/;
        $report->discard_changes;
        is $report->comments->count, ++$comment_count, 'A new update';
        is $report->state, 'fixed - council', 'Changed to fixed';

        $reports[1]->update({ state => 'fixed - council' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/^$/, 'No open reports';

        $report->update({ external_id => 'waste-15005-205', state => 'confirmed' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state unable to fix, Inclement Weather/;
        $report->discard_changes;
        is $report->comments->count, ++$comment_count, 'A new update';
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

        $in = $mech->echo_notify_xml('waste-15005-XXX', 2104, 15006, 207);
        $mech->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $mech->res->code, 200, 'OK response, even though event does not exist';
        is $report->comments->count, $comment_count, 'No new update';

        $in = $mech->echo_notify_xml('waste-15005-205', 2104, 15006, 207, 'FMS-%%%');
        my $report_id = $report->id;
        $in =~ s/%%%/$report_id/;

        $mech->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        #$report->update({ external_id => 'waste-15005-205', state => 'confirmed' });
        is $report->comments->count, ++$comment_count, 'A new update';
        $report->discard_changes;
        is $report->state, 'closed', 'A state change';

        my $comment = FixMyStreet::DB->resultset('Comment')->search(undef, { order_by => { -desc => 'id' } })->first;
        is $comment->get_extra_metadata('fms_extra_event_status'), 'Rejected';
        is $comment->get_extra_metadata('fms_extra_resolution_code'), 'Duplicate';
        FixMyStreet::App->log->enable('info');
    };
};

for my $test (
    {
        config => {
            ggw_cost => 2000,
            pro_rata_weekly => 86,
            pro_rata_minimum => 1586,
        },
        data => {
            four_days => '1586',
            one_week => '1586',
            two_weeks => '1672',
            two_and_a_half_weeks => '1672',
            twenty_five_weeks => '3650',
            fifty_one_weeks => '5886',
        }
    },
    {
        config => {
            ggw_cost => 2000,
            pro_rata_weekly => [{ start_date => '2020-05-11 00:00', cost => '86'}, {start_date => '2021-01-01 00:00', cost => '107.7'}, {start_date => '2024-05-11 00:00', cost => '100'}],
            pro_rata_minimum => [{ start_date => '2020-05-11 00:00', cost => '1586'}, {start_date => '2021-01-01 00:00', cost => '1500'}, {start_date => '2024-05-11 00:00', cost => '100'}],
        },
        data => {
            four_days => '1500',
            one_week => '1500',
            two_weeks => '1608',
            two_and_a_half_weeks => '1608',
            twenty_five_weeks => '4085',
            fifty_one_weeks => '6885',
        }
    }
) {

    subtest 'check pro-rata calculation' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'bromley',
            COBRAND_FEATURES => {
                payment_gateway => {
                    bromley => $test->{config}
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
                    expected => $test->{data}->{four_days},
                    desc => '4 days remaining',
                },
                {
                    year => 2021,
                    month => 2,
                    day => 26,
                    expected => $test->{data}->{one_week},
                    desc => 'one week remaining',
                },
                {
                    year => 2021,
                    month => 3,
                    day => 5,
                    expected => $test->{data}->{two_weeks},
                    desc => 'two weeks remaining',
                },
                {
                    year => 2021,
                    month => 3,
                    day => 8,
                    expected => $test->{data}->{two_and_a_half_weeks},
                    desc => 'two and a half weeks remaining',
                },
                {
                    year => 2021,
                    month => 8,
                    day => 19,
                    expected => $test->{data}->{twenty_five_weeks},
                    desc => '25 weeks remaining',
                },
                {
                    year => 2022,
                    month => 2,
                    day => 14,
                    expected => $test->{data}->{fifty_one_weeks},
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
};

subtest 'check direct debit reconcilliation' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            payment_gateway => {
                bromley => {
                }
            }
        },
    }, sub {
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
    my $ad_hoc_skipped_ref = "LBB-" . $ad_hoc_skipped->id . "-954325";
    $ad_hoc_skipped->state('unconfirmed');
    $ad_hoc_skipped->update;

    my $hidden = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54399',
        'uprn' => '554399',
    });
    my $hidden_ref = "LBB-" . $hidden->id . "-554399";
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
    my $renewal_from_cc_sub_ref = "LBB-" . $renewal_from_cc_sub->id . "-1654321";
    $renewal_from_cc_sub->state('unconfirmed');
    $renewal_from_cc_sub->set_extra_metadata('payerReference' => $renewal_from_cc_sub_ref);
    $renewal_from_cc_sub->update;

    my $sub_for_subsequent_renewal_from_cc_sub = setup_dd_test_report({
        'Subscription_Type' => 2,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '154323',
        'uprn' => '3654321',
    });
    my $sub_for_subsequent_renewal_from_cc_sub_ref = "LBB-" . $sub_for_subsequent_renewal_from_cc_sub->id . "-3654321";
    $sub_for_subsequent_renewal_from_cc_sub->set_extra_metadata('payerReference' => $sub_for_subsequent_renewal_from_cc_sub_ref);
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

    my $renewal_nothing_in_echo = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Subscription_Details_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '74321',
        'uprn' => '754322',
    });
    my $renewal_nothing_in_echo_ref = "LBB-" . $renewal_nothing_in_echo->id . "-754322";

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
                            PayerReference => "LBB-" . $new_sub->id . "-654321",
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
                            PayerReference => $hidden_ref,
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
                            PayerReference => "LBB-" . $ad_hoc_processed->id . "-654326",
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
                            PayerReference => $renewal_nothing_in_echo_ref,
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
                            PayerReference => $sub_for_subsequent_renewal_from_cc_sub_ref,
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
                            PayerReference => $renewal_from_cc_sub_ref,
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
                            PayerReference => "LBB-" . $ad_hoc->id . "-654325",
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
                            PayerReference => $ad_hoc_skipped_ref,
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
                                    Reference => "LBB-" . $unprocessed_cancel->id . "-854325",
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
    $sub_for_renewal->set_extra_metadata(payerReference => 'GGW654322');
    $sub_for_renewal->update;

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
    $processed_renewal->set_extra_metadata(payerReference => 'GGW654324');
    $processed_renewal->update;

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
    $cancel_nothing_in_echo->set_extra_metadata(payerReference => 'GGW954324');
    $cancel_nothing_in_echo->update;

    my $warnings = [
        "\n",
        "looking at payment GGW554321 for £10 on 16/03/2021\n",
        "category: Garden Subscription (1)\n",
        "is a new/ad hoc\n",
        "no matching record found for Garden Subscription payment with id GGW554321\n",
        "done looking at payment GGW554321\n",
        "\n",
        "looking at payment $hidden_ref for £10 on 16/03/2021\n",
        "category: Garden Subscription (1)\n",
        "extra query is {payerReference: $hidden_ref\n",
        "is a new/ad hoc\n",
        "looking at potential match " . $hidden->id . "\n",
        "potential match is a dd payment\n",
        "potential match type is 1\n",
        "found matching report " . $hidden->id . " with state hidden\n",
        "no matching record found for Garden Subscription payment with id $hidden_ref\n",
        "done looking at payment $hidden_ref\n",
        "\n",
        "looking at payment $renewal_nothing_in_echo_ref for £10 on 16/03/2021\n",
        "category: Garden Subscription (2)\n",
        "extra query is {payerReference: $renewal_nothing_in_echo_ref\n",
        "is a renewal\n",
        "looking at potential match " . $renewal_nothing_in_echo->id . " with state confirmed\n",
        "is a matching new report\n",
        "no matching service to renew for $renewal_nothing_in_echo_ref\n",
        "\n",
        "looking at payment GGW854324 for £10 on 16/03/2021\n",
        "category: Garden Subscription (2)\n",
        "is a renewal\n",
        "no matching record found for Garden Subscription payment with id GGW854324\n",
        "done looking at payment GGW854324\n",
        "\n",
        "looking at payment $ad_hoc_skipped_ref for £10 on 16/03/2021\n",
        "category: Garden Subscription (1)\n",
        "extra query is {payerReference: $ad_hoc_skipped_ref\n",
        "is a new/ad hoc\n",
        "looking at potential match " . $ad_hoc_skipped->id . "\n",
        "potential match is a dd payment\n",
        "potential match type is 3\n",
        "no matching record found for Garden Subscription payment with id $ad_hoc_skipped_ref\n",
        "done looking at payment $ad_hoc_skipped_ref\n",
    ];

    my $c = FixMyStreet::Cobrand::Bromley->new;
    warnings_are {
        $c->waste_reconcile_direct_debits({ dry_run => 1 });
    } [
        "running in dry_run mode, no records will be created or updated\n",
        @$warnings
    ], "warns if no matching record";

    $new_sub->discard_changes;
    is $new_sub->state, 'unconfirmed', "New report not confirmed after dry run";
    $renewal_from_cc_sub->discard_changes;
    is $renewal_from_cc_sub->state, 'unconfirmed', "Renewal report not confirmed after dry run";
    $ad_hoc->discard_changes;
    is $ad_hoc->state, 'unconfirmed', "ad hoc report not confirmed after dry run";
    $cancel_nothing_in_echo->discard_changes;
    is $cancel_nothing_in_echo->state, 'unconfirmed', 'already cancelled report not hidded after dry_run';
    $unprocessed_cancel->discard_changes;
    is $unprocessed_cancel->state, 'unconfirmed', 'Unprocessed cancel is not confirmed after dry_run';

    warnings_are {
        $c->waste_reconcile_direct_debits;
    } $warnings, "warns if no matching record";

    $new_sub->discard_changes;
    is $new_sub->state, 'confirmed', "New report confirmed";
    is $new_sub->get_extra_metadata('payerReference'), "LBB-" . $new_sub->id . "-654321", "payer reference set";
    is $new_sub->get_extra_field_value('PaymentCode'), "LBB-" . $new_sub->id . "-654321", 'correct echo payment code field';
    is $new_sub->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';

    $renewal_from_cc_sub->discard_changes;
    is $renewal_from_cc_sub->state, 'confirmed', "Renewal report confirmed";
    is $renewal_from_cc_sub->get_extra_field_value('PaymentCode'), $renewal_from_cc_sub_ref, 'correct echo payment code field';
    is $renewal_from_cc_sub->get_extra_field_value('Subscription_Type'), 2, 'From CC Renewal has correct type';
    is $renewal_from_cc_sub->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'From CC Renewal has correct container type';
    is $renewal_from_cc_sub->get_extra_field_value('service_id'), 545, 'Renewal has correct service id';
    is $renewal_from_cc_sub->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';

    my $subsequent_renewal_from_cc_sub = FixMyStreet::DB->resultset('Problem')->search({
            extra => { '@>' => encode_json({ _fields => [ { name => "uprn", value => "3654321" } ] }) },
        },
    )->order_by('-id');
    is $subsequent_renewal_from_cc_sub->count, 2, "two record for subsequent renewal property";
    $subsequent_renewal_from_cc_sub = $subsequent_renewal_from_cc_sub->first;
    is $subsequent_renewal_from_cc_sub->state, 'confirmed', "Renewal report confirmed";
    is $subsequent_renewal_from_cc_sub->get_extra_field_value('PaymentCode'), $sub_for_subsequent_renewal_from_cc_sub_ref, 'correct echo payment code field';
    is $subsequent_renewal_from_cc_sub->get_extra_field_value('Subscription_Type'), 2, 'Subsequent Renewal has correct type';
    is $subsequent_renewal_from_cc_sub->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'Subsequent Renewal has correct container type';
    is $subsequent_renewal_from_cc_sub->get_extra_field_value('service_id'), 545, 'Subsequent Renewal has correct service id';
    is $subsequent_renewal_from_cc_sub->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';
    is $subsequent_renewal_from_cc_sub->get_extra_field_value('payment_method'), 'direct_debit', 'correctly marked as direct debit';

    $ad_hoc_orig->discard_changes;
    is $ad_hoc_orig->get_extra_metadata('dd_date'), "01/01/2021", "dd date unchanged ad hoc orig";

    $ad_hoc->discard_changes;
    is $ad_hoc->state, 'confirmed', "ad hoc report confirmed";
    is $ad_hoc->get_extra_metadata('dd_date'), "16/03/2021", "dd date set for ad hoc";
    is $ad_hoc->get_extra_field_value('PaymentCode'), "LBB-" . $ad_hoc->id . "-654325", 'correct echo payment code field';
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
            extra => { '@>' => encode_json({ _fields => [ { name => "uprn", value => "654322" } ] }) },
        },
    )->order_by('-id');

    is $renewal->count, 2, "two records for renewal property";
    my $p = $renewal->first;
    ok $p->id != $sub_for_renewal->id, "not the original record";
    is $p->get_extra_field_value('Subscription_Type'), 2, "renewal has correct type";
    is $p->get_extra_field_value('Subscription_Details_Quantity'), 2, "renewal has correct number of bins";
    is $p->get_extra_field_value('Subscription_Type'), 2, "renewal has correct type";
    is $p->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'renewal has correct container type';
    is $p->get_extra_field_value('service_id'), 545, 'renewal has correct service id';
    is $p->get_extra_field_value('property_id'), '54321';
    is $p->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';
    is $p->get_extra_metadata('dd_date'), '16/03/2021';
    is $p->get_extra_metadata('payerReference'), 'GGW654322';
    is $p->cobrand_data, 'waste';
    is $p->state, 'confirmed';
    is $p->title, 'Garden Subscription - Renew';
    is $p->areas, ',2482,8141,';

    # Assume that this has now had to go through as New, rather than Renewal
    # Should not be any extra warning output later on
    $p->update_extra_field({ name => "Subscription_Type", value => 1 });
    $p->title("Garden Subscription - New");
    $p->update;

    my $renewal_too_recent = FixMyStreet::DB->resultset('Problem')->search({
            extra => { '@>' => encode_json({ _fields => [ { name => "uprn", value => "654329" } ] }) },
        },
    )->order_by('-id');
    is $renewal_too_recent->count, 0, "ignore payments less that three days old";

    my $cancel = FixMyStreet::DB->resultset('Problem')->search({
        extra => { '@>' => encode_json({ _fields => [ { name => "uprn", value => "654323" } ] }) },
    })->order_by('-id');
    is $cancel->count, 1, "one record for cancel property";
    is $cancel->first->id, $sub_for_cancel->id, "only record is the original one, no cancellation report created";

    my $processed = FixMyStreet::DB->resultset('Problem')->search({
            extra => { '@>' => encode_json({ _fields => [ { name => "uprn", value => "654324" } ] }) },
        },
    )->order_by('-id');
    is $processed->count, 2, "two records for processed renewal property";

    my $ad_hoc_processed_rs = FixMyStreet::DB->resultset('Problem')->search({
            extra => { '@>' => encode_json({ _fields => [ { name => "uprn", value => "654326" } ] }) },
        },
    )->order_by('-id');
    is $ad_hoc_processed_rs->count, 1, "one records for processed ad hoc property";

    $unprocessed_cancel->discard_changes;
    is $unprocessed_cancel->state, 'confirmed', 'Unprocessed cancel is confirmed';
    ok $unprocessed_cancel->confirmed, "confirmed is not null";
    is $unprocessed_cancel->get_extra_metadata('dd_date'), "21/02/2021", "dd date set for unprocessed cancelled";

    $failed_new_sub->discard_changes;
    is $failed_new_sub->state, 'unconfirmed', 'failed sub not hidden, no reference to match';

    warnings_are {
        $c->waste_reconcile_direct_debits;
    } $warnings, "warns if no matching record";

    $failed_new_sub->discard_changes;
    is $failed_new_sub->state, 'unconfirmed', 'failed sub still unconfirmed on second run';
    $ad_hoc_skipped->discard_changes;
    is $ad_hoc_skipped->state, 'unconfirmed', "ad hoc report not confirmed on second run";

    warnings_are {
        $c->waste_reconcile_direct_debits({ reference => $hidden_ref });
    } [
        "\n",
        "looking at payment $hidden_ref for £10 on 16/03/2021\n",
        "category: Garden Subscription (1)\n",
        "extra query is {payerReference: $hidden_ref\n",
        "is a new/ad hoc\n",
        "looking at potential match " . $hidden->id . "\n",
        "potential match is a dd payment\n",
        "potential match type is 1\n",
        "found matching report " . $hidden->id . " with state hidden\n",
        "no matching record found for Garden Subscription payment with id $hidden_ref\n",
        "done looking at payment $hidden_ref\n",
    ], "warns if given reference";

    $hidden->update({ state => 'fixed - council' });
    warnings_are {
        $c->waste_reconcile_direct_debits({ reference => $hidden_ref, force_renewal => 1 });
    } [
        "\n",
        "looking at payment $hidden_ref for £10 on 16/03/2021\n",
        "category: Garden Subscription (1)\n",
        "Overriding type 1 to renew\n",
        "extra query is {payerReference: $hidden_ref\n",
        "is a renewal\n",
        "looking at potential match " . $hidden->id . " with state fixed - council\n",
        "is a matching new report\n",
        "no matching service to renew for $hidden_ref\n",
    ], "gets past the first stage if forced renewal";

    stdout_like {
        $c->waste_reconcile_direct_debits({ reference => $renewal_nothing_in_echo_ref, force_when_missing => 1, verbose => 1 });
    } qr/looking at payment $renewal_nothing_in_echo_ref for £10 on 16\/03\/2021.*?category: Garden Subscription \(2\).*?is a renewal.*?looking at potential match @{[$renewal_nothing_in_echo->id]}.*?is a matching new report.*?created new confirmed report.*?done looking at payment/s, "creates a renewal if forced to";
};

};

subtest 'Garden Waste new subs alert update emails contain bin collection days link' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
    }, sub {
        $mech->clear_emails_ok;

        my $property_id = '54323';

        my $new_sub = setup_dd_test_report({ property_id => $property_id });

        my $update = FixMyStreet::DB->resultset('Comment')->find_or_create({
            problem_state => 'action scheduled',
            problem_id => $new_sub->id,
            user_id    => $staffuser->id,
            name       => 'Staff User',
            mark_fixed => 'f',
            text       => "Green bin on way",
            state      => 'confirmed',
            confirmed  => 'now()',
            anonymous  => 'f',
        });

        my $alert = FixMyStreet::DB->resultset('Alert')->create({
            user => $user,
            parameter => $new_sub->id,
            alert_type => 'new_updates',
            whensubscribed => '2021-09-27 12:00:00',
            cobrand => 'bromley',
            cobrand_data => 'waste',
        });
        $alert->confirm;

        FixMyStreet::Script::Alerts::send_updates();

        my $email = $mech->get_email;
        my $text_body = $mech->get_text_body_from_email($email);
        like $text_body, qr/Check your bin collections day/, 'has bin day link text in text part';
        my @links = $mech->get_link_from_email($email, 'get_all_links');
        my $found = any { $_ =~ m"recyclingservices\.bromley\.gov\.uk/waste/$property_id" } @links;
        ok $found, 'Found bin day URL in text part of alert email';

        my $html_body = $mech->get_html_body_from_email($email);
        like $html_body, qr/Check your bin collections day/, 'has bin day link text in HTML part';
        my @uris = $html_body =~ m/$RE{URI}/g;
        $found = any { $_ =~ m"recyclingservices\.bromley\.gov\.uk/waste/$property_id" } @uris;
        ok $found, 'Found bin day URL in HTML part of alert email';
    }
};

sub setup_dd_test_report {
    my $extras = shift;
    my ($report) = $mech->create_problems_for_body( 1, $body->id, 'Test', {
        category => 'Garden Subscription',
        latitude => 51.402092,
        longitude => 0.015783,
        cobrand => 'bromley',
        cobrand_data => 'waste',
        areas => ',2482,',
        user => $user,
    });

    $extras->{service_id} ||= 545;
    $extras->{Subscription_Details_Container_Type} ||= 44;

    my @extras = map { { name => $_, value => $extras->{$_} } } keys %$extras;
    $report->set_extra_fields( @extras );
    $report->update;

    return $report;
}

done_testing();
