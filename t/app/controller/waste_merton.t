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

my $bin_data = decode_json(path(__FILE__)->sibling('waste_merton_4443082.json')->slurp_utf8);
my $kerbside_bag_data = decode_json(path(__FILE__)->sibling('waste_4471550.json')->slurp_utf8);
my $above_shop_data = decode_json(path(__FILE__)->sibling('waste_merton_4499005.json')->slurp_utf8);

my $params = {
    send_method => 'Open311',
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
    cobrand => 'merton',
};
my $merton = $mech->create_body_ok(2500, 'Merton Council', $params);
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $merton, name => 'Staff User');

sub create_contact {
    my ($params, $group, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $merton, %$params, group => [$group]);
    $contact->set_extra_metadata( type => 'waste' );
    $contact->set_extra_fields(@extra);
    $contact->update;
}

create_contact({ category => 'Report missed collection', email => 'missed' }, 'Waste',
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Request new container', email => '3129' }, 'Waste',
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Action', required => 1, automated => 'hidden_field' },
    { code => 'Reason', required => 1, automated => 'hidden_field' },
    { code => 'Notes', required => 0, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Assisted collection add', email => '3200-add' }, 'Waste',
    { code => 'Exact_Location', description => 'Notes', required => 0, datatype => 'text' },
    { code => 'Start_Date', required => 0, automated => 'hidden_field' },
    { code => 'staff_form', automated => 'hidden_field' },
);
create_contact({ category => 'Assisted collection remove', email => '3200-remove' }, 'Waste',
    { code => 'Exact_Location', description => 'Notes', required => 0, datatype => 'text' },
    { code => 'End_Date', required => 0, automated => 'hidden_field' },
    { code => 'staff_form', automated => 'hidden_field' },
);
create_contact({ category => 'Assisted collection change', email => 'assisted' }, 'Waste',
    { code => 'Replace_Crew_Notes', description => 'Replace Crew Notes', required => 1, datatype => 'text' },
    { code => 'staff_form', automated => 'hidden_field' },
);
create_contact({ category => 'Failure to deliver', email => '3141' }, 'Waste',
    { code => 'Notes', description => 'Details', required => 1, datatype => 'text' },
);
create_contact({ category => 'Request additional collection', email => 'additional' }, 'Waste',
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Bin not returned', email => '3135' }, 'Waste',
    { code => 'Notes', description => 'Details', required => 0, datatype => 'text' },
);
create_contact({ category => 'Waste spillage', email => '3227' }, 'Waste',
    { code => 'Notes', description => 'Details', required => 0, datatype => 'text' },
);

my $no_echo_contact = $mech->create_contact_ok(
    body => $merton,
    category => 'No Echo',
    group => ['waste'],
    email => 'noecho@example.org',
);
$no_echo_contact->set_extra_metadata( type => 'waste' );

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
        waste_calendar_links => { merton => {
            'timebanded-2' => 'Timebanded-2',
            'houses-friday-A' => 'houses-friday-A',
        } },
        payment_gateway => { merton => {
            request_cost_2 => 1800,
            request_cost_3 => 1800,
            request_cost_28 => 1800,
            request_cost_39 => 1800,
            ggw_cost => 1901,
            ggw_new_bin_cost => 234,
            adelante => {
                cost_code => 'cost_code',
                cost_code_admin_fee => 'admin_code',
                request_cost_code => 'req_code',
            }
        } },
    },
    STAGING_FLAGS => {
        send_reports => 1,
    },
}, sub {
    my ($e) = shared_echo_mocks();

    my $sent_params = {};
    my $call_params = {};
    my $pay = Test::MockModule->new('Integrations::Adelante');

    $pay->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $call_params = shift;
    });
    $pay->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        $pay->original('pay')->($self, $sent_params);
        return {
            UID => '12345',
            Link => 'http://example.org/faq',
        };
    });
    my $query_return = { Status => 'Authorised', PaymentID => '54321' };
    $pay->mock(query => sub {
        my $self = shift;
        $sent_params = shift;
        return $query_return;
    });

    subtest 'Address lookup' => sub {
        set_fixed_time('2022-09-10T12:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('2 Example Street, Merton');
        $mech->content_contains('Every other Friday');
        $mech->content_contains('Friday 2 September');
        $mech->content_contains('Report a missed mixed recycling collection');
        $mech->content_contains('houses-friday-A');
        $mech->content_contains('Blue lidded wheelie bin');
    };

    subtest 'Schedule 2 property' => sub {
        my $dupe = dclone($bin_data);
        # Give the entry schedule 2 tasks
        foreach (@$dupe) {
            $_->{ServiceId} = 1069;
        }
        $e->mock('GetServiceUnitsForObject', sub { $dupe });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('not available at this property');
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
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
        $mech->content_like(qr/Friday 9 September\s+\(this collection has been adjusted from its usual time\)\s+\(In progress\)/);
        $mech->content_like(qr/, at  4:00p\.?m\.?/);
        $mech->content_lacks('Report a missed mixed recycling collection');
        $mech->content_contains('Report a missed non-recyclable waste collection');
        set_fixed_time('2022-09-09T19:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr/, at  4:00p\.?m\.?/);
        $mech->content_lacks('Report a missed mixed recycling collection');
        $mech->content_contains('Report a missed non-recyclable waste collection');
        set_fixed_time('2022-09-13T19:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a missed non-recyclable waste collection');
        $e->mock('GetTasks', sub { [] });
    };
    subtest 'Request a new bin' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-27' => 1 }});
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->uprn, 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Merton, KT1 1AA\n\nReason: Damaged\n\n1x Blue lid paper and cardboard bin (240L) to deliver\n\n1x Blue lid paper and cardboard bin (240L) to collect";
        is $report->category, 'Request new container';
        is $report->title, 'Request replacement Blue lid paper and cardboard bin (240L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('api_key'), 'KEY';
        is $cgi->param('attribute[Action]'), '2::1';
        is $cgi->param('attribute[Reason]'), '4::4';
    };

    subtest 'Report a new recycling raises a bin delivery request' => sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-12' => 1 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'missing' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->uprn, 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Merton, KT1 1AA\n\nReason: Missing\n\n1x Green recycling box (55L) to deliver";
        is $report->title, 'Request replacement Green recycling box (55L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '1';
        is $cgi->param('attribute[Reason]'), '1';
    };

    subtest 'Request new build container' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->content_lacks('Other containers', 'Does not contain "other" section if not staff');
        $mech->content_lacks('Blue lid paper and cardboard bin (360L)', 'Container not associated with service not available ');
        $mech->submit_form_ok({ with_fields => { 'container-3' => 1 } });
        $mech->content_lacks('request_reason_text', 'Staff only field for extra information absent');
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'new_build' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_lacks('No payment to be taken');
        $mech->waste_submit_check({ with_fields => { process => 'summary' } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{reference}, 'LBM-RNC-' . $new_report->id;
        is $sent_params->{items}[0]{amount}, 1800, 'correct amount used';
        is $sent_params->{items}[0]{cost_code}, 'req_code';
        check_extra_data_pre_confirm($new_report);
        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        check_extra_data_post_confirm($new_report);
        $mech->content_contains('request has been sent');

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->uprn, 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Merton, KT1 1AA\n\nReason: I am a new resident without a container\n\n1x Black rubbish bin (240L) to deliver";
        is $report->title, 'Request new Black rubbish bin (240L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '1';
        is $cgi->param('attribute[Reason]'), '6';
    };

    subtest 'Request new garden container' => sub {
        my $dupe = dclone($bin_data);
        $dupe->[3]{ServiceId} = 1082;
        $dupe->[3]{ServiceTasks}{ServiceTask}{ServiceTaskLines} = { ServiceTaskLine => [ {
                ScheduledAssetQuantity => 1,
                AssetTypeId => 1915,
                StartDate => { DateTime => '2022-03-30T00:00:00Z' },
                EndDate => { DateTime => '2023-03-30T00:00:00Z' },
            } ] };
        $e->mock('GetServiceUnitsForObject', sub { $dupe });
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-39' => 1 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'new_build' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->waste_submit_check({ with_fields => { process => 'summary' } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        is $sent_params->{items}[0]{reference}, 'LBM-RNC-' . $new_report->id;
        is $sent_params->{items}[0]{amount}, 1800, 'correct amount used';
        is $sent_params->{items}[0]{cost_code}, 'admin_code';
        check_extra_data_pre_confirm($new_report);

        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };

    subtest 'Request both refuse and garden container' => sub {
        my $dupe = dclone($bin_data);
        $dupe->[2]{ServiceId} = 1082;
        $dupe->[2]{ServiceTasks}{ServiceTask}[0]{ServiceTaskLines} = { ServiceTaskLine => [ {
                ScheduledAssetQuantity => 1,
                AssetTypeId => 1915,
                StartDate => { DateTime => '2022-03-30T00:00:00Z' },
                EndDate => { DateTime => '2023-03-30T00:00:00Z' },
            } ] };
        $e->mock('GetServiceUnitsForObject', sub { $dupe });
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-3' => 1, 'container-39' => 1 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'new_build' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->waste_submit_check({ with_fields => { process => 'summary' } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        is $sent_params->{items}[0]{reference}, 'LBM-RNC-' . $new_report->id;
        is $sent_params->{items}[0]{amount}, 1800, 'correct amount used';
        is $sent_params->{items}[0]{cost_code}, 'req_code';
        my $other_id = $new_report->get_extra_metadata('grouped_ids')->[0];
        is $sent_params->{items}[1]{reference}, 'LBM-RNC-' . $other_id;
        is $sent_params->{items}[1]{amount}, 1800, 'correct amount used';
        is $sent_params->{items}[1]{cost_code}, 'admin_code';
        check_extra_data_pre_confirm($new_report);

        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };

    subtest 'Request new build container as staff' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-3' => 1, 'quantity-3' => 2 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'new_build', 'request_reason_text' => 'Large household' x 10 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('No payment to be taken');
        $mech->submit_form_ok({ with_fields => { payment_method => 'waived' } });
        $mech->content_contains('Explanation field is required');
        $mech->submit_form_ok({ with_fields => { payment_method => 'waived', payment_explanation => 'Paid in cash' } });
        $mech->content_contains('request has been sent');

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->uprn, 1000000002;
        is $report->detail, "Quantity: 2\n\n2 Example Street, Merton, KT1 1AA\n\nReason: I am a new resident without a container\n\n1x Black rubbish bin (240L) to deliver\n\nAdditional details: " . "Large household" x 10;
        is $report->title, 'Request new Black rubbish bin (240L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '1::1';
        is $cgi->param('attribute[Notes]'), 'Large household' x 10;
        is $cgi->param('attribute[Reason]'), '6::6';
        is $cgi->param('attribute[contributed_by]'), $staff_user->email;
        $mech->log_out_ok;
    };

    subtest 'Request large paper bin as staff' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/request');
        $mech->content_contains('Other containers', 'Staff can select from list of containers not associated with a service');
        $mech->content_contains('Blue lid paper and cardboard bin (360L)', 'Domestic service available');
        $mech->content_lacks('Communal Refuse bin (240L)', 'Communal service not available');
        $mech->submit_form_ok({ with_fields => { 'container-28' => 1, 'quantity-28' => 2 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'new_build', 'request_reason_text' => 'Large household' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->waste_submit_check({ with_fields => { process => 'summary' } });

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        is $sent_params->{items}[0]{reference}, 'LBM-RNC-' . $report->id;
        is $sent_params->{items}[0]{amount}, 3600, 'correct amount used';
        is $sent_params->{items}[0]{cost_code}, 'req_code';
        check_extra_data_pre_confirm($report, payment_method => 'csc');
        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        check_extra_data_post_confirm($report);
        $mech->content_contains('request has been sent');
        is $report->uprn, 1000000002;
        is $report->get_extra_field_value('service_id'), 1075;
        is $report->detail, "Quantity: 2\n\n2 Example Street, Merton, KT1 1AA\n\nReason: I am a new resident without a container\n\n1x Blue lid paper and cardboard bin (360L) to deliver\n\nAdditional details: Large household";
        is $report->title, 'Request new Blue lid paper and cardboard bin (360L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '1::1';
        is $cgi->param('attribute[Reason]'), '6::6';
        $mech->log_out_ok;
    };

    subtest 'Request larger refuse bin' => sub {
        my $dupe = dclone($bin_data);
        $dupe->[3]{Data}{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value} = '2';
        $e->mock('GetServiceUnitsForObject', sub { $dupe });
        $mech->get_ok('/waste/12345');
        $mech->follow_link_ok({ text => 'Request a larger refuse container' });
        $mech->submit_form_ok({ with_fields => { medical_condition => 'No' } });
        $mech->submit_form_ok({ with_fields => { how_many => 'less5' } });
        $mech->content_contains('Sorry, you are not eligible');
        $mech->back;
        $mech->submit_form_ok({ with_fields => { how_many => '5more' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->back;
        $mech->back;
        $mech->back;
        $mech->submit_form_ok({ with_fields => { medical_condition => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { how_much => 'less1' } });
        $mech->content_contains('How many people live');
        $mech->back;
        $mech->submit_form_ok({ with_fields => { how_much => '3more' } });
        $mech->content_contains('Clinical waste');
        $mech->back;
        $mech->submit_form_ok({ with_fields => { how_much => '1or2' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('name="goto" value="medical_condition"');
        $mech->waste_submit_check({ with_fields => { process => 'summary' } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{reference}, 'LBM-RNC-' . $new_report->id;
        is $sent_params->{items}[0]{amount}, 1800, 'correct amount used';
        is $sent_params->{items}[0]{cost_code}, 'req_code';
        check_extra_data_pre_confirm($new_report);
        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        check_extra_data_post_confirm($new_report);
        $mech->content_contains('request has been sent');
        $mech->content_contains('consider your request');

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->uprn, 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Merton, KT1 1AA\n\n1x Black rubbish bin (240L) to deliver\n\n1x Black rubbish bin (180L) to collect";
        is $report->title, 'Request exchange for Black rubbish bin (240L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '2::1';
        is $cgi->param('attribute[Reason]'), '9::9';
        is $cgi->param('attribute[service_id]'), 1067;
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };

    subtest 'Report missed collection' => sub {
        $mech->get_ok('/waste/12345/report');
        $mech->content_contains('Food waste');
        $mech->content_contains('Mixed recycling');
        $mech->content_contains('Non-recyclable waste');
        $mech->content_lacks('Paper and card');

        $mech->submit_form_ok({ with_fields => { 'service-1084' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Thank you for reporting a missed collection');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->uprn, 1000000002;
        is $report->detail, "Report missed Food waste\n\n2 Example Street, Merton, KT1 1AA";
        is $report->title, 'Report missed Food waste';
    };
    subtest 'No reporting/requesting if open request' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a missed mixed recycling collection');
        $mech->content_contains('Request a mixed recycling container');

        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventTypeId => 3129,
            Data => { ExtensibleDatum => [
                { Value => 2, DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => 1, DatatypeName => 'Action' },
                        { Value => 12, DatatypeName => 'Container Type' },
                    ] },
                },
            ] },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A mixed recycling container request has been made');
        $mech->content_contains('Report a missed mixed recycling collection');
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-12" value="1"[^>]+disabled/s); # green

        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventTypeId => 3129,
            Data => { ExtensibleDatum => [
                { Value => 2, DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => 1, DatatypeName => 'Action' },
                        { Value => 44, DatatypeName => 'Container Type' },
                    ] },
                },
            ] },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A food waste container request has been made');
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-44" value="1"[^>]+disabled/s); # indoor
        $mech->content_like(qr/name="container-46" value="1"\s*data-toggle[^ ]*\s*>/s); # outdoor

        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 3145,
            EventStateId => 0,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 1071,
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A missed mixed recycling collection has been reported');
        $mech->content_contains('Request a mixed recycling container');

        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 3145,
            EventStateId => 0,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 1075,
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('only be reported within 2 working days');
        $mech->content_lacks('A paper and card collection has been reported as missed');

        $e->mock('GetEventsForObject', sub { [] }); # reset
    };

    $e->mock('GetServiceUnitsForObject', sub { $kerbside_bag_data });
    set_fixed_time('2022-10-13T19:00:00Z');
    subtest 'Fortnightly collection can request a blue stripe bag' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-22' => 1 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->uprn, 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Merton, KT1 1AA\n\nReason: Additional bag required\n\n1x Recycling Blue Stripe Bag to deliver";
        is $report->category, 'Request new container';
        is $report->title, 'Request new Recycling Blue Stripe Bag';
    };
    subtest 'Weekly collection cannot request a blue stripe bag' => sub {
        my $dupe = dclone($kerbside_bag_data);
        # Make it a weekly collection by changing original date
        $dupe->[2]{ServiceTasks}{ServiceTask}{ServiceTaskSchedules}{ServiceTaskSchedule}{LastInstance}{OriginalScheduledDate}{DateTime} = '2022-10-09T23:00:00Z';
        $e->mock('GetServiceUnitsForObject', sub { $dupe });
        $mech->get_ok('/waste/12345/request');
        $mech->content_lacks('container-22');
    };
    subtest 'Above-shop address' => sub {
        $e->mock('GetServiceUnitsForObject', sub { $above_shop_data });
        $mech->get_ok('/waste/12345');
        $mech->content_contains( 'Put your bags out between 6pm and 8pm',
            'Property has time-banded message' );
        $mech->content_contains( 'color: #BD63D1', 'Property has purple sack' );
        $mech->content_contains( 'color: #3B3B3A', 'Property has black sack' );
        $mech->content_lacks('Request a non-recyclable waste container');
        $mech->content_contains( 'You need to buy your own black sacks',
            'Property has black sack message' );
        $mech->content_contains('Timebanded-2', 'Correct calendar');

        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };

    set_fixed_time('2022-09-13T19:00:00Z');
    subtest 'test failure to deliver' => sub {
        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventTypeId => 3129,
            Data => { ExtensibleDatum => [
                { Value => 2, DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => 1, DatatypeName => 'Action' },
                        { Value => 12, DatatypeName => 'Container Type' },
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

    subtest 'test report a problem' => sub {
        FixMyStreet::Script::Reports::send();
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a problem with a non-recyclable waste collection', 'Can report a problem with non-recyclable waste');
        $mech->content_contains('Report a problem with a food waste collection', 'Can report a problem with food waste');
        my $root = HTML::TreeBuilder->new_from_content($mech->content());
        my $panel = $root->look_down(id => 'panel-1075');
        is $panel->as_text =~ /.*Please note that missed collections can only be reported.*/, 1, "Paper and card past reporting deadline";
        $mech->content_lacks('Report a problem with a paper and card collection', 'Can not report a problem with paper and card as past reporting deadline');
        $mech->follow_link_ok({ text => 'Report a problem with a non-recyclable waste collection' });
        $mech->submit_form_ok( { with_fields => { category => 'Bin not returned' } });
        $mech->submit_form_ok( { with_fields => { extra_Notes => 'Hello' } });
        $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } });
        $mech->submit_form_ok( { with_fields => { submit => '1' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('Notes'), 'Hello';
        is $report->detail, "Hello\n\n2 Example Street, Merton, KT1 1AA", "Details of report contain information about problem";
        is $report->user->email, 'schmoe@example.org', 'User details added to report';
        is $report->name, 'Joe Schmoe', 'User details added to report';
        is $report->category, 'Bin not returned', "Correct category";
        FixMyStreet::Script::Reports::send();
        my $email = $mech->get_email;
        is $mech->get_text_body_from_email($email) =~ /Your report about the problem with your bin collection has been made to the council/, 1, 'Other problem text included in email';
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('api_key'), 'KEY';
        is $cgi->param('attribute[Notes]'), 'Hello';
        $mech->get_ok('/waste/12345');
        $mech->follow_link_ok({ text => 'Report a problem with a non-recyclable waste collection' });
        $mech->submit_form_ok( { with_fields => { category => 'Waste spillage' } });
        $mech->submit_form_ok( { with_fields => { extra_Notes => 'Rubbish left on driveway' } });
        $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } });
        $mech->submit_form_ok( { with_fields => { submit => '1' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->category, 'Waste spillage', "Correct category";
        is $report->get_extra_field_value('Notes'), 'Rubbish left on driveway', "Notes filled in";
        is $report->detail, "Rubbish left on driveway\n\n2 Example Street, Merton, KT1 1AA", "Details of report contain information about problem";
        is $report->user->email, 'schmoe@example.org', 'User details added to report';
        is $report->name, 'Joe Schmoe', 'User details added to report';
        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        $email = $mech->get_email;
        is $mech->get_text_body_from_email($email) =~ /Your report about the problem with your bin collection has been made to the council/, 1, 'Other problem text included in email';
        $req = Open311->test_req_used;
        $cgi = CGI::Simple->new($req->content);
        is $cgi->param('api_key'), 'KEY';
        is $cgi->param('attribute[Notes]'), 'Rubbish left on driveway', "Notes added to open311 data for Echo";
    };

    subtest 'test report a problem with already open event' => sub {
        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 3135, # Bin not returned
            EventStateId => 0,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 1067,
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->follow_link_ok({ text => 'Report a problem with a non-recyclable waste collection' });
        $mech->content_like(qr/value="Bin not returned"\s+disabled/s);
        $e->mock('GetEventsForObject', sub { [] }); # reset
    };

    subtest 'test staff-only additional collection' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345');
        $mech->follow_link_ok({ text => 'Request an additional food waste collection' });
        $mech->content_contains('Paper and card'); # Normally not there, see missed test above
        $mech->submit_form_ok({ with_fields => { 'service-1084' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => "Anne Assist", email => 'anne@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('additional collection has been requested');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->uprn, 1000000002;
        is $report->detail, "Request additional Food waste collection\n\n2 Example Street, Merton, KT1 1AA";
        is $report->title, 'Request additional Food waste collection';
    };

    subtest 'test staff-only additional collection when there is already one' => sub {
        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventTypeId => 3160,
            EventStateId => 0,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 1084,
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Request an additional food waste collection');
        $mech->content_contains('An additional collection request has been made');
        $mech->get_ok('/waste/12345/report?additional=1');
        $mech->content_lacks('Food waste');
        $e->mock('GetEventsForObject', sub { [] });
    };

    subtest 'test staff-only assisted collection add form' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/enquiry?category=Assisted+collection+add&service_id=1067');
        $mech->submit_form_ok({ with_fields => { extra_Exact_Location => 'Behind the garden gate' } });
        $mech->submit_form_ok({ with_fields => { name => "Anne Assist", email => 'anne@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('Exact_Location'), 'Behind the garden gate';
        is $report->detail, "Behind the garden gate\n\n2 Example Street, Merton, KT1 1AA";
        is $report->user->email, 'anne@example.org';
        is $report->name, 'Anne Assist';
    };
    subtest 'test staff-only assisted collection change form' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/enquiry?category=Assisted+collection+change&service_id=1067');
        $mech->submit_form_ok({ with_fields => { extra_Replace_Crew_Notes => 'Behind the garden gate' } });
        $mech->submit_form_ok({ with_fields => { name => "Anne Assist", email => 'anne@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('Replace_Crew_Notes'), 'Behind the garden gate';
        is $report->detail, "Behind the garden gate\n\n2 Example Street, Merton, KT1 1AA";
        is $report->user->email, 'anne@example.org';
        is $report->name, 'Anne Assist';
    };
    subtest 'test staff-only form when logged out' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/12345/enquiry?category=Assisted+collection+add&service_id=1067');
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

sub get_report_from_redirect {
    my $url = shift;

    return ('', '', '') unless $url;

    my ($report_id, $token) = ( $url =~ m#/(\d+)/([^/]+)$# );
    my $new_report = FixMyStreet::DB->resultset('Problem')->find( {
            id => $report_id,
    });

    return undef unless $new_report->get_extra_metadata('redirect_id') eq $token;
    return ($token, $new_report, $report_id);
}

sub check_extra_data_pre_confirm {
    my $report = shift;
    ok $report, "report passed to check_extra_data_pre_confirm";

    my %params = (
        payment_method => 'credit_card',
        state => 'unconfirmed',
        @_
    );
    $report->discard_changes;
    is $report->category, 'Request new container';
    is $report->get_extra_field_value('payment_method'), $params{payment_method}, 'correct payment method on report';
    is $report->state, $params{state}, 'report state correct';
}

sub check_extra_data_post_confirm {
    my ($report, $pay_method) = @_;
    $pay_method ||= 2;
    ok $report, "report passed to check_extra_data_post_confirm";

    $report->discard_changes;
    is $report->state, 'confirmed', 'report confirmed';
    is $report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
}

done_testing;
