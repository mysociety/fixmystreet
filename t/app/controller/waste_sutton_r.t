use JSON::MaybeXS;
use Path::Tiny;
use Storable qw(dclone);
use Test::LongString;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Alerts;
use CGI::Simple;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;
my $sample_file = path(__FILE__)->parent->child("sample.jpg");

my $address_data = {
    Id => 12345,
    SharedRef => { Value => { anyType => '1000000002' } },
    PointType => 'PointAddress',
    PointAddressType => { Name => 'House', Id => 284 },
    Coordinates => { GeoPoint => { Latitude => 51.359723, Longitude => -0.193146 } },
    Description => '2 Example Street, Sutton, SM1 1AA',
};
my $bin_data = decode_json(path(__FILE__)->sibling('waste_sutton_4443082.json')->slurp_utf8);
my $bin_refuse_240_data = decode_json(path(__FILE__)->sibling('waste_sutton_4443082_refuse_240.json')->slurp_utf8);
my $bin_refuse_360_data = decode_json(path(__FILE__)->sibling('waste_sutton_4443082_refuse_360.json')->slurp_utf8);
my $bin_140_data = decode_json(path(__FILE__)->sibling('waste_sutton_4443082_140.json')->slurp_utf8);
my $bin_240_data = decode_json(path(__FILE__)->sibling('waste_sutton_4443082_paper_240.json')->slurp_utf8);
my $bin_360_data = decode_json(path(__FILE__)->sibling('waste_sutton_4443082_paper_360.json')->slurp_utf8);
my $kerbside_bag_data = decode_json(path(__FILE__)->sibling('waste_sutton_4471550.json')->slurp_utf8);
my $above_shop_data = decode_json(path(__FILE__)->sibling('waste_sutton_4499005.json')->slurp_utf8);
my $missed_collection_data = decode_json(path(__FILE__)->sibling('waste_sutton_4443082_missed.json')->slurp_utf8);

my $body_user = $mech->create_user_ok('systemuser@example.org');
my $params = {
    send_method => 'Open311',
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
    cobrand => 'sutton',
    comment_user => $body_user,
};
my $body = $mech->create_body_ok(2498, 'Sutton Council', $params, {
    wasteworks_config => { request_timeframe => '20 working days' }
});
my $kingston = $mech->create_body_ok(2480, 'Kingston Council', { %$params, cobrand => 'kingston' });
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');
my $user2 = $mech->create_user_ok('test2@example.net', name => 'Normal User The Second');
my $staff = $mech->create_user_ok('staff@example.net', name => 'Staff User', from_body => $body->id);
$staff->user_body_permissions->create({ body => $body, permission_type => 'report_edit' });
$staff->user_body_permissions->create({ body => $body, permission_type => 'view_dashboard' });

sub create_contact {
    my ($params, $group, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => [$group]);
    $contact->set_extra_metadata( type => 'waste' );
    $contact->set_extra_fields(@extra);
    $contact->update;
    return $contact;
}

