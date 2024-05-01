use utf8;
use JSON::MaybeXS;
use Path::Tiny;
use Storable qw(dclone);
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use CGI::Simple;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $bin_data = decode_json(path(__FILE__)->sibling('waste_4443082.json')->slurp_utf8);
my $kerbside_bag_data = decode_json(path(__FILE__)->sibling('waste_4471550.json')->slurp_utf8);
my $above_shop_data = decode_json(path(__FILE__)->sibling('waste_4499005.json')->slurp_utf8);

my $params = {
    send_method => 'Open311',
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
};
my $merton = $mech->create_body_ok(2500, 'Merton Council', $params, { cobrand => 'merton' });
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $merton, name => 'Staff User');

sub create_contact {
    my ($params, $group, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $merton, %$params, group => [$group]);
    $contact->set_extra_metadata( type => 'waste' );
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Report missed collection', email => 'missed' }, 'Waste',
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Request new container', email => '1635' }, 'Waste',
    { code => 'uprn', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Action', required => 1, automated => 'hidden_field' },
    { code => 'Reason', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Assisted collection add', email => 'assisted' }, 'Waste',
    { code => 'Crew_Notes', description => 'Notes', required => 1, datatype => 'text' },
    { code => 'staff_form', automated => 'hidden_field' },
);
create_contact({ category => 'Assisted collection remove', email => 'assisted' }, 'Waste',
    { code => 'Crew_Notes', description => 'Notes', required => 1, datatype => 'text' },
    { code => 'staff_form', automated => 'hidden_field' },
);
create_contact({ category => 'Failure to deliver', email => 'failure' }, 'Waste',
    { code => 'Notes', description => 'Details', required => 1, datatype => 'text' },
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'merton',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { merton => {
            url => 'http://example.org/',
            bulky_service_id => 413,
            open311_endpoint => 'http://example.net/api/',
            open311_api_key => 'api_key',
        } },
        waste => { merton => 1 },
    },
    STAGING_FLAGS => {
        send_reports => 1,
    },
}, sub {
    my ($e) = shared_echo_mocks();
    subtest 'Address lookup' => sub {
        set_fixed_time('2022-09-10T12:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('2 Example Street, Merton');
        $mech->content_contains('Every Friday fortnightly');
        $mech->content_contains('Friday, 2nd September');
        $mech->content_contains('Report a mixed recycling collection as missed');
    };
    subtest 'In progress collection' => sub {
        $e->mock('GetTasks', sub { [ {
            Ref => { Value => { anyType => [ 17430692, 8287 ] } },
            State => { Name => 'Completed' },
            CompletedDate => { DateTime => '2022-09-09T16:00:00Z' }
        }, {
            Ref => { Value => { anyType => [ 17510905, 8287 ] } },
            State => { Name => 'Outstanding' },
            CompletedDate => undef
        } ] });
        set_fixed_time('2022-09-09T16:30:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr/Friday, 9th September\s+\(this collection has been adjusted from its usual time\)\s+\(In progress\)/);
        $mech->content_contains(', at  4:00pm');
        $mech->content_lacks('Report a mixed recycling collection as missed');
        $mech->content_contains('Report a non-recyclable refuse collection as missed');
        set_fixed_time('2022-09-09T19:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains(', at  4:00pm');
        $mech->content_lacks('Report a mixed recycling collection as missed');
        $mech->content_contains('Report a non-recyclable refuse collection as missed');
        set_fixed_time('2022-09-13T19:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a non-recyclable refuse collection as missed');
        $e->mock('GetTasks', sub { [] });
    };
    subtest 'Request a new bin' => sub {
        $mech->get_ok('/waste/12345/request');
        # 19 (1), 24 (1), 16 (1), 1 (1)
        $mech->submit_form_ok({ with_fields => { 'container-19' => 1 }});
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Merton, KT1 1AA\n\nReason: Damaged";
        is $report->category, 'Request new container';
        is $report->title, 'Request replacement Blue lid paper and cardboard bin (240L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('api_key'), 'KEY';
        is $cgi->param('attribute[Action]'), '3';
        is $cgi->param('attribute[Reason]'), '2';
    };
    subtest 'Test sending of reports to other endpoint' => sub {
        use_ok 'FixMyStreet::Script::Merton::SendWaste';
        Open311->_inject_response('/api/requests.xml', '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>359</service_request_id></request></service_requests>');
        my $send = FixMyStreet::Script::Merton::SendWaste->new;
        $send->send_reports;
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('api_key'), 'api_key';
        is $cgi->param('attribute[Action]'), '3';
        is $cgi->param('attribute[Reason]'), '2';
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_metadata('sent_to_crimson'), 1;
        is $report->get_extra_metadata('crimson_external_id'), "359";
        is $report->external_id, "248";
    };
    subtest 'Report a new recycling raises a bin delivery request' => sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-16' => 1 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'missing' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Merton, KT1 1AA\n\nReason: Missing";
        is $report->title, 'Request replacement Green recycling box (55L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '1';
        is $cgi->param('attribute[Reason]'), '1';
    };
    subtest 'Request new build container' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-1' => 1 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'new_build' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Merton, KT1 1AA\n\nReason: I am a new resident without a container";
        is $report->title, 'Request new Black rubbish bin (140L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '1';
        is $cgi->param('attribute[Reason]'), '4';
    };

    subtest 'Report missed collection' => sub {
        $mech->get_ok('/waste/12345/report');
        $mech->content_contains('Food waste');
        $mech->content_contains('Mixed recycling');
        $mech->content_contains('Non-recyclable Refuse');
        $mech->content_lacks('Paper and card');

        $mech->submit_form_ok({ with_fields => { 'service-2239' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('collection has been reported');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Report missed Food waste\n\n2 Example Street, Merton, KT1 1AA";
        is $report->title, 'Report missed Food waste';
    };
    subtest 'No reporting/requesting if open request' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a mixed recycling collection as missed');
        $mech->content_contains('Request a mixed recycling container');

        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventTypeId => 1635,
            Data => { ExtensibleDatum => [
                { Value => 2, DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => 1, DatatypeName => 'Action' },
                        { Value => 16, DatatypeName => 'Container Type' },
                    ] },
                },
            ] },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A mixed recycling container request has been made');
        $mech->content_contains('Report a mixed recycling collection as missed');
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-16" value="1"[^>]+disabled/s); # green

        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventTypeId => 1635,
            Data => { ExtensibleDatum => [
                { Value => 2, DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => 1, DatatypeName => 'Action' },
                        { Value => 23, DatatypeName => 'Container Type' },
                    ] },
                },
            ] },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A food waste container request has been made');
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-23" value="1"[^>]+disabled/s); # indoor
        $mech->content_like(qr/name="container-24" value="1"\s*data-toggle[^ ]*\s*>/s); # outdoor

        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 1566,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 408,
            Data => { ExtensibleDatum => [
                { Value => 1, DatatypeName => 'Container Mix' },
            ] },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A mixed recycling collection has been reported as missed');
        $mech->content_contains('Request a mixed recycling container');

        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 1566,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 408,
            Data => { ExtensibleDatum => {
                Value => 1, DatatypeName => 'Paper'
            } },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A paper and card collection has been reported as missed');

        $e->mock('GetEventsForObject', sub { [] }); # reset
    };

    $e->mock('GetServiceUnitsForObject', sub { $kerbside_bag_data });
    subtest 'No requesting a red stripe bag' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->content_lacks('"container-6" value="1"');
    };
    subtest 'Fortnightly collection can request a blue stripe bag' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-18' => 1 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Merton, KT1 1AA\n\nReason: Additional bag required";
        is $report->category, 'Request new container';
        is $report->title, 'Request new Recycling Blue Stripe Bag';
    };
    subtest 'Weekly collection cannot request a blue stripe bag' => sub {
        $e->mock('GetServiceUnitsForObject', sub { $above_shop_data });
        $mech->get_ok('/waste/12345/request');
        $mech->content_lacks('"container-18" value="1"');
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };

    subtest 'test failure to deliver' => sub {
        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventTypeId => 1635,
            Data => { ExtensibleDatum => [
                { Value => 2, DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => 1, DatatypeName => 'Action' },
                        { Value => 16, DatatypeName => 'Container Type' },
                    ] },
                },
            ] },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Report a failure to deliver a food waste container');
        $mech->follow_link_ok({ text => 'Report a failure to deliver a mixed recycling container' });
        $mech->submit_form_ok({ with_fields => { extra_Notes => 'It never turned up' } });
        $mech->submit_form_ok({ with_fields => { name => "Anne Assist", email => 'anne@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('Notes'), 'It never turned up';
        is $report->detail, "It never turned up\n\n2 Example Street, Merton, KT1 1AA";
        is $report->user->email, 'anne@example.org';
        is $report->name, 'Anne Assist';
        $e->mock('GetEventsForObject', sub { [] }); # reset
    };

    subtest 'test staff-only assisted collection form' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/enquiry?category=Assisted+collection+add&service_id=2238');
        $mech->submit_form_ok({ with_fields => { extra_Crew_Notes => 'Behind the garden gate' } });
        $mech->submit_form_ok({ with_fields => { name => "Anne Assist", email => 'anne@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('Crew_Notes'), 'Behind the garden gate';
        is $report->detail, "Behind the garden gate\n\n2 Example Street, Merton, KT1 1AA";
        is $report->user->email, 'anne@example.org';
        is $report->name, 'Anne Assist';
    };
    subtest 'test staff-only form when logged out' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/12345/enquiry?category=Assisted+collection+add&service_id=2238');
        is $mech->res->previous->code, 302;
    };
    subtest 'test assisted collection display' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Set up for assisted collection');
        my $dupe = dclone($bin_data);
        # Give the entry an assisted collection
        $dupe->[0]{Data}{ExtensibleDatum}{DatatypeName} = 'Assisted Collection';
        $dupe->[0]{Data}{ExtensibleDatum}{Value} = 1;
        $e->mock('GetServiceUnitsForObject', sub { $dupe });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('is set up for assisted collection');
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };
};

sub shared_echo_mocks {
    my $e = Test::MockModule->new('Integrations::Echo');
    $e->mock('GetPointAddress', sub {
        return {
            Id => 12345,
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.400975, Longitude => -0.19655 } },
            Description => '2 Example Street, Merton, KT1 1AA',
        };
    });
    $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    $e->mock('GetEventsForObject', sub { [] });
    $e->mock('GetTasks', sub { [] });
    $e->mock( 'CancelReservedSlotsForEvent', sub {
        my (undef, $guid) = @_;
        ok $guid, 'non-nil GUID passed to CancelReservedSlotsForEvent';
    } );

    return $e;
}

done_testing;
