use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use t::Mock::Tilma;
use Test::MockTime qw(:all);
use Test::MockModule;
use Test::Output;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });

use_ok 'FixMyStreet::Cobrand::Brent';

my $comment_user = $mech->create_user_ok('comment@example.org', email_verified => 1, name => 'Brent');
my $brent = $mech->create_body_ok(2488, 'Brent', {
    api_key => 'abc',
    jurisdiction => 'brent',
    endpoint => 'http://endpoint.example.org',
    send_method => 'Open311',
    comment_user => $comment_user,
}, {
    cobrand => 'brent'
});
my $contact = $mech->create_contact_ok(body_id => $brent->id, category => 'Graffiti', email => 'graffiti@example.org');
my $gully = $mech->create_contact_ok(body_id => $brent->id, category => 'Gully grid missing',
    email => 'Symology-gully', group => ['Drains and gullies']);
my $user1 = $mech->create_user_ok('user1@example.org', email_verified => 1, name => 'User 1');

$mech->create_contact_ok(body_id => $brent->id, category => 'Potholes', email => 'potholes@brent.example.org');

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $brent, %$params, extra => { type => 'waste' });
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Report missed collection', email => 'missed' });
create_contact({ category => 'Request new container', email => 'request@example.org' },
    { code => 'Container_Task_New_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Task_New_Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Container_Task_New_Actions', required => 0, automated => 'hidden_field' },
    { code => 'Container_Task_New_Notes', required => 0, automated => 'hidden_field' },
    { code => 'LastPayMethod', required => 0, automated => 'hidden_field' },
    { code => 'PaymentCode', required => 0, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
);

for my $test (
    {
        desc => 'Problem has stayed open when user reported fixed with update',
        report_status => 'confirmed',
        fields => { been_fixed => 'Yes', reported => 'No', another => 'No', update => 'Test' },
    },
    {
        desc => 'Problem has stayed open when user reported fixed without update',
        report_status => 'confirmed',
        fields => { been_fixed => 'Yes', reported => 'No', another => 'No' },
    },
    {
        desc => 'Problem has stayed fixed when user reported not fixed with update',
        report_status => 'fixed - council',
        fields => { been_fixed => 'No', reported => 'No', another => 'No', update => 'Test' },
    },
 ) { subtest "Response to questionnaire doesn't update problem state" => sub {
        my $dt = DateTime->now()->subtract( weeks => 5 );
        my $report_time = $dt->ymd . ' ' . $dt->hms;
        my $sent = $dt->add( minutes => 5 );
        my $sent_time = $sent->ymd . ' ' . $sent->hms;

        my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'Title', {
        areas => "2488", category => 'Graffiti', cobrand => 'brent', user => $user1, confirmed => $report_time,
        lastupdate => $report_time, whensent => $sent_time, state => $test->{report_status}});


        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'brent',
        }, sub {

        FixMyStreet::DB->resultset('Questionnaire')->send_questionnaires( {
            site => 'fixmystreet'
        } );

        my $email = $mech->get_email;
        my $url = $mech->get_link_from_email($email, 0, 1);
        $mech->clear_emails_ok;
        $mech->get_ok($url);
        $mech->submit_form_ok( { with_fields => $test->{fields} }, "Questionnaire submitted");
        $mech->get_ok('/report/' . $problem->id);
        $problem = FixMyStreet::DB->resultset('Problem')->find_or_create( { id => $problem->id } );
        is $problem->state, $test->{report_status}, $test->{desc};
        my $questionnaire = FixMyStreet::DB->resultset('Questionnaire')->find( {
            problem_id => $problem->id
        } );

        $questionnaire->delete;
        $problem->comments->first->delete;
        $problem->delete;
        }
    };
};

