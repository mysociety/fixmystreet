use Test::MockTime qw(:all);
use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Test::MockModule;
use Test::Output;
use Test::Warn;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

use_ok 'FixMyStreet::Cobrand::Brent';

my $super_user = $mech->create_user_ok('superuser@example.com', is_superuser => 1, name => "Super User");
my $comment_user = $mech->create_user_ok('comment@example.org', email_verified => 1, name => 'Brent');
my $brent = $mech->create_body_ok(2488, 'Brent Council', {
    api_key => 'abc',
    jurisdiction => 'brent',
    endpoint => 'http://endpoint.example.org',
    send_method => 'Open311',
    comment_user => $comment_user,
    send_extended_statuses => 1,
    cobrand => 'brent'
});

my $user1 = $mech->create_user_ok(
    'user1@example.org',
    email_verified => 1,
    name           => 'User 1',
    phone          => '44 07 999 999 999',
    phone_verified => 1,
);
my $role = FixMyStreet::DB->resultset("Role")->create({
    body => $brent,
    name => 'Role',
    permissions => ['moderate', 'user_edit', 'view_dashboard'],
});
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $brent, name => 'Staff User');
$staff_user->user_roles->find_or_create({ role_id => $role->id });

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $brent, %$params, extra => { type => 'waste' });
    $contact->set_extra_fields(
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Report missed collection', email => 'Echo-missed' });
create_contact({ category => 'Request new container', email => 'request@example.org',
    extra => { anonymous_allowed => 1 } },
    { code => 'Container_Request_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Request_Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Container_Request_Action', required => 0, automated => 'hidden_field' },
    { code => 'Container_Request_Notes', required => 0, automated => 'hidden_field' },
    { code => 'Container_Request_Reason', required => 0, automated => 'hidden_field' },
    { code => 'service_id', required => 0, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
    { code => 'request_referral', required => 0, automated => 'hidden_field' },
    { code => 'request_how_long_lived', required => 0, automated => 'hidden_field' },
    { code => 'request_ordered_previously', required => 0, automated => 'hidden_field' },
    { code => 'request_contamination_reports', required => 0, automated => 'hidden_field' },
    { code => 'request_property_people', required => 0, automated => 'hidden_field' },
    { code => 'request_property_type', required => 0, automated => 'hidden_field' },
    { code => 'request_property_nappies', required => 0, automated => 'hidden_field' },
    { code => 'request_property_general_waste_bins', required => 0, automated => 'hidden_field' },
    { code => 'request_property_largest_general_waste_bin', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'Assisted collection add', email => 'Echo-assisted' },
    { code => 'Notes', description => 'Additional notes', required => 0, datatype => 'text' },
    { code => 'staff_form', automated => 'hidden_field' },
);
create_contact({ category => 'Garden Subscription', email => 'Echo-garden' },
    { code => 'uprn', required => 1, automated => 'hidden_field' },
    { code => 'property_id', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 0, automated => 'hidden_field' },
    { code => 'Paid_Collection_Container_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Paid_Collection_Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Container_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'current_containers', required => 1, automated => 'hidden_field' },
    { code => 'new_containers', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
    { code => 'pro_rata', required => 0, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
    { code => 'client_reference', required => 1, automated => 'hidden_field' },
    { code => 'Subscription_Type', required => 0, automated => 'hidden_field' },
);

create_contact({ category => 'Staff general enquiry', email => 'general@brent.gov.uk' },
    { code => 'Notes', description => 'Please put your question in here for a general enquiry', required => 1, datatype => 'text' },
    { code => 'staff_form', automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
);

create_contact({ category => 'Additional collection', email => 'general@brent.gov.uk' },
    { code => 'Notes', description => 'Please add your notes here', required => 1, datatype => 'text' },
    { code => 'staff_form', automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1 },
}, sub {
    subtest "garden report includes right payment information in open311" => sub {
        my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'title', {
            category => 'Garden Subscription',
            areas => '2488',
            extra => { payment_reference => 'reference' },
        });

        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('attribute[PaymentCode]'), 'reference';
        $problem->delete;
    };

};

for my $test (
    {
        desc => 'No commas when only resolution coded',
        resolution_code => 60,
        task_type => '',
        task_state => '',
        result => 60,
    },
    {
        desc => 'Commas in full waste details',
        resolution_code => 60,
        task_type => 20,
        task_state => 40,
        result => '60,20,40',
    },
    {
        desc => 'Commas if only task_state ',
        resolution_code => '',
        task_type => '',
        task_state => 40,
        result => ',,40',
    },
) {
    $mech->log_in_ok($super_user->email);
    subtest 'Brent templates provide external_status_code for non-waste reports' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'brent',
    }, sub {
        $mech->get_ok('/admin/templates/' . $brent->id . '/new');
        $mech->submit_form_ok({ with_fields => {
            title => 'We are investigating your report',
            text => 'We are now looking into your report and will update you soon.',
            resolution_code => $test->{resolution_code},
            task_type => $test->{task_type},
            task_state => $test->{task_state},
        } });
        my $template = $brent->response_templates->first;
        is($template->external_status_code, $test->{result}, $test->{desc});
        $template->delete;
        };
    };
    $mech->log_out_ok;
};

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

subtest 'push updating of reports' => sub {
    my $integ = Test::MockModule->new('SOAP::Lite');
    $integ->mock(call => sub {
        my ($cls, @args) = @_;
        my $method = $args[0]->name;
        if ($method eq 'GetEvent') {
            my ($key, $type, $value) = ${$args[3]->value}->value;
            my $external_id = ${$value->value}->value->value;
            my ($waste, $event_state_id, $resolution_code, $event_type) = split /-/, $external_id;
            $event_type ||= '943';
            return SOAP::Result->new(result => {
                EventStateId => $event_state_id,
                EventTypeId => $event_type,
                LastUpdatedDate => { OffsetMinutes => 60, DateTime => '2020-06-24T14:00:00Z' },
                ResolutionCodeId => $resolution_code,
            });
        } elsif ($method eq 'GetEventType') {
            return SOAP::Result->new(result => {
                Workflow => { States => { State => [
                    { CoreState => 'New', Name => 'New', Id => 7671 },
                    { CoreState => 'Cancelled', Name => 'Rejected ', Id => 7672,
                      ResolutionCodes => { StateResolutionCode => [
                        { ResolutionCodeId => 48, Name => 'Duplicate' },
                        { ResolutionCodeId => 100, Name => 'No Access' },
                      ] } },
                    { CoreState => 'Pending', Name => 'Accepted', Id => 7673 },
                    { CoreState => 'Pending', Name => 'Allocated to Crew', Id => 7679 },
                    { CoreState => 'Closed', Name => 'Completed ', Id => 7680 },
                    { CoreState => 'Closed', Name => 'Not Completed', Id => 7681,
                      ResolutionCodes => { StateResolutionCode => [
                        { ResolutionCodeId => 67, Name => 'Nothing Found' },
                        { ResolutionCodeId => 31, Name => 'Breakdown' },
                        { ResolutionCodeId => 14, Name => 'Inclement weather conditions ' },
                      ] } },
                    { CoreState => 'Pending', Name => 'Re-Open', Id => 14683 },
                ] } },
            });
        } else {
            is $method, 'UNKNOWN';
        }
    });

    my ($report, $alert);
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'brent',
        COBRAND_FEATURES => {
            echo => { brent => { url => 'https://www.example.org/' } },
            #waste => { brent => 1 }
        },
    }, sub {
        $brent->response_templates->create({
            title => 'Allocated title', text => 'This has been allocated',
            'auto_response' => 1, state => 'in progress',
        });

        my $report2;
        ($report, $report2) = $mech->create_problems_for_body(2, $brent->id, 'Graffiti', {
            category => 'Graffiti',
        });
        # Set last update to before the time of the first update we've mocked.
        $report->update({ lastupdate => DateTime->new(year => 2020, month => 06, day => 23, hour => 15) });
        my $report_id = $report->id;
        my $cobrand = FixMyStreet::Cobrand::Brent->new;

        $alert = FixMyStreet::DB->resultset('Alert')->create({
            alert_type => 'new_updates',
            parameter  => $report->id,
            confirmed  => 1,
            user_id    => $report->user->id,
        });

        $report2->update({ external_id => 'Symology-123' });
        $report->update({ external_id => 'Echo-waste-7671-' });
        stdout_is {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } "Fetching data for report $report_id\n";
        $report->discard_changes;
        is $report->comments->count, 0, 'No new update';
        is $report->state, 'confirmed', 'No state change';

        $report->update({ external_id => 'Echo-waste-7679-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state in progress, Allocated to Crew/;
        $report->discard_changes;
        is $report->comments->count, 1, 'A new update';
        my $update = $report->comments->first;
        is $update->text, 'This has been allocated';
        is $report->state, 'in progress', 'A state change';

        $report->update({ external_id => 'Echo-waste-7681-67' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state unable to fix, Nothing Found/;
        $report->discard_changes;
        is $report->comments->count, 2, 'A new update';
        is $report->state, 'unable to fix', 'Changed to no further action';

        $update = $report->comments->order_by('-id')->first;
        my $sent = FixMyStreet::DB->resultset("AlertSent")->search({ alert_id => $alert->id, parameter => $update->id })->first;
        is $sent, undef;

        $report->update({ external_id => 'Echo-waste-7680--1159', state => 'confirmed' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state fixed - council, Completed/;
        $report->discard_changes;
        is $report->comments->count, 3, 'A new update';
        is $report->state, 'fixed - council', 'Changed to fixed';
        $report->update({ external_id => 'Echo-waste-7681-67' });

        $update = $report->comments->order_by('-id')->first;
        $sent = FixMyStreet::DB->resultset("AlertSent")->search({ alert_id => $alert->id, parameter => $update->id })->first;
        isnt $sent, undef;
    };

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'brent',
        COBRAND_FEATURES => {
            echo => { brent => {
                url => 'https://www.example.org/',
                receive_action => 'action',
                receive_username => 'un',
                receive_password => 'password',
            } },
            waste => { brent => 1 }
        },
    }, sub {
        my $in = $mech->echo_notify_xml('waste-7681-67', 943, 7672, 100);
        my $mech2 = $mech->clone;
        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 4, 'A new update';
        $report->discard_changes;
        is $report->state, 'closed', 'A state change';

        my $update = $report->comments->order_by('-id')->first;
        my $sent = FixMyStreet::DB->resultset("AlertSent")->search({ alert_id => $alert->id, parameter => $update->id })->first;
        is $sent, undef;

        $report->update({ state => 'confirmed' });
        $in =~ s/943/1159/;
        $in =~ s/7672/7680/;
        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 5, 'A new update';
        $report->discard_changes;
        is $report->state, 'fixed - council', 'A state change';

        $update = $report->comments->order_by('-id')->first;
        $sent = FixMyStreet::DB->resultset("AlertSent")->search({ alert_id => $alert->id, parameter => $update->id })->first;
        isnt $sent, undef;

    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1 },
    COBRAND_FEATURES => {
        echo => { brent => { sample_data => 1 } },
        waste => { brent => 1 },
        anonymous_account => { brent => 'anonymous' },
        waste_calendar_links => { brent => {
            'wednesday-B2' => 'https://example.org/media/16420712/wednesdayweek2.pdf'
        } },
        ggw_calendar_links => { brent => {
            'monday-2' => [ {
                href => 'https://example.org/media/16420712/mondayweek2',
                text => 'Download PDF garden waste calendar',
            } ]
        } },
        payment_gateway => { brent => {
            cc_url => 'http://example.com',
            ggw_cost => 6000,
            request_cost_blue_bin => 3000,
            # request_cost_food_caddy => 500,
            cc_url => 'http://example.org/cc_submit',
            hmac => '1234',
            hmac_id => '1234',
            scpID => '1234',
        } },
        open311_email => { brent => {
            'Request new container' => 'referral@example.org',
        } },
    },
}, sub {
    my $echo = shared_echo_mocks();
    $echo->mock('GetServiceUnitsForObject' => sub {
    return [
        {
            Id => 1001,
            ServiceId => 265,
            ServiceName => 'Domestic Dry Recycling Collection',
            ServiceTasks => { ServiceTask => {
                Id => 401,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        Ref => { Value => { anyType => [ 123, 456 ] } },
                    },
                } },
            } },
        }, {
            Id => 1002,
            ServiceId => 262,
            ServiceName => 'Domestic Refuse Collection',
            ServiceTasks => { ServiceTask => {
                Id => 36384495,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    Allocation => {
                        RoundName => 'Wednesday',
                        RoundGroupName => 'Delta 12 Week 2',
                    },
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        Ref => { Value => { anyType => [ 234, 567 ] } },
                    },
                } },
            } },
        }, {
            Id => 1003,
            ServiceId => 316,
            ServiceName => 'Domestic Food Waste Collection',
            ServiceTasks => { ServiceTask => {
                Id => 403,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-04T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-04T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-21T00:00:00Z' },
                        Ref => { Value => { anyType => [ 345, 678 ] } },
                    },
                    TimeBand => {
                        Start => '07:30:00.000',
                        End => '08:30:00.000',
                    },
                } },
            } },
        }, {
            Id => '36404180',
            ServiceId => 807,
            ServiceName => 'Domestic Paper/Card Collection',
            ServiceTasks => { ServiceTask => {
                Id => 21507618,
                TaskTypeId => 4317,
                Data => '',
                ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                    Allocation => {
                        RoundName => 'Wednesday',
                        RoundGroupName => 'PaperCard07 WKB',
                    },
                    StartDate => { DateTime => '2020-03-30T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        Ref => { Value => { anyType => [ 567, 890 ] } },
                    },
                } ] },
            } }
        },{
            Id => 1004,
            ServiceId => 317,
            ServiceName => 'Garden waste collection',
            ServiceTasks => { ServiceTask => {
                Id => 405,
                TaskTypeId => 1689,
                Data => { ExtensibleDatum => [ {
                    DatatypeName => 'BRT - Paid Collection Container Quantity',
                    Value => 1,
                }, {
                    DatatypeName => 'BRT - Paid Collection Container Type',
                    Value => 1,
                } ] },
                ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                    Allocation => {
                        RoundName => 'Monday ',
                        RoundGroupName => 'Delta 04 Week 2',
                    },
                    StartDate => { DateTime => '2020-03-30T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        Ref => { Value => { anyType => [ 567, 890 ] } },
                    },
                } ] },
            } }
        }, ]
    });

    my $sent_params = {};
    my $call_params = {};

    my $pay = Test::MockModule->new('Integrations::SCP');
    $pay->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $call_params = { @_ };
    });
    $pay->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        $pay->original('pay')->($self, $sent_params);
        return {
            transactionState => 'IN_PROGRESS',
            scpReference => '12345',
            invokeResult => {
                status => 'SUCCESS',
                redirectUrl => 'http://example.org/faq'
            }
        };
    });
    $pay->mock(query => sub {
        my $self = shift;
        $sent_params = shift;
        return {
            transactionState => 'COMPLETE',
            paymentResult => {
                status => 'SUCCESS',
                paymentDetails => {
                    paymentHeader => {
                        uniqueTranId => 54321
                    }
                }
            }
        };
    });

    subtest 'test report missed container' => sub {
        set_fixed_time('2020-05-19T12:00:00Z'); # After sample food waste collection
        $mech->get_ok('/waste/12345');
        restore_time();
    };

    $mech->get_ok('/waste/12345');
    $mech->content_contains("(07:30&ndash;08:30)", 'shows time band');
    $mech->content_contains('https://example.org/media/16420712/wednesdayweek2', 'showing PDF calendar');
    $mech->content_contains('https://example.org/media/16420712/mondayweek2', 'showing green garden waste PDF calendar');
    $mech->content_contains('Every other Thursday', 'food showing right schedule');

    $mech->host('brent.fixmystreet.com');

    subtest 'test requesting a container' => sub {
        set_fixed_time('2025-01-27T12:00:00Z'); # After new general bin notice text
        $mech->log_in_ok($user1->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Request a recycling container');
        $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});

        $mech->submit_form_ok({ with_fields => { 'container-choice' => 13 } }, "Choose garden bin");
        $mech->content_contains("Why do you need a replacement container?");
        $mech->content_contains("My container is damaged", "Can report damaged container");
        $mech->content_contains("My container is missing", "Can report missing container");
        $mech->content_lacks("I am a new resident without a container", "Can request new container as new resident");
        $mech->content_lacks("I would like an extra container", "Can not request an extra container");
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' } }, "Choose damaged as replacement reason");
        $mech->content_contains("About you");

        for my $test ({ id => 11, name => 'food waste caddy'}, { id => 6, name => 'Recycling bin (blue bin)'}) {
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
            $mech->submit_form_ok({ with_fields => { 'container-choice' => $test->{id} } }, "Choose " . $test->{name});
            $mech->content_contains("Why do you need a replacement container?");
            $mech->content_contains("My container is damaged", "Can report damaged container");
            $mech->content_contains("My container is missing", "Can report missing container");
            $mech->content_contains("I am a new resident without a container", "Can request new container as new resident");
            $mech->content_contains("I would like an extra container", "Can request an extra container");
            for my $radio (
                    {choice => 'damaged', type => 'damaged container'},
                    {choice => 'missing', type => 'missing container'},
                    {choice => 'extra', type => 'extra container'}
            ) {
                $mech->submit_form_ok({ with_fields => { 'request_reason' => $radio->{choice} } });
                $mech->content_contains("About you", "No further questions for " . $radio->{type});
                $mech->back;
            }
            for my $radio (
                    {choice => 'new_build', type => 'new resident needs container'},
            ) {
                $mech->submit_form_ok({ with_fields => { 'request_reason' => $radio->{choice} } });
                $mech->content_contains("How long have you", "Extra question for " . $radio->{type});
                $mech->back;
            }
            $mech->back;
        }

        $mech->submit_form_ok({ with_fields => { 'container-choice' => 13 } }, "Choose garden bin");
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
        $mech->submit_form_ok({ with_fields => { 'process' => 'summary' } });
        $mech->content_contains('Your container request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->uprn, 1000000002;
        is $report->get_extra_field_value('Container_Request_Container_Type'), '13::13';
        is $report->get_extra_field_value('Container_Request_Action'), '2::1';
        is $report->get_extra_field_value('Container_Request_Reason'), '4::4';
        is $report->get_extra_field_value('Container_Request_Notes'), '';
        is $report->get_extra_field_value('Container_Request_Quantity'), '1::1';
        is $report->get_extra_field_value('service_id'), '317';

        FixMyStreet::Script::Reports::send();
        # No sent email, only logged email
        my $body = $mech->get_text_body_from_email;
        like $body, qr/We aim to deliver this container/;
        restore_time();
    };

    subtest 'test general waste (refuse) container requests' => sub {
        foreach ((
            # Some extra container rejection scenarios
            {
                should_be_referred => 0,
                reason => 'extra',
                property_people => 'Up to 5',
                property_nappies => 'None',
                property_general_waste_bins => '1',
                property_largest_general_waste_bin => '140L',
                # Check report detail for rejections.
                expected_report_detail => "Request automatically calculated\n\n" .
                                          "Quantity: 1\n\n" .
                                          "2 Example Street, Brent, NW2 1AA\n\n" .
                                          "Reason: I would like an extra container",
            },
            {
                should_be_referred => 0,
                reason => 'extra',
                property_people => 'Up to 5',
                property_nappies => '1 or more',
                property_general_waste_bins => '2 or more',
                property_largest_general_waste_bin => '140L',
            },
            {
                should_be_referred => 0,
                reason => 'extra',
                property_people => '6 or more',
                property_nappies => '1 or more',
                property_general_waste_bins => '1',
                property_largest_general_waste_bin => '240L',
            },
            {
                should_be_referred => 0,
                reason => 'extra',
                property_people => '6 or more',
                property_nappies => '1 or more',
                property_general_waste_bins => '1',
                property_largest_general_waste_bin => '360L',
            },
            # Some extra container referral scenarios
            {
                should_be_referred => '1',
                test_send => 1,
                user_email => 'new_user_1@example.com',
                reason => 'extra',
                property_people => '6 or more',
                property_nappies => 'None',
                property_general_waste_bins => '1',
                property_largest_general_waste_bin => '140L',
                should_be_referred => 1,
                # Check report detail for referrals.
                expected_report_detail => "Request forwarded to Brent Council by email\n\n" .
                                          "Quantity: 1\n\n" .
                                          "2 Example Street, Brent, NW2 1AA\n\n" .
                                          "Reason: I would like an extra container",
            },
            {
                should_be_referred => 1,
                test_send => 1,
                reason => 'extra',
                property_people => 'Up to 5',
                property_nappies => '1 or more',
                property_general_waste_bins => '1',
                property_largest_general_waste_bin => '140L',
            },
            # Some replacement (damaged) container rejection scenarios
            {
                should_be_referred => 0,
                reason => 'damaged',
                property_people => 'Up to 5',
                property_nappies => 'None',
                property_general_waste_bins => '2 or more',
                property_largest_general_waste_bin => '140L',
            },
            {
                should_be_referred => 0,
                reason => 'damaged',
                property_people => 'Up to 5',
                property_nappies => '1 or more',
                property_general_waste_bins => '2 or more',
                property_largest_general_waste_bin => '240L',
            },
            {
                should_be_referred => 0,
                reason => 'damaged',
                property_people => '6 or more',
                property_nappies => 'None',
                property_general_waste_bins => '2 or more',
                property_largest_general_waste_bin => '360L',
            },
            # Some replacement (damaged) container referral scenarios
            {
                should_be_referred => 1,
                test_send => 1,
                reason => 'damaged',
                property_people => 'Up to 5',
                property_nappies => 'None',
                property_general_waste_bins => '1',
                property_largest_general_waste_bin => '140L',
            },
            {
                should_be_referred => 1,
                reason => 'damaged',
                property_people => 'Up to 5',
                property_nappies => '1 or more',
                property_general_waste_bins => '1',
                property_largest_general_waste_bin => '360L',
            },
            {
                should_be_referred => 1,
                reason => 'damaged',
                property_people => 'Up to 5',
                property_nappies => '1 or more',
                property_general_waste_bins => '2 or more',
                property_largest_general_waste_bin => '140L',
            },
            {
                should_be_referred => 1,
                reason => 'damaged',
                property_people => '6 or more',
                property_nappies => '1 or more',
                property_general_waste_bins => '2 or more',
                property_largest_general_waste_bin => '360L',
            },
            # Some missing container rejection scenarios
            {
                should_be_referred => 0,
                reason => 'missing',
                property_people => 'Up to 5',
                property_nappies => 'None',
                property_general_waste_bins => '1',
                property_largest_general_waste_bin => '140L',
            },
            {
                should_be_referred => 0,
                reason => 'missing',
                property_people => '6 or more',
                property_nappies => '1 or more',
                property_general_waste_bins => '2 or more',
                property_largest_general_waste_bin => '140L',
            },
            {
                should_be_referred => 0,
                reason => 'missing',
                property_people => '6 or more',
                property_nappies => 'None',
                property_general_waste_bins => '1',
                property_largest_general_waste_bin => '240L',
            },
            # Some missing container referral scenarios
            {
                should_be_referred => 1,
                test_send => 1,
                reason => 'missing',
                property_people => 'Up to 5',
                property_nappies => 'None',
                property_general_waste_bins => 'None',
                property_largest_general_waste_bin => '140L',
            },
            {
                should_be_referred => 1,
                reason => 'missing',
                property_people => '6 or more',
                property_nappies => 'None',
                property_general_waste_bins => '1',
                property_largest_general_waste_bin => '140L',
            },
            {
                should_be_referred => 1,
                reason => 'missing',
                property_people => '6 or more',
                property_nappies => '1 or more',
                property_general_waste_bins => '1',
                property_largest_general_waste_bin => '360L',
            },
        )) {
            my $should_be_referred = $_->{should_be_referred};
            my $test_send = $_->{test_send};
            my $user_email = $_->{user_email} || $user1->email;
            my $reason = $_->{reason};
            my $people = $_->{property_people};
            my $nappies = $_->{property_nappies};
            my $bins = $_->{property_general_waste_bins};
            my $largest_bin_size = $_->{property_largest_general_waste_bin};
            my $expected_report_detail = $_->{expected_report_detail};

            my $outcome_text = $should_be_referred ? 'REFER' : 'REFUSE';


            subtest "$outcome_text | reason: $reason | people: $people | nappies: $nappies | bins: $bins | largest bin size: $largest_bin_size" => sub {
                FixMyStreet::DB->resultset('Problem')->search(
                    {
                        category => 'Request new container',
                        title => ['Request new General rubbish bin (grey bin)'],
                    }
                )->delete;
                $mech->get_ok('/waste/12345');
                $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
                $mech->submit_form_ok({ with_fields => { 'container-choice' => 16 } }, "Choose refuse bin");

                $mech->content_contains("Why do you need a replacement container?");
                $mech->content_contains("My container is damaged", "Can report damaged container");
                $mech->content_contains("I would like an extra container", "Can request an extra container");
                $mech->content_contains("My container is missing", "Can report missing container");
                $mech->content_lacks("I am a new resident without a container", "Can not request new container as new resident");

                $mech->submit_form_ok({ with_fields => { 'request_reason' => $reason } }, "Request with reason $reason");

                $mech->content_contains('Household details', "Questions for extra refuse container");
                $mech->submit_form_ok({ with_fields => { 'property_type' => 'Shared flat' } }); # Doesn't affect refusal/referral logic.
                $mech->submit_form_ok({ with_fields => { 'property_people' => $people } }, "Answer household detail questions");
                $mech->submit_form_ok({ with_fields => { 'property_nappies' => $nappies } }, "Answer household detail questions");
                $mech->submit_form_ok({ with_fields => { 'property_general_waste_bins' => $bins } }, "Answer household detail questions");
                if ($bins ne 'None') {
                    $mech->submit_form_ok({ with_fields => { 'property_largest_general_waste_bin' => $largest_bin_size } }, "Answer household detail questions");
                } else {
                    # For email test below
                    $largest_bin_size = 'none';
                }

                if ($should_be_referred) {
                    # Exit early to prevent clutter.
                    $mech->content_contains('About you', "'about you' section shown - report will be referred") or return;
                    # We onlt collect personal details if the request won't be rejected.
                    $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user_email, phone => '44 07 111 111 111' } });
                } else {
                    # Exit early to prevent clutter.
                    $mech->content_lacks('About you', "'about you' section not shown - report will be rejected") or return;
                }
                $mech->submit_form_ok({ with_fields => { 'process' => 'summary' } });

                my ($report) = FixMyStreet::DB->resultset('Problem')->search({ category => 'Request new container' })->order_by('-id')->first;
                if ($should_be_referred) {
                    is $report->get_extra_field_value('request_referral'), 1, 'Request was referred';
                    is $report->state, 'confirmed', 'Referred report in confirmed state';
                } else {
                    is $report->get_extra_field_value('request_referral'), '', 'Request was refused';
                    is $report->state, 'fixed - council', 'Refused report in fixed - council state';
                }
                if ($expected_report_detail) {
                    is $report->detail, $expected_report_detail, "Report detail is correct";
                }

                # Check post submit page text.
                if ($should_be_referred) {
                    $mech->content_contains('Your container request has been sent');
                    $mech->content_contains('let you know if your request has been approved');
                } else {
                    $mech->content_lacks('Your container request');
                    $mech->content_lacks('let you know if your request has been approved');
                    $mech->content_contains('Your property meets current general waste capacity requirements');
                }

                if ($test_send) {
                    FixMyStreet::Script::Reports::send( 0, 0, 0, $report->id );
                    my @emails = $mech->get_email;
                    my ($to_client) = grep { $_->header('To') eq 'referral@example.org' } @emails;

                    # Test we have the phone number provided in the form
                    my $plain = $mech->get_text_body_from_email($to_client);
                    my $html = $mech->get_html_body_from_email($to_client);

                    if ( $user_email eq $user1->email ) {
                        # Pre-existing user; use pretty original phone
                        like $plain, qr/\+44 7999 999999/, 'plain email contains phone';
                        like $html, qr/\+44 7999 999999/, 'html email contains phone';
                    } else {
                        like $plain, qr/44 07 111 111 111/, 'plain email contains phone';
                        like $html, qr/44 07 111 111 111/, 'html email contains phone';
                    }

                    my $action = $reason eq 'damaged' ? 'Collect\+Deliver' : 'Deliver';
                    my $reason_display = {
                        damaged => 'Damaged',
                        missing => 'Missing',
                        extra => 'Increase capacity',
                    }->{$reason};

                    like $plain, qr/Which container do you need\?: General rubbish bin \(grey bin\)/;
                    like $plain, qr/Collect or deliver\?: $action/;
                    like $plain, qr/Why do you need a replacement container\?: $reason_display/;

                    like $plain, qr/How many people \(including children\) live at your property\?: $people/;
                    like $plain, qr/How many children in nappies live at your property\?: $nappies/;
                    like $plain, qr/How many general waste bins do you currently have.*: $bins/;
                    like $plain, qr/What size is the largest general waste bin\?: $largest_bin_size/;
                    like $plain, qr/Property type: Shared flat/;
                    like $plain, qr/Referral\?: Yes/;

                    like $html, qr/Which container do you need\?:.*General rubbish bin \(grey bin\)/;
                    like $html, qr/Collect or deliver\?:.*$action/;
                    like $html, qr/Why do you need a replacement container\?:.*$reason_display/;

                    like $html, qr/How many people \(including children\) live at your property\?:.*$people/;
                    like $html, qr/How many children in nappies live at your property\?:.*$nappies/;
                    like $html, qr/How many general waste bins do you currently have.*$bins/;
                    like $html, qr/What size is the largest general waste bin\?:.*$largest_bin_size/;
                    like $html, qr/Property type:.*Shared flat/;
                    like $html, qr/Referral\?:.*Yes/;

                    $mech->clear_emails_ok;
                }

                # Check what happens if we try and raise another request.
                for my $new_reason ( qw/extra damaged missing/ ) {
                    $mech->get_ok('/waste/12345');
                    $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
                    $mech->submit_form_ok({ with_fields => { 'container-choice' => 16 } }, "Choose refuse bin");
                    $mech->submit_form_ok({ with_fields => { 'request_reason' => $new_reason } }, "Request container with reason $new_reason");
                    if ($should_be_referred) {
                        # Displays wording to indicate a recent non-refused report has already been made.
                        $mech->content_contains('We are unable to complete your request because our records show a similar container');
                    } else {
                        # Displays wording for instant refusal of the request since there is already a recent refusal.
                        $mech->content_contains('Your property meets current general waste capacity requirements');
                    }
                }
            };

            # Cleanup.
            FixMyStreet::DB->resultset('Problem')->search(
                {
                    category => 'Request new container',
                    title => ['Request new General rubbish bin (grey bin)'],
                }
            )->delete;
        }
    };

    subtest 'test requesting a container with payment' => sub {
        for my $test (
            # { id => 11, name => 'food waste caddy', service_id => 316, pence_cost => 500 },
            { id => 6, name => 'Recycling bin (blue bin)', service_id => 265, pence_cost => 3000 },
        ) {
            subtest "...a $test->{name}" => sub {
                $mech->get_ok('/waste/12345');
                $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
                $mech->submit_form_ok({ with_fields => { 'container-choice' => $test->{id} } }, "Choose " . $test->{name});
                $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' } });
                $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
                $mech->content_contains('Continue to payment');
                $mech->waste_submit_check({ with_fields => { 'process' => 'summary' } });

                my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

                is $sent_params->{items}[0]{amount}, $test->{pence_cost}, 'correct amount used';
                # The below does a similar checks to the garden test check_extra_data_pre_confirm
                is $report->category, 'Request new container', 'correct category on report';
                is $report->title, "Request new \u$test->{name}", 'correct title on report';
                is $report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
                is $report->uprn, 1000000002;
                is $report->get_extra_field_value('Container_Request_Container_Type'), join('::', $test->{id}, $test->{id});
                is $report->get_extra_field_value('Container_Request_Action'), '2::1';
                is $report->get_extra_field_value('Container_Request_Reason'), '4::4';
                is $report->get_extra_field_value('Container_Request_Notes'), '';
                is $report->get_extra_field_value('Container_Request_Quantity'), '1::1';
                is $report->get_extra_field_value('service_id'), $test->{service_id};

                is $report->state, 'unconfirmed', 'report state correct';
                is $report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

                $mech->get_ok("/waste/pay_complete/$report_id/$token");

                # The below does a similar checks to the garden test check_extra_data_post_confirm
                $report->discard_changes;
                is $report->state, 'confirmed', 'report confirmed';
                is $report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

                $mech->content_contains('Your container request has been sent');
                $mech->content_like(qr#/waste/12345"[^>]*>Show upcoming#, "contains link to bin page");

                FixMyStreet::Script::Reports::send();
                my $body = $mech->get_text_body_from_email;
                like $body, qr/We aim to deliver this container/;
                $mech->clear_emails_ok;
            };
        }
    };

    sub make_request {
        my ($test_name, $reason, $duration, $referral, $emails) = @_;
        my $full_test_name = "Making a request, $test_name, $reason" . ($duration ? ", $duration" : "");
        subtest $full_test_name => sub {
            $mech->get_ok('/waste/12345/request');
            $mech->submit_form_ok({ with_fields => { 'container-choice' => 11 } }, "Choose food caddy");
            $mech->submit_form_ok({ with_fields => { 'request_reason' => $reason } });
            $mech->submit_form_ok({ with_fields => { how_long_lived => $duration } }) if $duration;
            if ($referral eq 'refuse') {
                $mech->content_contains('referral@example.org');
                return;
            }
            $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
            # if ($referral) {
                $mech->submit_form_ok({ with_fields => { 'process' => 'summary' } });
                $mech->content_contains('Your container request has been sent');
            # } else {
            #     $mech->waste_submit_check({ with_fields => { 'process' => 'summary' } });
            # }
            my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            if (!$referral) {
                $report->update({ state => 'confirmed' }); # Fake payment
            }
            is $report->get_extra_field_value('request_referral'), $referral;
            is $report->get_extra_field_value('request_how_long_lived'), $duration;
            is $report->get_extra_field_value('request_ordered_previously'), $test_name eq 'Ordered' ? 1 : '';
            is $report->get_extra_field_value('request_contamination_reports'), $test_name eq 'Contaminated' ? 3 : '';
            FixMyStreet::Script::Reports::send();
            my @email = $mech->get_email;
            is @email, $emails;
            if ($emails == 2) {
                like $mech->get_text_body_from_email($email[0]), qr/a resident has tried to request a container/;
                like $mech->get_text_body_from_email($email[1]), qr/We aim to deliver this container/;
            } else {
                like $mech->get_text_body_from_email($email[0]), qr/We aim to deliver this container/;
            }
            $mech->clear_emails_ok;
            $report->delete;
        };
    }

    subtest 'check request referral/refusal' => sub {
        $echo->mock('GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 2936,
            ResolvedDate => { DateTime => '2024-05-17T12:00:00Z' },
            Data => { ExtensibleDatum => { ChildData => { ExtensibleDatum => {
                DatatypeName => 'Container Type',
                Value => 11,
            } } } },
        } ] } );
        make_request("Ordered", 'new_build', 'less3', 1, 2);
        make_request("Ordered", 'damaged', '', 1, 2);
        make_request("Ordered", 'missing', '', 1, 2);
        make_request("Ordered", 'extra', '', 'refuse');

        $echo->mock('GetEventsForObject', sub { [] });
        make_request("Not ordered", 'new_build', 'less3', '', 1);
        make_request("Not ordered", 'new_build', '3more', 1, 2);
        make_request("Not ordered", 'missing', '', '', 1);
        make_request("Not ordered", 'extra', '', '', 1);

        # $echo->mock('GetServiceTaskInstances', sub { [
        #     { ServiceTaskRef => { Value => { anyType => '401' } },
        #         Instances => { ScheduledTaskInfo => [
        #             { Resolution => 1148, CurrentScheduledDate => { DateTime => '2020-07-01T00:00:00Z' } },
        #             { Resolution => 1148, CurrentScheduledDate => { DateTime => '2020-07-01T00:00:00Z' } },
        #             { Resolution => 1148, CurrentScheduledDate => { DateTime => '2020-07-01T00:00:00Z' } },
        #         ] }
        #     },
        # ] });
        # make_request("Contaminated", 'missing', '', 1, 2);
        # make_request("Contaminated", 'extra', '', 'refuse');
    };

    subtest 'test staff-only assisted collection form' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Set up for assisted collection');
        $mech->get_ok('/waste/12345/enquiry?category=Assisted+collection+add&service_id=262');
        $mech->submit_form_ok({ with_fields => { extra_Notes => 'Behind the garden gate' } });
        $mech->submit_form_ok({ with_fields => { name => "Anne Assist", email => 'anne@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('enquiry has been submitted');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->detail, "Behind the garden gate\n\n2 Example Street, Brent, NW2 1AA";
        is $report->user->email, 'anne@example.org';
        is $report->name, 'Anne Assist';
    };

    subtest 'test staff-only additional collection form' => sub {
        $mech->log_in_ok($user1->email);
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Log an additional collection');
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Log an additional collection');
        $mech->get_ok('/waste/12345/enquiry?category=Additional+collection&service_id=262');
        $mech->submit_form_ok({ with_fields => { extra_Notes => 'Please do another collection for this address' } });
        $mech->submit_form_ok({ with_fields => { name => "Anne Assist", email => 'anne@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('enquiry has been submitted');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->detail, "Please do another collection for this address\n\n2 Example Street, Brent, NW2 1AA";
        is $report->user->email, 'anne@example.org';
        is $report->name, 'Anne Assist';
    };

    subtest 'test staff-only general enquiry form' => sub {
        $mech->log_in_ok($user1->email);
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Staff general enquiry');
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Staff general enquiry');
        $mech->get_ok('/waste/12345/enquiry?category=Staff+general+enquiry&service_id=265');
        $mech->submit_form_ok({ with_fields => { extra_Notes => 'Domestic rubbish often missed at this address' } });
        $mech->submit_form_ok({ with_fields => { name => "Staff User", email => 'staff@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('enquiry has been submitted');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->detail, "Domestic rubbish often missed at this address\n\n2 Example Street, Brent, NW2 1AA";
        is $report->user->email, 'staff@example.org';
        is $report->name, 'Staff User';
        is $report->get_extra_field_value('service_id'), '265';
        $report->delete;
        $report->update;
    };

    $echo->mock('GetServiceUnitsForObject' => sub {
    return [
        {
            Id => 1001,
            ServiceId => 269,
            ServiceName => 'FAS DMR Collection',
            ServiceTasks => { ServiceTask => {
                Id => 401,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    },
                } },
            } },
        }, ]
    });
    subtest 'test requesting a sack' => sub {
        # Ordered previously, but not referred
        $echo->mock('GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 2936,
            ResolvedDate => { DateTime => '2024-05-17T12:00:00Z' },
            Data => { ExtensibleDatum => { ChildData => { ExtensibleDatum => {
                DatatypeName => 'Container Type',
                Value => 8,
            } } } },
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 8 } }, "Choose sack");
        $mech->content_contains("Why do you need more sacks?");
        $mech->content_lacks("My container is damaged", "Can report damaged container");
        $mech->content_lacks("My container is missing", "Can report missing container");
        $mech->content_contains("I am a new resident without any", "Can request new container as new resident");
        $mech->content_contains("I have used all the sacks provided", "Can request more sacks");
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'new_build' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
        $mech->submit_form_ok({ with_fields => { 'process' => 'summary' } });
        $mech->content_contains('Your container request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->uprn, 1000000002;
        is $report->get_extra_field_value('Container_Request_Container_Type'), '8';
        is $report->get_extra_field_value('Container_Request_Action'), '1';
        is $report->get_extra_field_value('Container_Request_Reason'), '6';
        is $report->get_extra_field_value('Container_Request_Notes'), '';
        is $report->get_extra_field_value('Container_Request_Quantity'), '1';
        is $report->get_extra_field_value('service_id'), '269';
        is $report->get_extra_field_value('request_referral'), '';
    };
    $echo->mock('GetServiceUnitsForObject' => sub {
    return [
        {
            Id => 1004,
            ServiceId => 317,
            ServiceName => 'Garden waste collection',
            ServiceTasks => { ServiceTask => {
                Id => 405,
                TaskTypeId => 1689,
                Data => { ExtensibleDatum => [ {
                    DatatypeName => 'BRT - Paid Collection Container Quantity',
                    Value => 1,
                }, {
                    DatatypeName => 'BRT - Paid Collection Container Type',
                    Value => 1,
                } ] },
                ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                    Allocation => {
                        RoundName => 'Monday ',
                        RoundGroupName => 'Delta 04 Week 2',
                    },
                    StartDate => { DateTime => '2020-03-30T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        Ref => { Value => { anyType => [ 567, 890 ] } },
                    },
                } ] },
            } }
        }, ]
    });
    subtest 'test variation in ScheduleDescription in winter months' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('https://example.org/media/16420712/mondayweek2', 'showing green garden waste PDF calendar');
    }
};