create_contact({ category => 'Report missed collection', email => 'missed' }, 'Waste',
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Report missed assisted collection', email => '3146' }, 'Waste',
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Complaint against time', email => '3134' }, 'Waste',
    { code => 'Notes', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'property_id', required => 1, automated => 'hidden_field' },
    { code => 'original_ref', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Failure to Deliver Bags/Containers', email => '3141' }, 'Waste',
    { code => 'Notes', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'original_ref', required => 1, automated => 'hidden_field' },
    { code => 'container_request_guid', required => 0, automated => 'hidden_field' },
);
my $new_container_request_contact = create_contact({ category => 'Request new container', email => '3129' }, 'Waste',
    { code => 'uprn', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Action', required => 1, automated => 'hidden_field' },
    { code => 'Reason', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 0, automated => 'hidden_field' },
    { code => 'payment', required => 0, automated => 'hidden_field' },
    { code => 'property_id', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'Bin not returned', email => '3135' }, 'Waste',
    { code => 'NotAssisted', description => 'Thank you for bringing this to our attention. We will use your feedback to improve performance in the future.  Please accept our apologies for the inconvenience caused.', variable => 'false'  },
    { code => 'AssistedReturned', description => 'Thank you for bringing this to our attention. We will not return to your address on this occasion but we will endeavour to train our collection crew so that containers are returned correctly in the future.', variable => 'false' },
    { code => 'AssistedNotReturned', description => 'Thank you for bringing this to our attention. We will return to your address as soon as we can to return the bin to its correct location. This may take up to 2 working days.', variable => 'false'  },
    { code => 'Exact_Location', description => 'Exact location', required => 0, datatype => 'text' },
    { code => 'Notes', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'Waste spillage', email => '3227' }, 'Waste',
    { code => 'Image', description => 'Image', required => 0, datatype => 'image' },
    { code => 'Notes', description => 'Details of the spillage', required => 0, datatype => 'text' },
);

create_contact({ category => 'Missed collection dispute', email => '3143' }, 'Waste',
    { code => 'Image', description => 'Image', required => 0, datatype => 'image' },
    { code => 'Notes', description => 'Reason for dispute', required => 1, datatype => 'text' },
);

my $sent_params;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'sutton',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { sutton => {
            url => 'http://example.org/',
        } },
        waste => { sutton => 1 },
        waste_features => { sutton => {
                no_service_residential_address_types => [ 283, 284, 285 ],
                request_cancel_enabled => 1,
            } },
        echo => { sutton => { bulky_service_id => 960 }},
        payment_gateway => { sutton => {
            cc_url => 'http://example.com',
            request_change_cost_refuse_140 => 2500,
            request_change_cost_refuse_240 => 4500,
            request_change_cost_refuse_360 => 2000,
            request_change_cost_refuse_360_refuse_240 => 3000,
            request_change_cost_refuse_240_refuse_140 => 4000,
            request_change_cost_paper_360_paper_240 => 1500,
            request_change_cost_paper_240 => 1500,
            request_change_cost_paper_360 => 3000,
            request_replace_cost_refuse_140 => 500,
            request_replace_cost_refuse_240 => 500,
            request_replace_cost_refuse_360 => 500,
            request_replace_cost_paper_240 => 500,
            request_replace_cost_paper_360 => 1500,
            request_replace_cost_food_indoor_premium => 1500,
        } },
    },
    STAGING_FLAGS => {
        send_reports => 1,
    },
}, sub {
    my ($e) = shared_echo_mocks();
    my ($scp) = shared_scp_mocks();

    subtest 'Address lookup' => sub {
        set_fixed_time('2022-09-10T12:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('2 Example Street, Sutton');
        $mech->content_contains('Every other Friday');
        $mech->content_contains('Friday, 2nd September');
        $mech->content_lacks('Report a mixed recycling (cans, plastics &amp; glass) collection as missed', 'Standard reporting link removed');
        $mech->content_contains('Report a problem', 'General report an issue link added');
    };
    subtest 'In progress collection' => sub {
        $e->mock('GetTasks', sub { [ {
            Ref => { Value => { anyType => [ 17430692, 8287 ] } },
            State => { Name => 'Completed' },
            CompletedDate => { DateTime => '2022-09-09T16:00:00Z' }
        }, {
            Ref => { Value => { anyType => [ 17510905, 8287 ] } },
            State => { Name => 'Allocated' },
            CompletedDate => undef
        } ] });
        set_fixed_time('2022-09-09T16:30:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr/Friday, 9th September\s+\(this collection has been adjusted from its usual time\)\s+\(In progress\)/);
        $mech->content_lacks('Report a mixed recycling (cans, plastics &amp; glass) collection as missed');
        $mech->content_lacks('Report a non-recyclable refuse collection as missed');
        $mech->content_contains('Report a problem', 'Link is available');
        set_fixed_time('2022-09-09T19:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr/, at  4:00p\.?m\.?/);
        $mech->content_lacks('Report a mixed recycling (cans, plastics &amp; glass) collection as missed', 'Standard link removed');
        $mech->content_lacks('Report a non-recyclable refuse collection as missed', 'Standard link removed');
        $mech->content_contains('Report a problem', 'Link is available');
        $e->mock('GetTasks', sub { [] });
    };
    subtest 'Request a new bin' => sub {
        $mech->follow_link_ok( { text => 'Request a bin, box, caddy or bags' } );
		# 27 (1), 46 (1), 12 (1), 1 (1)
        # missing, new_build, more
        $mech->content_contains('The Council has continued to provide waste and recycling containers free for as long as possible', 'Intro text included');
        $mech->content_contains('You can request a larger container if you meet the following criteria', 'Divider intro text included for container sizes');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 27 }});
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Continue to payment');
        $mech->content_contains('Damaged (1x to deliver, 1x to collect)');

        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 500;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        $mech->content_contains('request has been sent');
        $mech->content_contains('Containers typically arrive within 20 working days');

        is $report->uprn, 1000000002;
        is $report->detail, "2 Example Street, Sutton, SM1 1AA\n\nReason: Damaged\n\n1x Paper and Cardboard Green Wheelie Bin (240L) to deliver\n\n1x Paper and Cardboard Green Wheelie Bin (240L) to collect";
        is $report->category, 'Request new container';
        is $report->title, 'Request replacement Paper and Cardboard Green Wheelie Bin (240L)';
        is $report->get_extra_field_value('payment'), 500, 'correct payment';
        is $report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $report->get_extra_field_value('Container_Type'), 27, 'correct bin type';
        is $report->get_extra_field_value('Action'), '2::1', 'correct container request action';
        is $report->get_extra_field_value('service_id'), 948;
        is $report->state, 'unconfirmed', 'report not confirmed';
        is $report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        FixMyStreet::Script::Reports::send();
        my $email = $mech->get_text_body_from_email;
        like $email, qr/please allow up to 20 working days/;
        like $email, qr/cancel your request/, 'include cancel link text';
        like $email, qr/A refund will not be issued/, 'include no refund text for paid request';
        like $email, qr/waste\/12345\/request\/cancel\//, 'include cancel link';
    };
    subtest 'Request a premium caddy' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->content_contains('The Council has continued to provide waste and recycling containers free for as long as possible', 'Intro text included');
        $mech->content_contains('You can request a larger container if you meet the following criteria', 'Divider intro text included for container sizes');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 85 }});
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'missing' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Continue to payment');
        $mech->content_contains('Missing (1x to deliver)');

        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 1500;
    };
    subtest 'Request a larger bin than current (120L -> 240L)' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 3 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Continue to payment');
        $mech->content_like(qr/Standard Brown General Waste Wheelie Bin \(140L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to collect<\/dd>/);
        $mech->content_like(qr/Larger Brown General Waste Wheelie Bin \(240L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to deliver<\/dd>/);

        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 4500;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');
        $mech->content_contains('Containers typically arrive within 20 working days');

        is $report->uprn, 1000000002;
        is $report->title, 'Request exchange for Larger Brown General Waste Wheelie Bin (240L)';
        is $report->get_extra_field_value('payment'), 4500, 'correct payment';
        is $report->get_extra_field_value('Container_Type'), '1::3', 'correct bin type';
        is $report->get_extra_field_value('Action'), '2::1', 'correct container request action';
        is $report->get_extra_field_value('Reason'), '9::9', 'correct container request reason';
        is $report->get_extra_field_value('service_id'), 940;
    };
    subtest 'Request a smaller bin than current (240L -> 140L)' => sub {
        $e->mock('GetServiceUnitsForObject', sub { $bin_refuse_240_data });
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 1 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Continue to payment');
        $mech->content_like(qr/Larger Brown General Waste Wheelie Bin \(240L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to collect<\/dd>/);
        $mech->content_like(qr/Standard Brown General Waste Wheelie Bin \(140L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to deliver<\/dd>/);

        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 4000;
    };
    subtest 'Request a smaller bin than current (360L -> 240L)' => sub {
        $e->mock('GetServiceUnitsForObject', sub { $bin_refuse_360_data });
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 3 }}, 'select smaller bin');
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }}, 'fill user details');
        $mech->content_contains('Continue to payment', 'go to payment page');
        $mech->content_like(qr/Extra Large Brown General Waste Wheelie Bin \(360L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to collect<\/dd>/, 'page contains old bin text');
        $mech->content_like(qr/Larger Brown General Waste Wheelie Bin \(240L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to deliver<\/dd>/, 'page contains new bin text');

        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 3000, 'price correct';
    };
    subtest 'Request a paper bin when having a 140L' => sub {
        $e->mock('GetServiceUnitsForObject', sub { $bin_140_data });
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 27 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Continue to payment');
        $mech->content_like(qr/Paper and Cardboard Green Wheelie Bin \(140L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to collect<\/dd>/);
        $mech->content_like(qr/Paper and Cardboard Green Wheelie Bin \(240L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to deliver<\/dd>/);

        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 1500;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');
        $mech->content_contains('Containers typically arrive within 20 working days');

        is $report->uprn, 1000000002;
        is $report->title, 'Request exchange for Paper and Cardboard Green Wheelie Bin (240L)';
        is $report->get_extra_field_value('payment'), 1500, 'correct payment';
        is $report->get_extra_field_value('Container_Type'), '26::27', 'correct bin type';
        is $report->get_extra_field_value('Action'), '2::1', 'correct container request action';
        is $report->get_extra_field_value('Reason'), '9::9', 'correct container request reason';
        is $report->get_extra_field_value('service_id'), 948;
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };
    subtest 'Request a paper bin when having a 240L' => sub {
        $e->mock('GetServiceUnitsForObject', sub { $bin_240_data });
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 28 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Continue to payment');
        $mech->content_like(qr/Paper and Cardboard Green Wheelie Bin \(240L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to collect<\/dd>/);
        $mech->content_like(qr/Paper and Cardboard Green Wheelie Bin \(360L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to deliver<\/dd>/);

        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 3000;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');
        $mech->content_contains('Containers typically arrive within 20 working days');

        is $report->uprn, 1000000002;
        is $report->title, 'Request exchange for Paper and Cardboard Green Wheelie Bin (360L)';
        is $report->get_extra_field_value('payment'), 3000, 'correct payment';
        is $report->get_extra_field_value('Container_Type'), '27::28', 'correct bin type';
        is $report->get_extra_field_value('Action'), '2::1', 'correct container request action';
        is $report->get_extra_field_value('Reason'), '9::9', 'correct container request reason';
        is $report->get_extra_field_value('service_id'), 948;
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };
    subtest 'Request a smaller paper bin when having a 360L' => sub {
        $e->mock('GetServiceUnitsForObject', sub { $bin_360_data });
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 27 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Continue to payment');
        # use open ':std', ':encoding(UTF-8)';
        # print $mech->content;
        $mech->content_like(qr/Paper and Cardboard Green Wheelie Bin \(360L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to collect<\/dd>/);
        $mech->content_like(qr/Paper and Cardboard Green Wheelie Bin \(240L\)<\/dt>\s*<dd class="govuk-summary-list__value">1x to deliver<\/dd>/);

        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 1500;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');
        $mech->content_contains('Containers typically arrive within 20 working days');

        is $report->uprn, 1000000002;
        is $report->title, 'Request exchange for Paper and Cardboard Green Wheelie Bin (240L)';
        is $report->get_extra_field_value('payment'), 1500, 'correct payment';
        is $report->get_extra_field_value('Container_Type'), '28::27', 'correct bin type';
        is $report->get_extra_field_value('Action'), '2::1', 'correct container request action';
        is $report->get_extra_field_value('Reason'), '10::10', 'correct container request reason';
        is $report->get_extra_field_value('service_id'), 948;
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };
    subtest 'Report a new recycling raises a bin delivery request' => sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 12 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'missing' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Missing (1x to deliver)');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->uprn, 1000000002;
        is $report->detail, "2 Example Street, Sutton, SM1 1AA\n\nReason: Missing\n\n1x Mixed Recycling Green Box (55L) to deliver";
        is $report->title, 'Request replacement Mixed Recycling Green Box (55L)';
    };

    subtest 'Report missed collection' => sub {

        $mech->get_ok('/waste/12345');
        $mech->follow_link_ok( { url_regex => qr/service_id=954/}, 'Follow "Report a problem" link for food waste' );
        $mech->submit_form_ok({ with_fields => { category => 'redirect-missed' }});
        $mech->submit_form_ok({ with_fields => { 'service-954' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Thank you for reporting a missed collection');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->uprn, 1000000002;
        is $report->detail, "Report missed Food Waste\n\n2 Example Street, Sutton, SM1 1AA";
        is $report->title, 'Report missed Food Waste';
    };

    subtest 'No reporting/requesting if open request' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Report a mixed recycling (cans, plastics &amp; glass) collection as missed', 'Standard reporting is missing');

        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventTypeId => 3129,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
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
        $mech->content_contains('A mixed recycling (cans, plastics &amp; glass) container request was made on Saturday, 10 September');
        $mech->content_lacks('Report a mixed recycling (cans, plastics &amp; glass) collection as missed', 'Standard missed reporting link not expected');
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-choice" value="12" aria-describedby="container-choice-item-hint"\s+disabled/s); # green
        $mech->content_like(qr/Mixed Recycling Green Box \(55L\).*?<span id="container-choice-item-hint" class="govuk-hint govuk-checkboxes__hint">\s+Unavailable to request as order in progress/s);
        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            EventTypeId => 3129,
            Data => { ExtensibleDatum => [
                { Value => 2, DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => 1, DatatypeName => 'Action' },
                        { Value => 43, DatatypeName => 'Container Type' },
                    ] },
                },
            ] },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A food waste container request was made on Saturday, 10 September');
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-choice" value="43" aria-describedby="container-choice-item-hint"\s+disabled/s); # indoor
        $mech->content_like(qr/name="container-choice" value="46"\s*>/s); # outdoor

        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 3145,
            EventStateId => 0,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 944,
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Request a mixed recycling (cans, plastics &amp; glass) container', 'Standard link missing');
        $mech->content_lacks("A mixed recycling \(cans, plastics &amp; glass\) collection was reported as missed on Saturday, 10 September", 'Standard reporting link/message removed');
        $mech->follow_link_ok({ url_regex => qr/service_id=944/});
        $mech->content_like(qr/A mixed recycling \(cans, plastics &amp; glass\) collection was reported as missed\s+on Saturday, 10 September/);
        $mech->content_contains('We aim to resolve this by Tuesday, 13 September');

        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 3145,
            EventStateId => 0,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 948,
        } ] });
        $mech->get_ok('/waste/12345');

        $mech->content_lacks("A paper &amp; card collection was reported as missed", 'Standard reporting link/message removed');
        $e->mock('GetEventsForObject', sub { [] }); # reset
    };
    subtest 'No reporting if open request on service unit' => sub {
        $e->mock('GetEventsForObject', sub {
            my ($self, $type, $id) = @_;
            return [] if $type eq 'PointAddress' || $id == 1004;
            like $id, qr/^100[1-3]$/; # recycling service unit
            return [ {
                EventTypeId => 3145,
                EventStateId => 0,
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                ServiceId => 944,
            } ]
        });
        $mech->get_ok('/waste/12345');
        $e->mock('GetEventsForObject', sub { [] }); # reset
    };
    subtest 'No requesting if open request of different size' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->content_unlike(qr/name="container-choice" value="1"[^>]+disabled/s);

        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            EventTypeId => 3129,
            Data => { ExtensibleDatum => [
                { Value => 2, DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => 1, DatatypeName => 'Action' },
                        { Value => 1, DatatypeName => 'Container Type' },
                    ] },
                },
            ] },
        } ] });
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-choice" value="1"[^>]+disabled/s);

        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            EventTypeId => 3129,
            Data => { ExtensibleDatum => [
                { Value => 2, DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => 1, DatatypeName => 'Action' },
                        { Value => 3, DatatypeName => 'Container Type' },
                    ] },
                },
            ] },
        } ] });
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-choice" value="1"[^>]+disabled/s); # still disabled

        $e->mock('GetEventsForObject', sub { [] }); # reset
    };


    $e->mock('GetServiceUnitsForObject', sub { $kerbside_bag_data });
    set_fixed_time('2022-10-12T19:00:00Z');
    subtest 'No requesting a red stripe bag' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('#E83651');
        $mech->get_ok('/waste/12345/request');
        $mech->content_lacks('"container-choice" value="10"');
    };
    subtest 'Fortnightly collection can request a blue stripe bag' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 22 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->uprn, 1000000002;
        is $report->detail, "2 Example Street, Sutton, SM1 1AA\n\nReason: Additional bag required\n\n1x Mixed Recycling Blue Striped Bag to deliver";
        is $report->category, 'Request new container';
        is $report->title, 'Request new Mixed Recycling Blue Striped Bag';
    };
    subtest 'Weekly collection cannot request a blue stripe bag or unknown containers' => sub {
        $e->mock('GetServiceUnitsForObject', sub { $above_shop_data });
        $mech->get_ok('/waste/12345/request');
        $mech->content_lacks('"container-choice" value="22"');
        $mech->content_lacks('"container-choice" value="46"');
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };

    subtest 'Fetching property without services give Sutton specific errors' => sub {
        $e->mock('GetServiceUnitsForObject', sub { [] });
        $mech->get_ok('/waste/12345/');
        $mech->content_contains('Oh no! Something has gone wrong');
        my $non_residential = { %$address_data, PointAddressType => { Id => 123 } };
        $e->mock('GetPointAddress', sub { $non_residential });
        $mech->get_ok('/waste/12345/');
        $mech->content_contains('No schedule found for this property');
        $e->mock('GetPointAddress', sub { $address_data });
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };

    subtest 'Okay fetching property with two of the same task type' => sub {
        my @dupe = @$bin_data;
        push @dupe, dclone($dupe[0]);
        # Give the new entry a different ID and task ref
        $dupe[$#dupe]->{ServiceTasks}{ServiceTask}[0]{Id} = 4001;
        $dupe[$#dupe]->{ServiceTasks}{ServiceTask}[0]{ServiceTaskSchedules}{ServiceTaskSchedule}{LastInstance}{Ref}{Value}{anyType}[1] = 8281;
        $e->mock('GetServiceUnitsForObject', sub { \@dupe });
        $e->mock('GetTasks', sub { [ {
            Ref => { Value => { anyType => [ 22239416, 8280 ] } },
            State => { Name => 'Completed' },
            CompletedDate => { DateTime => '2022-09-09T16:00:00Z' }
        }, {
            Ref => { Value => { anyType => [ 22239416, 8281 ] } },
            State => { Name => 'Outstanding' },
            CompletedDate => undef
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('assisted collection'); # For below, while we're here
        $e->mock('GetTasks', sub { [] });
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };
    set_fixed_time('2022-09-09T19:00:00Z');
    subtest 'Assisted collection display for staff' => sub {
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('not set up for assisted collection');
        my $dupe = dclone($bin_data);
        # Give the entry an assisted collection
        $dupe->[0]{Data}{ExtensibleDatum}{DatatypeName} = 'Assisted Collection';
        $dupe->[0]{Data}{ExtensibleDatum}{Value} = 1;
        $e->mock('GetServiceUnitsForObject', sub { $dupe });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('is set up for assisted collection');
        $mech->follow_link_ok( { url_regex => qr/service_id=954/}, 'Follow "Report a problem" link for the assisted collection' );
        $mech->submit_form_ok({ with_fields => { category => 'redirect-missed' }}, 'Select the missed collection option');
        subtest 'Different category for assisted' => sub {
            $mech->submit_form_ok({ with_fields => { 'service-954' => 1 } });
            $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
            $mech->submit_form_ok({ with_fields => { process => 'summary' } });
            $mech->content_contains('Thank you for reporting a missed collection');
            my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
            is $report->category, 'Report missed assisted collection';
        };
        subtest 'FAS cannot be assisted even if it says it is' => sub {
            my $dupe = dclone($above_shop_data);
            # Give the entry an assisted collection
            $dupe->[0]{Data}{ExtensibleDatum}[1] = {
                DatatypeName => 'Assisted Collection',
                Value => 1,
            };
            $e->mock('GetServiceUnitsForObject', sub { $dupe });
            $mech->get_ok('/waste/12345');
            $mech->content_contains('not set up for assisted collection');
        };
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };

    set_fixed_time('2022-10-13T19:00:00Z');
    subtest 'Time banded property display' => sub {
        $e->mock('GetServiceUnitsForObject', sub { $above_shop_data });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Put your bags out between 6pm and 8pm');
        $mech->content_contains('Every Wednesday and Saturday');
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };
    set_fixed_time('2022-09-09T19:00:00Z');

    subtest 'test report a problem - bin not returned, not assisted' => sub {
        FixMyStreet::Script::Reports::send();
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Report a spillage or bin not returned issue with a non-recyclable refuse collection', 'Can report a problem with non-recyclable waste');
        $mech->content_lacks('Report a spillage or bin not returned issue with a food waste collection', 'Can report a problem with food waste');
        $mech->content_contains('Report a problem');
        $mech->content_lacks('Report a spillage or bin not returned issue with a paper and card collection', 'Standard missed reporting link not expected anyway');
        $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for the assisted collection' );
        $mech->submit_form_ok( { with_fields => { category => 'Bin not returned' } });
        $mech->content_contains('We will use your feedback');
        $mech->content_lacks('We will not return to your address on this occasion');
        $mech->content_lacks('We will return to your address as soon as we can to return the bin');
        $mech->submit_form_ok( { with_fields => { extra_Exact_Location => 'hello' } } );
        $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } });
        $mech->submit_form_ok( { with_fields => { submit => '1' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Return to property details');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('Notes'), '', "Blank notes field is empty string";
        is $report->detail, "Non-Recyclable Refuse\n\n2 Example Street, Sutton, SM1 1AA", "Details of report contain information about problem";
        is $report->user->email, 'schmoe@example.org', 'User details added to report';
        is $report->name, 'Joe Schmoe', 'User details added to report';
        is $report->category, 'Bin not returned', "Correct category";
        FixMyStreet::Script::Reports::send();
        my $text = $mech->get_text_body_from_email;
        like $text, qr/apologise for any inconvenience/, 'Other problem text included in email';
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('api_key'), 'KEY';
        is $cgi->param('attribute[Exact_Location]'), 'hello';
        is $cgi->param('attribute[Notes]'), '';
    };

   subtest 'test report a problem - bin not returned, assisted' => sub {
        my $dupe = dclone($bin_data);
        # Give the entry an assisted collection
        $dupe->[0]{Data}{ExtensibleDatum}{DatatypeName} = 'Assisted Collection';
        $dupe->[0]{Data}{ExtensibleDatum}{Value} = 1;
        $e->mock('GetServiceUnitsForObject', sub { $dupe });
        $mech->get_ok('/waste/12345');
        $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for the assisted collection' );
        $mech->submit_form_ok( { with_fields => { category => 'Bin not returned' } });
        $mech->submit_form_ok( { with_fields => { now_returned => 'Yes' } } );
        $mech->content_contains('We will not return to your address on this occasion');
        $mech->content_lacks('We will return to your address as soon as we can to return the bin');
        $mech->content_lacks('We will use your feedback');

        $mech->submit_form_ok( { with_fields => { extra_Exact_Location => 'hello' } } );
        $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } });
        $mech->submit_form_ok( { with_fields => { submit => '1' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Return to property details');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('Notes'), '', "Blank notes field is empty string";
        is $report->detail, "Non-Recyclable Refuse\n\n2 Example Street, Sutton, SM1 1AA", "Details of report contain information about problem";
        FixMyStreet::Script::Reports::send();
        my $text = $mech->get_text_body_from_email;
        like $text, qr/apologise for any inconvenience/, 'Other problem text included in email';
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Exact_Location]'), 'hello';
        is $cgi->param('attribute[Notes]'), '';
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
   };

   subtest 'test report a problem - bin not returned, assisted, not returned' => sub {
        my $dupe = dclone($bin_data);
        # Give the entry an assisted collection
        $dupe->[0]{Data}{ExtensibleDatum}{DatatypeName} = 'Assisted Collection';
        $dupe->[0]{Data}{ExtensibleDatum}{Value} = 1;
        $e->mock('GetServiceUnitsForObject', sub { $dupe });
        $mech->get_ok('/waste/12345');
        $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for the assisted collection' );
        $mech->submit_form_ok( { with_fields => { category => 'Bin not returned' } });
        $mech->submit_form_ok( { with_fields => { now_returned => 'No' } } );
        $mech->content_contains('We will return to your address as soon as we can to return the bin');
        $mech->content_lacks('We will not return to your address on this occasion');
        $mech->content_lacks('We will use your feedback');

        $mech->submit_form_ok( { with_fields => { extra_Exact_Location => 'hello' } } );
        $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } });
        $mech->submit_form_ok( { with_fields => { submit => '1' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Return to property details');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('Notes'), '*** Property is on assisted list ***';
        is $report->detail, "Non-Recyclable Refuse\n\n2 Example Street, Sutton, SM1 1AA", "Details of report contain information about problem";
        FixMyStreet::Script::Reports::send();
        my $text = $mech->get_text_body_from_email;
        like $text, qr/apologise for any inconvenience/, 'Other problem text included in email';
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Exact_Location]'), 'hello';
        is $cgi->param('attribute[Notes]'), '*** Property is on assisted list ***';
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
   };

   subtest 'test report a problem - waste spillage' => sub {
        $mech->get_ok('/waste/12345');
        $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for the assisted collection' );
        $mech->submit_form_ok( { with_fields => { category => 'Waste spillage' } });
        $mech->submit_form_ok( { with_fields => {
            extra_Notes => 'Rubbish left on driveway',
            location_photo => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
        } });
        $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } });
        $mech->submit_form_ok( { with_fields => { submit => '1' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Return to property details');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->category, 'Waste spillage', "Correct category";
        is $report->get_extra_field_value('Notes'), 'Rubbish left on driveway', "Notes filled in";
        is $report->detail, "Rubbish left on driveway\n\nNon-Recyclable Refuse\n\n2 Example Street, Sutton, SM1 1AA", "Details of report contain information about problem";
        is $report->user->email, 'schmoe@example.org', 'User details added to report';
        is $report->name, 'Joe Schmoe', 'User details added to report';
        is $report->photo, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';
        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my $text = $mech->get_text_body_from_email;
        like $text, qr/apologise for any inconvenienc/, 'Other problem text included in email';
        my $req = Open311->test_req_used;
        foreach ($req->parts) {
            my $cd = $_->header('Content-Disposition');
            is $_->content, 'KEY', 'API key present' if $cd =~ /api_key/;
            is $_->content, 'Rubbish left on driveway', 'Notes added' if $cd =~ /attribute\[Notes\]/;
            is $_->header('Content-Type'), 'image/jpeg', 'Right content type' if $cd =~ /jpeg/;
        }
    };

    subtest 'No spillage report for open request in same service' => sub {
        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 3227, # Waste spillage
            ServiceId => 940, # Refuse
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for the non-recyclable collection' );
        $mech->content_like(qr/name="category" value="Waste spillage" aria-describedby="category-item-hint"\s+disabled/s);
        $mech->content_like(qr/You have already reported a spillage/s);
        $mech->back;
        $mech->follow_link_ok( { url_regex => qr/service_id=954/}, 'Follow "Report a problem" link for the food collection' );
        $mech->content_unlike(qr/name="category" value="Waste spillage" aria-describedby="category-item-hint"\s+disabled/s);
        $e->mock('GetEventsForObject', sub { [] }); # reset
    };

    # this is a dispute for when a scheduled collection has been marked as not complete
    subtest 'Dispute of missed collections' => sub {
        my $dispute_label = 'Dispute collection closure reason';
        my $problem_url
            = '/waste/12345/enquiry?template=problem&service_id=940';

        subtest 'No missed collection' => sub {
            set_fixed_time('2022-09-10T19:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_lacks($dispute_label);

            set_fixed_time('2022-09-13T19:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_lacks($dispute_label);

            set_fixed_time('2022-09-15T17:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_lacks($dispute_label);

            set_fixed_time('2022-09-15T19:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_lacks($dispute_label);
        };

        # domestic refuse
        $e->mock('GetTasks', sub { [ {
            Ref => { Value => { anyType => [ 17430692, 8287 ] } },
            State => { Name => 'Not Completed' },
            Resolution => { Name => 'Contaminated builder waste', Ref => { Value => { 'anyType' => 1135 } } },
            CompletedDate => { DateTime => '2022-09-09T16:00:00Z' }
        } ] });

        subtest 'Raising a dispute only available within window' => sub {
            set_fixed_time('2022-09-09T17:30:00Z');
            $mech->get_ok($problem_url);
            $mech->content_lacks($dispute_label, 'not allowed before window opens');

            set_fixed_time('2022-09-14T19:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_lacks($dispute_label, 'not allowed after window closes');

            set_fixed_time('2022-09-14T00:01:00Z');
            $mech->get_ok($problem_url);
            $mech->content_lacks($dispute_label, 'not allowed just after window closes');

            set_fixed_time('2022-09-13T23:59:00Z');
            $mech->get_ok($problem_url);
            $mech->content_contains($dispute_label, 'allowed just before window closes');

            set_fixed_time('2022-09-09T18:01:00Z');
            $mech->get_ok($problem_url);
            $mech->content_contains($dispute_label, 'allowed just after window opens');

            set_fixed_time('2022-09-11T18:01:00Z');
            $mech->get_ok($problem_url);
            $mech->content_contains($dispute_label, 'allowed during window');
        };

        subtest 'Open dispute for missed collection' => sub {
            $mech->clear_emails_ok;
            set_fixed_time('2022-09-11T18:01:00Z');
            $mech->get_ok($problem_url);
            $mech->submit_form_ok(
                { with_fields => { category => 'Missed collection dispute' } }
            );
            $mech->content_contains('Contaminated builder waste', 'details of missed bin collection displayed');
            $mech->content_lacks('This photo provides the evidence', 'No resolution photo text');
            $mech->submit_form_ok( { with_fields => { 'extra_Notes' => 'There was no problem with the bin' } }, 'submitted reasons');
            $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } }, 'sumitted name and email');
            $mech->submit_form_ok( { with_fields => { submit => '1' } }, 'submitted confirmation');
            $mech->content_contains('Your enquiry has been submitted');
            $mech->content_contains('Return to property details');
            $mech->content_contains('/waste/12345"');
            my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            is $report->category, 'Missed collection dispute', "Correct category";
            is $report->title, 'Missed collection dispute';
            is $report->detail, "Non-Recyclable Refuse\n\n2 Example Street, Sutton, SM1 1AA", "Details of report contain information about problem";
            is $report->user->email, 'schmoe@example.org', 'User details added to report';
            is $report->name, 'Joe Schmoe', 'User details added to report';
            is $report->get_extra_field_value('Notes'), "There was no problem with the bin";
            FixMyStreet::Script::Reports::send();
            $mech->email_count_is(1);
            my $email = $mech->get_email;
            my $text_email = $mech->get_text_body_from_email($email);
            my $html_email = $mech->get_html_body_from_email($email);
            like $text_email, qr/respond in the next two working days/, 'Correct text email next steps';
            like $html_email, qr/respond in the next two working days/, 'Correct text email next steps';
        };

        subtest 'Existing dispute event' => sub {
            # Now mock there is an existing escalation
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3143,
                EventStateId => 0,
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-11T18:03:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-14T19:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_like(qr/Missed collection dispute.*disabled/s);
            $mech->content_contains('We are investigating the problem with this collection.');
        };


        $e->mock('GetEventsForObject', sub { [] }); # reset
    };

    my $missed_report;

    subtest 'Escalations of missed collections' => sub {
        subtest 'No missed collection' => sub {
            for my $date ('2022-09-10T19:00:00Z', '2022-09-13T19:00:00Z', '2022-09-15T17:00:00Z', '2022-09-15T19:00:00Z') {
                set_fixed_time($date);
                $mech->get_ok('/waste/12345', "Call waste page on $date");
                $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
                $mech->content_contains('class="govuk-heading-xl">Report a problem', 'On the report a problem page');
                $mech->content_lacks('Escalate my missed collection report', 'No escalation option available without missed collection reported');
            }
        };

        subtest 'Open missed collection but by a different flat' => sub {
            # So say this result was what was returned by a ServiceUnit GetEventsForObject call, not the address one
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19240, # Allocated to Crew
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12346 } } } ] },
            } ] });

            set_fixed_time('2022-09-13T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
            $mech->content_contains('class="govuk-heading-xl">Report a problem', 'On the report a problem page');
            $mech->content_lacks('Escalate my missed collection report', 'No escalation option available without missed collection reported');
        };

        subtest 'Open missed collection' => sub {
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                ClientReference => 'LBS-123',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19240, # Allocated to Crew
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-10T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
            $mech->content_contains('class="govuk-heading-xl">Report a problem', 'On the report a problem page');
            $mech->content_lacks('Escalate my missed collection report', 'No escalation option available due to date');

            set_fixed_time('2022-09-13T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
            $mech->content_contains('class="govuk-heading-xl">Report a problem', 'On the report a problem page');
            $mech->content_contains('Escalate my missed collection report', 'Escalation option available');
            $mech->content_contains('if they have not returned you can escalate the report');
            subtest 'actually make the report' => sub {
                $mech->submit_form_ok( { with_fields => { category => 'Complaint against time' } });
                $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } });
                $mech->submit_form_ok( { with_fields => { submit => '1' } });
                $mech->content_contains('Your enquiry has been submitted');
                $mech->content_contains('Return to property details');
                $mech->content_contains('/waste/12345"');
                my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
                # save this for later
                $missed_report = $report;
                is $report->category, 'Complaint against time', "Correct category";
                is $report->title, 'Issue with collection';
                is $report->detail, "Non-Recyclable Refuse\n\n2 Example Street, Sutton, SM1 1AA", "Details of report contain information about problem";
                is $report->user->email, 'schmoe@example.org', 'User details added to report';
                is $report->name, 'Joe Schmoe', 'User details added to report';
                is $report->get_extra_field_value('Notes'), 'Originally Echo Event #112112321';
                is $report->get_extra_field_value('original_ref'), 'LBS-123';

                $e->mock('GetEventsForObject', sub { [
                    {
                        Id => '112112321',
                        ClientReference => 'LBS-123',
                        EventTypeId => 3145, # Missed collection
                        EventStateId => 19240, # Allocated to Crew
                        ServiceId => 940, # Refuse
                        EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                        EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
                    },
                    {
                        Id => '112112321',
                        ClientReference => 'LBS-123',
                        EventTypeId => 3134, # Missed collection escalation
                        EventStateId => 19240, # Allocated to Crew
                        ServiceId => 940, # Refuse
                        EventDate => { DateTime => "2022-09-13T17:00:00Z" },
                        EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
                } ] });

                $mech->get_ok('/waste/12345/enquiry?template=problem&service_id=940');
                $mech->content_contains("We aim to resolve this by Wednesday, 14 September", 'escalation target date within one working day displayed');
            };

            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                ClientReference => 'LBS-123',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19240, # Allocated to Crew
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-15T17:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
            $mech->content_contains('class="govuk-heading-xl">Report a problem', 'On the report a problem page');
            $mech->content_contains('Escalate my missed collection report', 'Escalation option available');
            $mech->content_contains('if they have not returned you can escalate the report', 'Allows escalating');

            set_fixed_time('2022-09-15T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
            $mech->content_contains('Escalate my missed collection report', 'Escalation option not available');
            $mech->content_like(qr/name="category" value="Complaint against time" aria-describedby="category-item-hint"\s+disabled/s, 'Escalation option shown, but disabled, after end of window');
        };

        subtest 'Completed missed collection - no escalation' => sub {
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19241, # Completed
                ResolvedDate => { DateTime => "2022-09-10T17:00:00Z" },
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            for my $date ('2022-09-10T19:00:00Z', '2022-09-13T19:00:00Z', '2022-09-15T17:00:00Z', '2022-09-15T19:00:00Z' ) {
                set_fixed_time($date);
                $mech->get_ok('/waste/12345');
                $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
                $mech->content_lacks('Escalate my missed collection report', 'No option to escalate missed collection');
            }
        };

        subtest 'Not Completed missed collection' => sub {
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19242, # Not Completed
                ResolvedDate => { DateTime => "2022-09-10T17:00:00Z" },
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            for my $date ('2022-09-10T19:00:00Z', '2022-09-13T19:00:00Z', '2022-09-15T17:00:00Z', '2022-09-15T19:00:00Z' ) {
                set_fixed_time($date);
                $mech->get_ok('/waste/12345');
                $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
                $mech->content_lacks('Escalate my missed collection report', 'No option to escalate missed collection');
            }
        };

        subtest 'Existing escalation event' => sub {
            # Now mock there is an existing escalation
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3145, # Missed collection
                EventStateId => 0,
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            }, {
                Id => '112112322',
                EventTypeId => 3134, # Complaint against time
                EventStateId => 0,
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-13T19:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-14T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
            $mech->content_lacks('redirect-missed', 'Report missed not present');
            $mech->content_contains('Thank you for reporting an issue with this collection; we are investigating', "Message to resident displayed");
        };

        $e->mock('GetEventsForObject', sub { [] }); # reset
    };

    # this is when a collection has been missed, a missed bin report made and then
    # marked as not complete
    subtest 'Dispute of non completed missed bin report' => sub {
        # We want to test that a missed collection report can be disputed.
        # To prevent confusion, mock *completed* task for original collection.
        # If it was incomplete, a dispute could be raised for it, and would
        # also mean in reality that a missed collection report cannot be made
        # (see waste_task_resolutions() in Echo.pm).
        $e->mock('GetTasks', sub { [ {
            Ref => { Value => { anyType => [ 17430692, 8287 ] } },
            State => { Name => 'Completed' },
            # Resolution => { Name => 'Contaminated builder waste', Ref => { Value => { 'anyType' => 1135 } } },
            CompletedDate => { DateTime => '2022-09-09T16:00:00Z' }
        } ] });

        my $problem_url
            = '/waste/12345/enquiry?template=problem&service_id=940';
        my $dispute_label = 'Dispute collection closure reason';

        subtest 'Check link availability' => sub {
            # Mock missed collection report in Echo
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19242, # Not Completed
                ResolvedDate => { DateTime => "2022-09-10T17:00:00Z" },
                ResolutionCodeId => 1135, # Contaminated builder waste
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-10T19:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_contains($dispute_label);

            set_fixed_time('2022-09-13T19:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_contains($dispute_label);

            set_fixed_time('2022-09-15T17:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_lacks($dispute_label);

            set_fixed_time('2022-09-15T19:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_lacks($dispute_label);
        };

        my $comment = FixMyStreet::DB->resultset('Comment')->create(
            {
                user          => $body_user,
                problem_id    => $missed_report->id,
                text          => 'Contaminated builder waste',
                confirmed     => DateTime->now - DateTime::Duration->new( minutes => 15 ),
                problem_state => 'unable to fix',
                anonymous     => 0,
                mark_open     => 0,
                mark_fixed    => 0,
                state         => 'confirmed',
                photo         => $sample_file->slurp,
            }
        );

        restore_time();
        $comment->confirmed( DateTime->now ); # - DateTime::Duration->new( minutes => 15 ) );
        $comment->update;

        my $email;
        set_fixed_time('2022-09-11T18:01:00Z');
        subtest 'Open collection dispute from email' => sub {
            $mech->clear_emails_ok;
            FixMyStreet::Script::Alerts::send_updates();
            $mech->email_count_is(1);
            $email = $mech->get_email;
            my $email_text = $mech->get_text_body_from_email($email);
            my $email_html = $mech->get_html_body_from_email($email);
            like $email_text, qr/Contaminated builder waste/, 'Reason pulled from comment';
            like $email_text, qr/report a problem with this missed collection/, 'Report a problem text in text email';
            like $email_html, qr/Contaminated builder waste/, 'Reason pulled from comment';
            like $email_html, qr/Report a problem with this missed collection/, 'Report a problem text in html email';
            like $email_html, qr{waste/12345/enquiry}, 'HTML alert contains report link';

            # we only want the HTML link as the text version does not contain the link
            my @links = $email_html =~ m{https?://[^"]+}g;
            my @enq_links = grep( /enquiry/, @links );
            # need to strip the host otherwise we're not logged in
            my $l = URI->new($enq_links[0]);
            $mech->get_ok($l->path_query);
            $mech->content_contains('Contaminated builder waste', 'details of missed bin collection displayed');

            # XXX Email link uses 'original_booking_id' param here to denote
            # missed collection report ID, but 'original_booking_id' should
            # really only refer to bulky/small item reports. Also, photo
            # does not appear when form accessed from web below.
            $mech->content_contains('This photo provides the evidence', 'Has resolution photo text');
        };

        subtest 'Create dispute for non complete missed bin report' => sub {
            FixMyStreet::Script::Reports::send();
            $mech->clear_emails_ok;
            set_fixed_time('2022-09-11T18:01:00Z');
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok( { url_regex => qr/service_id=940/} );
            $mech->submit_form_ok(
                { with_fields => { category => 'Missed collection dispute' } }
            );
            $mech->content_contains('Contaminated builder waste', 'details of missed bin collection displayed');
            $mech->content_lacks('This photo provides the evidence', 'No resolution photo text');
            $mech->submit_form_ok( { with_fields => { 'extra_Notes' => 'There was no problem with the bin' } }, 'submitted reasons');
            $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } }, 'sumitted name and email');
            $mech->submit_form_ok( { with_fields => { submit => '1' } }, 'submitted confirmation');
            $mech->content_contains('Your enquiry has been submitted');
            $mech->content_contains('Return to property details');
            $mech->content_contains('/waste/12345"');
            my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            is $report->category, 'Missed collection dispute', "Correct category";
            is $report->title, 'Missed collection dispute';
            is $report->detail, "Non-Recyclable Refuse\n\n2 Example Street, Sutton, SM1 1AA", "Details of report contain information about problem";
            is $report->user->email, 'schmoe@example.org', 'User details added to report';
            is $report->name, 'Joe Schmoe', 'User details added to report';
            like $report->get_extra_field_value('Notes'), qr"There was no problem with the bin";
            like $report->get_extra_field_value('Notes'), qr"Originally Echo Event #112112321";
            FixMyStreet::Script::Reports::send();
            $mech->email_count_is(1);
            my $email = $mech->get_email;
            my $text_email = $mech->get_text_body_from_email($email);
            my $html_email = $mech->get_html_body_from_email($email);
            like $text_email, qr/respond in the next two working days/, 'Correct text email next steps';
            like $html_email, qr/respond in the next two working days/, 'Correct text email next steps';
        };

        subtest 'Existing dispute event' => sub {
            # Now mock there is an existing dispute
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19242, # Not Completed
                ResolvedDate => { DateTime => "2022-09-10T17:00:00Z" },
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            },
            {
                Id => '112112321',
                EventTypeId => 3143,
                EventStateId => 0,
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-11T18:03:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-14T19:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_like(qr/Missed collection dispute.*disabled/s);
            $mech->content_contains('We are investigating the problem with this collection.');
        };

        subtest 'Complete missed collection' => sub {
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19241, # Completed
                ResolvedDate => { DateTime => "2022-09-10T17:00:00Z" },
                ServiceId => 940, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-14T19:00:00Z');
            $mech->get_ok($problem_url);
            $mech->content_lacks($dispute_label);
        };

        $e->mock('GetEventsForObject', sub { [] }); # reset
    };

    subtest 'Escalations of container delivery failure' => sub {
        my $request_time = "2025-02-03T08:00:00Z";

        my $window_start_time = "2025-03-04T00:00:00Z";
        my $just_before_window = "2025-03-03T23:59:59Z";

        my $window_end_time = "2025-03-18T23:59:59Z";
        my $just_after_window = "2025-03-19T00:00:00Z";

        my $open_container_request_event = {
            Id => '112112321',
            ClientReference => 'LBS-789',
            EventTypeId => 3129, # Container request
            EventDate => { DateTime => $request_time },
            Data => { ExtensibleDatum => [
                { Value => 2, DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => 1, DatatypeName => 'Action' },
                        { Value => 1, DatatypeName => 'Container Type' }, # Refuse container
                    ] },
                },
            ] },
            Guid => 'container-request-event-guid',
        };
        my $escalation_event = {
            Id => '112112323',
            EventTypeId => 3141, # Failure to Deliver Bags/Containers
            EventStateId => 0,
            ServiceId => 940, # Refuse
            EventDate => { DateTime => "2022-09-13T19:00:00Z" },
            Guid => 'container-escalation-event-guid',
        };
        my ($escalation_report) = $mech->create_problems_for_body(
            1, $body->id,
            'Container escalation', {
                cobrand => 'sutton',
                external_id => 'container-escalation-event-guid',
                cobrand_data => 'waste',
            }
        );
        $escalation_report->set_extra_fields({ name => 'container_request_guid', value => 'container-request-event-guid' });
        $escalation_report->update;


        $e->mock('GetEventsForObject', sub { [ $open_container_request_event, $escalation_event ] });

        subtest "Open request already escalated; can't escalate" => sub {
            foreach my $config ((
                { 'time' => $just_before_window, label => 'before window' },
                { 'time' => $window_start_time,  label => 'window start' },
                { 'time' => $window_end_time,    label => 'window end' },
                { 'time' => $just_after_window,  label => 'after window' },
            )) {
                subtest $config->{label} => sub {
                    set_fixed_time($config->{time});
                    $mech->get_ok('/waste/12345');
                    $mech->content_lacks('Request a non-recyclable refuse container');
                    $mech->content_contains('A non-recyclable refuse container request was made on Monday, 3 February');
                    $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
                    $mech->content_contains('Thank you for reporting an issue with this delivery; we are investigating');
                };
            }
        };
        $e->mock('GetEventsForObject', sub { [ $open_container_request_event ] });

        subtest "Open request not escalated but outside window; can't escalate" => sub {
            foreach my $config ((
                { 'time' => $just_before_window, label => 'before window' },
                { 'time' => $just_after_window,  label => 'after window' },
            )) {
                subtest $config->{label} => sub {
                    set_fixed_time($config->{time});
                    $mech->get_ok('/waste/12345');
                    $mech->content_lacks('Request a non-recyclable refuse container');
                    $mech->content_contains('A non-recyclable refuse container request was made on Monday, 3 February');
                    $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
                    $mech->content_contains('please wait until 10 working days have passed');
                };
            }
        };

        subtest "Open request not escalated and inside window; can escalate" => sub {
            foreach my $config ((
                { 'time' => $window_start_time, label => 'window start' },
                { 'time' => $window_end_time,  label => 'window end' },
            )) {
                subtest $config->{label} => sub {
                    set_fixed_time($config->{time});
                    $mech->get_ok('/waste/12345');
                    $mech->content_lacks('Request a non-recyclable refuse container');
                    $mech->content_contains('A non-recyclable refuse container request was made');
                    $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
                    $mech->content_contains('bags have not been delivered', 'Option to escalate available');
                    $mech->content_contains('If your bin has not been delivered you can report this delivery as not completed.', 'hint for user correct');
                    $mech->content_lacks('Thank you for reporting an issue with this delivery', 'hint for user correct');
                };
            }
        };

        subtest 'Making an escalation' => sub {
            set_fixed_time($window_start_time);
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok( { url_regex => qr/service_id=940/}, 'Follow "Report a problem" link for Non-Recyclable Waste collection' );
            $mech->submit_form_ok( { with_fields => { category => 'Failure to Deliver Bags/Containers' } });
            $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } });

            $mech->submit_form_ok( { with_fields => { submit => '1' } });
            $mech->content_contains('Your enquiry has been submitted');
            $mech->content_contains('Return to property details');
            $mech->content_contains('/waste/12345"');
            my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            is $report->category, 'Failure to Deliver Bags/Containers', "Correct category";
            is $report->title, 'Issue with delivery';
            is $report->detail, "Non-Recyclable Refuse\n\n2 Example Street, Sutton, SM1 1AA", "Details of report contain information about problem";
            is $report->user->email, 'schmoe@example.org', 'User email added to report';
            is $report->name, 'Joe Schmoe', 'User name added to report';
            is $report->get_extra_field_value('Notes'), 'Originally Echo Event #112112321';
            is $report->get_extra_field_value('container_request_guid'), 'container-request-event-guid';
            is $report->get_extra_field_value('original_ref'), 'LBS-789';
        };

        $e->mock('GetEventsForObject', sub { [] }); # reset
    };

    subtest 'CSV export including escalation information' => sub {
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_like(qr/Complaint against time.*LBS-123/);
        $mech->content_like(qr/Failure to Deliver.*LBS-789/);
    };

    my $template = FixMyStreet::DB->resultset("ResponseTemplate")->create({
        body => $body,
        state => 'cancelled',
        title => 'title',
        text => 'response template text',
        auto_response => 1,
    });
    $template->add_to_contacts($new_container_request_contact);

    foreach ((
        {
            scenario => "with payment",
            payment => 1,
        },
        {
            scenario => "without payment",
            payment => 0,
        },
    )) {
        my $scenario = $_->{scenario};
        my $payment = $_->{payment};

        subtest "Container request $scenario cancellations" => sub {

            my $event_guid = "container-request-event-guid-$scenario";
            my ($container_request_report) = $mech->create_problems_for_body(
                1, $body->id,
                'Container request', {
                    cobrand => 'sutton',
                    external_id => $event_guid,
                    cobrand_data => 'waste',
                    user => $user,
                    title => "Request replacement container",
                    category => "Request new container",
                }
            );
            my @extra_fields = ({
                name => 'service_id',
                value => 940,  # Domestic Refuse Collection
            });
            if ($payment) {
                push @extra_fields, {
                    name => 'payment',
                    value => 100,
                };
            }
            $container_request_report->set_extra_fields(@extra_fields);
            $container_request_report->update;

            my $open_container_request_event = {
                Id => '112112321',
                ServiceId => 940,  # Domestic Refuse Collection
                ClientReference => 'LBS-789',
                EventTypeId => 3129,  # Container request
                EventDate => { DateTime => "2025-02-03T08:00:00Z" },
                Data => { ExtensibleDatum => [
                    { Value => 2, DatatypeName => 'Source' },
                    {
                        ChildData => { ExtensibleDatum => [
                            { Value => 1, DatatypeName => 'Action' },
                            { Value => 1, DatatypeName => 'Container Type' },  # Refuse container
                        ] },
                    },
                ] },
                Guid => $event_guid,
            };
            $e->mock('GetServiceUnitsForObject', sub { $bin_data });
            $e->mock('GetEventsForObject', sub { [$open_container_request_event] });

            my $cancellation_url = "/waste/12345/request/cancel/" . $container_request_report->id;
            my $cancel_form_title = "Cancel your replacement container request";
            set_fixed_time('2025-02-05T08:00:00Z');

            subtest "Link shown" => sub {
                $mech->get_ok('/waste/12345');
                $mech->content_contains($cancellation_url);
                $mech->content_contains('cancel your container order');
                if ($payment) {
                    $mech->content_contains('A refund will not be issued.');
                }
            };

            foreach ((
                {
                    scenario => "Staff",
                    can_cancel => 1,
                    user => $staff,
                },
                {
                    scenario => "The user that made the request",
                    can_cancel => 1,
                    user => $user,
                },
                {
                    scenario => "Random user",
                    can_cancel => 0,
                    user => $user2,
                },
            )) {
                my $can_cancel = $_->{can_cancel};
                my $can_cancel_text = $can_cancel ? 'can cancel' : "can't cancel";
                my $scenario = $_->{scenario};
                my $u = $_->{user};
                subtest "$scenario $can_cancel_text" => sub {
                    $mech->log_in_ok($u->email);
                    $mech->get_ok($cancellation_url);
                    if ($can_cancel) {
                        $mech->content_contains($cancel_form_title);
                    } else {
                        $mech->content_lacks($cancel_form_title);
                    }
                };
            }

            subtest "Cancel" => sub {
                FixMyStreet::DB->resultset('Alert')->create({
                    user => $staff,
                    alert_type => 'new_updates',
                    parameter => $container_request_report->id,
                    confirmed => 1,
                    cobrand => 'sutton',
                    whensubscribed => DateTime->new(year => 1),
                });

                $mech->log_in_ok($user->email);
                $mech->get_ok($cancellation_url);
                $mech->content_contains($cancel_form_title);
                $mech->content_contains("I would like to cancel my container request.");
                if ($payment) {
                    $mech->content_contains("I acknowledge that the payment will not be refunded.");
                }
                $mech->submit_form_ok( { with_fields => { confirm => 1 } } );
                $mech->content_contains("Your replacement container request has been cancelled.");
                $container_request_report->discard_changes;
                is $container_request_report->state, 'cancelled';
                my $latest_comment = $container_request_report->comments->search(
                        {},
                        { order_by => { -desc => 'id' } },
                )->first;
                is $latest_comment->text, "response template text", "cancel update uses response template";

                $mech->clear_emails_ok;
                FixMyStreet::Script::Alerts::send_updates();
                $mech->email_count_is(1);
                my $body = $mech->get_email->as_string;
                contains_string $body, "response template text";
                lacks_string $body, "State changed to:";
            };

            subtest "Link not shown after already cancelled" => sub {
                $mech->log_in_ok($user->email);
                $mech->content_lacks($cancellation_url);
            };
        };
    }

    subtest "Container request cancellation in admin" => sub {
        my ($container_request_report) = $mech->create_problems_for_body(
            1, $body->id,
            'Container request', {
                cobrand => 'sutton',
                external_id => 'container-request',
                cobrand_data => 'waste',
                user => $user,
                title => "Request replacement container",
                category => "Request new container",
            }
        );
        $container_request_report->update({ state => 'confirmed' });
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/admin/report_edit/' . $container_request_report->id);
        $mech->submit_form_ok({ with_fields => { state => 'cancelled' } });
        $container_request_report->discard_changes;
        is $container_request_report->state, 'cancelled';
        my $latest_comment = $container_request_report->comments->search(
                {},
                { order_by => { -desc => 'id' } },
        )->first;
        is $latest_comment->text, "response template text", "cancel update uses response template";
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
    $e->mock('GetPointAddress', sub { $address_data });
    $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    $e->mock('GetEventsForObject', sub { [] });
    $e->mock('GetTasks', sub { [] });
    $e->mock( 'CancelReservedSlotsForEvent', sub {
        my (undef, $guid) = @_;
        ok $guid, 'non-nil GUID passed to CancelReservedSlotsForEvent';
    } );
    return $e;
}

sub shared_scp_mocks {
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
    return $pay;
}

done_testing;