subtest "Open311 attribute changes" => sub {
    my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'Gully', {
        areas => "2488", category => 'Gully grid missing', cobrand => 'brent',
    });
    $problem->update_extra_field({ name => 'UnitID', value => '234' });
    $problem->update;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'brent',
        MAPIT_URL => 'http://mapit.uk/',
        STAGING_FLAGS => { send_reports => 1 },
        COBRAND_FEATURES => {
            anonymous_account => {
                brent => 'anonymous'
            },
        },
    }, sub {
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('attribute[UnitID]'), undef, 'UnitID removed from attributes';
        like $c->param('description'), qr/ukey: 234/, 'UnitID on gully sent across in detail';
        is $c->param('attribute[title]'), $problem->title, 'Report title passed as attribute for Open311';
    };

    $problem->delete;
};

my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'brent', 'tfl' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest "hides the TfL River Piers category" => sub {

        my $tfl = $mech->create_body_ok(2488, 'TfL');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers', email => 'tfl@example.org');

        ok $mech->host('brent.fixmystreet.com'), 'set host';
        my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.55904&longitude=-0.28168');
        is $json->{by_category}->{"River Piers"}, undef, "Brent doesn't have River Piers category";
    };
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
            my ($waste, $event_state_id, $resolution_code) = split /-/, $external_id;
            return SOAP::Result->new(result => {
                EventStateId => $event_state_id,
                EventTypeId => '943',
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

    my $report;
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

        ($report) = $mech->create_problems_for_body(1, $brent->id, 'Graffiti', {
            category => 'Graffiti',
        });
        my $cobrand = FixMyStreet::Cobrand::Brent->new;

        $report->update({ external_id => 'Echo-waste-7671-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
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
        my $in = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<Envelope>
  <Header>
    <Action>action</Action>
    <Security><UsernameToken><Username>un</Username><Password>password</Password></UsernameToken></Security>
  </Header>
  <Body>
    <NotifyEventUpdated>
      <event>
        <Guid>waste-7681-67</Guid>
        <EventTypeId>943</EventTypeId>
        <EventStateId>7672</EventStateId>
        <ResolutionCodeId>100</ResolutionCodeId>
      </event>
    </NotifyEventUpdated>
  </Body>
</Envelope>
EOF
        my $mech2 = $mech->clone;
        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 3, 'A new update';
        $report->discard_changes;
        is $report->state, 'not responsible', 'A state change';
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { brent => { sample_data => 1 } },
        waste => { brent => 1 },
        anonymous_account => { brent => 'anonymous' },
        payment_gateway => { brent => {
            cc_url => 'http://example.com',
            request_cost => 5000,
        } },
    },
}, sub {
    my $echo = shared_echo_mocks();
    $echo->mock('GetServiceUnitsForObject' => sub {
    return [
        {
            Id => 1001,
            ServiceId => 262,
            ServiceName => 'Domestic Dry Recycling Collection',
            ServiceTasks => { ServiceTask => {
                Id => 401,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    ScheduleDescription => 'every Wednesday',
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
            ServiceId => 265,
            ServiceName => 'Domestic Refuse Collection',
            ServiceTasks => { ServiceTask => {
                Id => 402,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    ScheduleDescription => 'every other Wednesday',
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
                    ScheduleDescription => 'every other Wednesday',
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-20T00:00:00Z' },
                        Ref => { Value => { anyType => [ 345, 678 ] } },
                    },
                } },
            } },
        }, ]
    });

    subtest 'test report missed container' => sub {
        set_fixed_time('2020-05-19T12:00:00Z'); # After sample food waste collection
        $mech->get_ok('/waste/12345');
        restore_time();
    };

    subtest 'test requesting a container' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Request a domestic dry recycling collection container');
        $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 3 } }, "Choose general rubbish bin");

        $mech->content_contains("Why do you need a replacement container?");
        $mech->content_contains("My container is damaged", "Can report damaged container");
        $mech->content_contains("My container is missing", "Can report missing container");
        $mech->content_lacks("I am a new resident without a container", "Can not request new container as new resident");
        $mech->content_lacks("I would like an extra container", "Can not request an extra container");
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' } }, "Choose damaged as replacement reason");

        $mech->content_contains("Damaged during collection");
        $mech->content_contains("Wear and tear");
        $mech->content_contains("Other damage");
        $mech->submit_form_ok({ with_fields => { 'notes_damaged' => 'collection' } });

        $mech->content_contains("Collection damage");
        $mech->submit_form_ok({ with_fields => { 'details_damaged' => '' } }, "Put nothing in obligatory field");
        $mech->content_contains("Please describe how your container was damaged field is required", "Error message for empty field");
        $mech->submit_form_ok({ with_fields => { 'details_damaged' => 'Bin man brutalised my bin' } }, "Put reason in for obligatory field");
        $mech->content_contains("About you");

        $mech->back; $mech->back; $mech->back; # Going back to choose different type of damage

        $mech->submit_form_ok({ with_fields => { 'notes_damaged' => 'wear' } });
        $mech->content_contains("About you", "No notes required for wear and tear damage");
        $mech->back;

        $mech->submit_form_ok({ with_fields => { 'notes_damaged' => 'other' } });
        $mech->content_contains("About you", "No notes required for other damage");

        for my $test ({ id => 23, name => 'food waste caddy'}, { id => 11, name => 'Recycling bin (blue bin)'}) {
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
            $mech->submit_form_ok({ with_fields => { 'container-choice' => $test->{id} } }, "Choose " . $test->{name});
            $mech->content_contains("Why do you need a replacement container?");
            $mech->content_contains("My container is damaged", "Can report damaged container");
            $mech->content_contains("My container is missing", "Can report missing container");
            $mech->content_contains("I am a new resident without a container", "Can request new container as new resident");
            $mech->content_contains("I would like an extra container", "Can request an extra container");
            for my $radio (
                    {choice => 'new_build', type => 'new resident needs container'},
                    {choice => 'damaged', type => 'damaged container'},
                    {choice => 'missing', type => 'missing container'},
                    {choice => 'extra', type => 'extra container'}
            ) {
                $mech->submit_form_ok({ with_fields => { 'request_reason' => $radio->{choice} } });
                $mech->content_contains("About you", "No further questions for " . $radio->{type});
                $mech->back;
            }
        }

        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
        $mech->submit_form_ok({ with_fields => { 'process' => 'summary' } });
        $mech->content_contains('Your container request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->get_extra_field_value('Container_Task_New_Container_Type'), '11::11';
        is $report->get_extra_field_value('Container_Task_New_Actions'), '2::1';
        is $report->get_extra_field_value('Container_Task_New_Notes'), '';
    };

    subtest 'test paying for a missing refuse container' => sub {
        my $sent_params;
        my $pay = Test::MockModule->new('Integrations::SCP');

        $pay->mock(pay => sub {
            my $self = shift;
            $sent_params = shift;
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

        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 3 } }, "Choose general rubbish bin");
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'missing' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
        $mech->content_contains('grey bin');
        $mech->content_contains('Test McTest');
        $mech->content_contains($user1->email);
        $mech->content_contains("Continue to payment");
        my $mech2 = $mech->clone;
        $mech2->submit_form_ok({ with_fields => { process => 'summary' } });

        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Request new container', 'correct category on report';
        is $new_report->title, 'Request new General rubbish bin (grey bin)', 'correct title on report';
        is $new_report->get_extra_field_value('payment'), 5000, 'correct payment';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        #is $new_report->get_extra_field_value('Container_Task_New_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Task_New_Container_Type'), 3, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Task_New_Actions'), 1, 'correct container request action';
        is $new_report->state, 'unconfirmed', 'report not confirmed';
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        is $sent_params->{items}[0]{amount}, 5000, 'correct amount used';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_field_value('LastPayMethod'), 2, 'correct echo payment method field';
        is $new_report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
        $new_report->delete;
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

done_testing();