subtest 'check direct debit reconcilliation' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'brent',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            payment_gateway => {
                brent => {
                    ggw_cost => 5000,
                }
            }
        },
    }, sub {
    set_fixed_time('2021-03-19T12:00:00Z'); # After sample food waste collection
    my $echo = Test::MockModule->new('Integrations::Echo');
    # XXX 
    $echo->mock('GetServiceUnitsForObject' => sub {
        my ($self, $id) = @_;

        if ( $id == 54321 ) {
            return [ {
                Id => 1005,
                ServiceId => 317,
                ServiceName => 'Garden waste collection',
                ServiceTasks => { ServiceTask => {
                    Id => 405,
                    Data => { ExtensibleDatum => [ {
                        DatatypeName => 'BRT - Paid Collection Container Quantity',
                        Value => 2,
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
                ServiceId => 317,
                ServiceName => 'Garden waste collection',
                ServiceTasks => { ServiceTask => {
                    Id => 405,
                    Data => { ExtensibleDatum => [ {
                        DatatypeName => 'BRT - Paid Collection Container Quantity',
                        Value => 1,
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

    my $ad_hoc = setup_dd_test_report({
        'Subscription_Type' => 3,
        'Paid_Collection_Container_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54325',
        'uprn' => '654325',
    });
    $ad_hoc->state('unconfirmed');
    $ad_hoc->update;

    my $new_sub = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Paid_Collection_Container_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54323',
        'uprn' => '654321',
    });
    $new_sub->state('unconfirmed');
    $new_sub->update;

    my $sub_for_renewal = setup_dd_test_report({
        'Subscription_Type' => 1,
        'Paid_Collection_Container_Quantity' => 2,
        'payment_method' => 'direct_debit',
        'property_id' => '54321',
        'uprn' => '654322',
    });
    $sub_for_renewal->set_extra_metadata(payerReference => 'GGW654322');
    $sub_for_renewal->update;

    my $processed_renewal = setup_dd_test_report({
        'Subscription_Type' => 2,
        'Paid_Collection_Container_Quantity' => 1,
        'payment_method' => 'direct_debit',
        'property_id' => '54324',
        'uprn' => '654324',
    });
    $processed_renewal->set_extra_metadata('dd_date' => '16/03/2021');
    $processed_renewal->set_extra_metadata(payerReference => 'GGW654324');
    $processed_renewal->update;

    my $integ = Test::MockModule->new('Integrations::AccessPaySuite');
    $integ->mock('config', sub { return { dd_sun => 'sun', dd_client_id => 'client' }; } );
    $integ->mock('call', sub {
        my ($self, $method, $url) = @_;

        if ( $url eq 'payments' ) {
        return {
            Pagination => {
                Page => 1,
                PageSize => 100,
                TotalPages => 1,
                TotalRecords => 7,
            },
            Data => [
                        {   # new sub
                            Amount => 5000,
                            CollectionDate => "2021-03-08T00:00:00",
                            Comment => "",
                            ContractId => "Contract-Guid",
                            CreatedAt => "2021-03-03T11:00:24",
                            CustomerId => "Customer-Guid",
                            DateOfCollection => "2021-03-09T00:00:00",
                            DirectDebitReference => "BRT-" . $new_sub->id . "-654321",
                            Method => "BACS",
                            Status => "Paid",
                            Type => "First Time"
                        },
                        {   # unhandled new sub
                            Amount => 5000,
                            ClientName => "London Borough of Bromley",
                            Comment => "",
                            CollectionDate => "2021-03-16T00:00:00",
                            DateOfCollection => "2021-03-16T00:00:00",
                            DirectDebitReference => "GGW554321",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "First Time",
                        },
                        {   # renewal
                            Amount => 5000,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "2021-03-16T00:00:00",
                            DateOfCollection => "2021-03-16T00:00:00",
                            DirectDebitReference => "GGW654322",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Regular",
                        },
                        {   # renewal already handled
                            Amount => 5000,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "2021-03-16T00:00:00",
                            DateOfCollection => "2021-03-16T00:00:00",
                            DirectDebitReference => "GGW654324",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Regular",
                        },
                        {   # renewal but payment too new
                            Amount => 5000,
                            CollectionDate => "2021-03-18T00:00:00",
                            Comment => "",
                            ContractId => "Contract-Guid",
                            CreatedAt => "2021-03-03T11:00:24",
                            CustomerId => "Customer-Guid",
                            DateOfCollection => "2021-03-19T00:00:00",
                            DirectDebitReference => "GGW654329",
                            Method => "BACS",
                            Status => "Paid",
                            Type => "Regular",
                        },
                        {   # renewal but nothing in fms
                            Amount => 5000,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "2021-03-16T00:00:00",
                            DateOfCollection => "2021-03-16T00:00:00",
                            DirectDebitReference => "GGW854324",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Regular",
                        },
                        {   # ad hoc
                            Comment => "WasteWorks: AdHoc payment for #" . $ad_hoc->id,
                            Amount => 5000,
                            ClientName => "London Borough of Bromley",
                            CollectionDate => "2021-03-14T00:00:00",
                            DateOfCollection => "2021-03-16T00:00:00",
                            DirectDebitReference => "BRT-" . $ad_hoc->id . "-654325",
                            ProductName => "Garden Waste",
                            Status => "Paid",
                            Type => "Regular",
                        },
                    ]
            };
        }
    });

    my $warnings = [
        "\n",
        "looking at payment GGW554321 for £5000 on 2021-03-16T00:00:00\n",
        "category: Garden Subscription (1)\n",
        "is a new/ad hoc\n",
        "no matching record found for Garden Subscription payment with id GGW554321\n",
        "trying to process the payment as if it's a renewal in case it came through wrong...\n",
        "no matching record found for Garden Subscription payment with id GGW554321\n",
        "done looking at payment GGW554321\n",
        "\n",
        "looking at payment GGW854324 for £5000 on 2021-03-16T00:00:00\n",
        "category: Garden Subscription (2)\n",
        "is a renewal\n",
        "no matching record found for Garden Subscription payment with id GGW854324\n",
        "done looking at payment GGW854324\n",
    ];

    my $c = FixMyStreet::Cobrand::Brent->new;
    warnings_are {
        $c->waste_reconcile_direct_debits({ dry_run => 1 });
    } [
        "running in dry_run mode, no records will be created or updated\n",
        @$warnings
    ], "warns if no matching record";

    $new_sub->discard_changes;
    is $new_sub->state, 'unconfirmed', "New report not confirmed after dry run";
    $ad_hoc->discard_changes;
    is $ad_hoc->state, 'unconfirmed', "ad hoc report not confirmed after dry run";

    warnings_are {
        $c->waste_reconcile_direct_debits;
    } $warnings, "warns if no matching record";

    $new_sub->discard_changes;
    is $new_sub->state, 'confirmed', "New report confirmed";
    is $new_sub->get_extra_metadata('payerReference'), "BRT-" . $new_sub->id . "-654321", "payer reference set";
    is $new_sub->get_extra_metadata('payment_reference'), "BRT-" . $new_sub->id . "-654321", 'correct echo payment code field';
    is $new_sub->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method field';

    $ad_hoc->discard_changes;
    is $ad_hoc->state, 'confirmed', "ad hoc report confirmed";
    is $ad_hoc->get_extra_metadata('dd_date'), "2021-03-16T00:00:00", "dd date set for ad hoc";
    is $ad_hoc->get_extra_metadata('payment_reference'), "BRT-" . $ad_hoc->id . "-654325", 'correct echo payment code field';
    is $ad_hoc->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method field';

    my $renewal = FixMyStreet::DB->resultset('Problem')->search({ uprn => "654322" })->order_by('-id');

    is $renewal->count, 2, "two records for renewal property";
    my $p = $renewal->first;
    ok $p->id != $sub_for_renewal->id, "not the original record";
    is $p->get_extra_field_value('Subscription_Type'), 2, "renewal has correct type";
    is $p->get_extra_field_value('Paid_Collection_Container_Quantity'), 2, "renewal has correct number of bins";
    is $p->get_extra_field_value('Paid_Collection_Container_Type'), 13, 'renewal has correct container type';
    is $p->get_extra_field_value('service_id'), 317, 'renewal has correct service id';
    is $p->get_extra_field_value('property_id'), '54321';
    is $p->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method field';
    is $p->get_extra_metadata('dd_date'), '2021-03-16T00:00:00';
    is $p->get_extra_metadata('payerReference'), 'GGW654322';
    is $p->cobrand_data, 'waste';
    is $p->state, 'confirmed';
    is $p->title, 'Garden Subscription - Renew';
    is $p->areas, ',2488,';

    # Assume that this has now had to go through as New, rather than Renewal
    # Should not be any extra warning output later on
    $p->update_extra_field({ name => "Subscription_Type", value => 1 });
    $p->title("Garden Subscription - New");
    $p->update;

    my $renewal_too_recent = FixMyStreet::DB->resultset('Problem')->search({ uprn => "654329" })->order_by('-id');
    is $renewal_too_recent->count, 0, "ignore payments less that three days old";

    my $processed = FixMyStreet::DB->resultset('Problem')->search({ uprn => "654324" })->order_by('-id');
    is $processed->count, 2, "two records for processed renewal property";

    warnings_are {
        $c->waste_reconcile_direct_debits;
    } $warnings, "warns if no matching record";
};

};

sub get_report_from_redirect {
    my $url = shift;

    my ($report_id, $token) = ( $url =~ m#/(\d+)/([^/]+)$# );
    my $new_report = FixMyStreet::DB->resultset('Problem')->find( {
            id => $report_id,
    });

    return undef unless $new_report->get_extra_metadata('redirect_id') eq $token;
    return ($token, $new_report, $report_id);
}

sub shared_echo_mocks {
    my $e = Test::MockModule->new('Integrations::Echo');
    $e->mock('GetPointAddress', sub {
        return {
            Id => 12345,
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.55904, Longitude => -0.28168 } },
            Description => '2 Example Street, Brent, NW2 1AA',
        };
    });
    $e->mock('GetEventsForObject', sub { [] });
    $e->mock('GetTasks', sub { [] });
    return $e;
}

sub setup_dd_test_report {
    my $extras = shift;
    my ($report) = $mech->create_problems_for_body( 1, $brent->id, 'Test', {
        uprn => delete $extras->{uprn},
        category => 'Garden Subscription',
        latitude => 51.55904,
        longitude => -0.28168,
        cobrand => 'brent',
        cobrand_data => 'waste',
        areas => ',2488,',
        user => $user1,
    });

    $extras->{service_id} ||= 317;
    $extras->{Paid_Collection_Container_Type} ||= 13;

    my @extras = map { { name => $_, value => $extras->{$_} } } keys %$extras;
    $report->set_extra_fields( @extras );
    $report->update;

    return $report;
}

done_testing();
