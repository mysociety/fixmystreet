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
my $kingston = $mech->create_body_ok(2480, 'Kingston Council', $params, { cobrand => 'kingston' });
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');

sub create_contact {
    my ($params, $group, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $kingston, %$params, group => [$group]);
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
    { code => 'LastPayMethod', required => 0, automated => 'hidden_field' },
    { code => 'PaymentCode', required => 0, automated => 'hidden_field' },
    { code => 'payment_method', required => 0, automated => 'hidden_field' },
    { code => 'payment', required => 0, automated => 'hidden_field' },
);

my $sent_params;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'kingston',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { kingston => {
            url => 'http://example.org/',
        } },
        waste => { kingston => 1 },
        echo => { kingston => { bulky_service_id => 413 }},
        payment_gateway => { kingston => {
            cc_url => 'http://example.com',
            request_replace_cost => 1800,
            request_replace_cost_more => 900,
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
        $mech->content_contains('2 Example Street, Kingston');
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
        $mech->content_unlike(qr/Blue lid paper.*Blue lid paper/s);
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 19 }});
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' }});
        $mech->submit_form_ok({ with_fields => { 'notes_damaged' => 'collection' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Continue to payment');

        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 1800;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Kingston, KT1 1AA\n\nReason: My container is damaged - Damaged during collection";
        is $report->category, 'Request new container';
        is $report->title, 'Request new Blue lid paper and cardboard bin (240L)';
        is $report->get_extra_field_value('payment'), 1800, 'correct payment';
        is $report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $report->get_extra_field_value('Container_Type'), 19, 'correct bin type';
        is $report->get_extra_field_value('Action'), 3, 'correct container request action';
        is $report->state, 'unconfirmed', 'report not confirmed';
        is $report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '3';
        is $cgi->param('attribute[Reason]'), '2';
    };
    subtest 'Report a new recycling raises a bin delivery request' => sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 16 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'missing' }});
        $mech->submit_form_ok({ with_fields => { 'notes_missing' => 'Were there, now not' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 1800;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');
        $mech->content_contains('>Return to property details<', "Button text changed for Kingston");
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Kingston, KT1 1AA\n\nReason: My container is missing - Were there, now not";
        is $report->title, 'Request new Green recycling box (55L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '1';
        is $cgi->param('attribute[Reason]'), '1';
    };
    subtest 'Request a new damaged recycling box' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 16 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' }});
        $mech->submit_form_ok({ with_fields => { 'notes_damaged' => 'wear' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 1800;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Kingston, KT1 1AA\n\nReason: My container is damaged - Wear and tear";
        is $report->title, 'Request new Green recycling box (55L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '3';
        is $cgi->param('attribute[Reason]'), '2';
    };
    subtest 'Request more recycling boxes' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 16 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'more' }});
        $mech->submit_form_ok({ with_fields => { 'recycling_swap' => 'No' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 1800;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Kingston, KT1 1AA\n\nReason: I need an additional container/bin";
        is $report->title, 'Request new Green recycling box (55L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '1';
        is $cgi->param('attribute[Reason]'), '3';
    };
    subtest 'Request recycling boxes bin swap' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 16 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'more' }});
        $mech->submit_form_ok({ with_fields => { 'recycling_swap' => 'Yes' }});
        $mech->submit_form_ok({ with_fields => { 'recycling_swap_confirm' => 1 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 1800;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Kingston, KT1 1AA\n\nReason: I need an additional container/bin";
        is $report->title, 'Request new Green recycling bin (240L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Container_Type]'), '16::16::16::12';
        is $cgi->param('attribute[Action]'), '2::2::2::1';
        is $cgi->param('attribute[Reason]'), '3::3::3::3';
    };
    subtest 'Request recycling bin replacement, no additional' => sub {
        my $clone = dclone($bin_data);
        # Change 16/3 to 12/1
        $clone->[0]->{ServiceTasks}{ServiceTask}[3]{Data}{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value} = "12";
        $clone->[0]->{ServiceTasks}{ServiceTask}[3]{Data}{ExtensibleDatum}{ChildData}{ExtensibleDatum}[1]{Value} = "1";
        $e->mock('GetServiceUnitsForObject', sub { $clone });
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 12 } });
        $mech->content_lacks('more');
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' }});
        $mech->submit_form_ok({ with_fields => { 'notes_damaged' => 'other' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 1800;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Kingston, KT1 1AA\n\nReason: My container is damaged - Other damage";
        is $report->title, 'Request new Green recycling bin (240L)';
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Container_Type]'), '12';
        is $cgi->param('attribute[Action]'), '3';
        is $cgi->param('attribute[Reason]'), '2';
        $e->mock('GetServiceUnitsForObject', sub { $bin_data });
    };

    subtest 'Request new containers' => sub {
        $mech->get_ok('/waste/12345/request?new=1');
		# 19 (1), 24 (1), 16 (1), 1 (1)
        $mech->submit_form_ok({ with_fields => { 'container-1' => 1, 'container-19' => 1, 'container-16' => 1, 'quantity-16' => 2, 'quantity-24' => 2, 'container-24' => 1 }});
        $mech->submit_form_ok({ with_fields => { 'how_many' => '5more' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Continue to payment');

        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        is $sent_params->{items}[0]{amount}, 4500;

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');

        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Kingston, KT1 1AA";
        is $report->category, 'Request new container';
        is $report->title, 'Request new Black rubbish bin';
        is $report->get_extra_field_value('payment'), 4500, 'correct payment';
        is $report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $report->get_extra_field_value('Container_Type'), 2, 'correct bin type';
        is $report->get_extra_field_value('Action'), 1, 'correct container request action';
        is $report->state, 'unconfirmed', 'report not confirmed';
        is $report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        foreach (@{ $report->get_extra_metadata('grouped_ids') }) {
            my $report = FixMyStreet::DB->resultset("Problem")->find($_);
            is $report->get_extra_field_value('uprn'), 1000000002;
            if ($report->title eq 'Request new Green recycling box (55L)') {
                is $report->get_extra_field_value('Container_Type'), 16, 'correct bin type';
            } elsif ($report->title eq 'Request new Food waste bin (outdoor)') {
                is $report->get_extra_field_value('Container_Type'), 24, 'correct bin type';
            } elsif ($report->title eq 'Request new Blue lid paper and cardboard bin (240L)') {
                is $report->get_extra_field_value('Container_Type'), 19, 'correct bin type';
            } else {
                is $report->title, 'BAD';
            }
            is $report->detail, "Quantity: 1\n\n2 Example Street, Kingston, KT1 1AA";
            is $report->category, 'Request new container';
            is $report->get_extra_field_value('payment'), 4500, 'correct payment';
            is $report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $report->get_extra_field_value('Action'), 1, 'correct container request action';
            is $report->state, 'confirmed', 'report confirmed';
            is $report->get_extra_metadata('scpReference'), undef, 'only original report has SCP ref';
        }

        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[Action]'), '1';
        is $cgi->param('attribute[Reason]'), '3';
    };
    subtest 'Request bins from front page' => sub {
        $mech->get_ok('/waste/12345');
        $mech->submit_form_ok({ form_number => 7 });
        $mech->content_contains('name="container-choice" value="1"');
        $mech->content_contains('Blue lid paper and cardboard bin');
        $mech->content_contains('Green recycling box');
        $mech->content_contains('Food waste bin (outdoor)');
        $mech->content_contains('Black rubbish bin');
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
        is $report->detail, "Report missed Food waste\n\n2 Example Street, Kingston, KT1 1AA";
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
        $mech->content_contains('Report a mixed recycling collection as missed');
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-choice" value="16"[^>]+disabled/s); # green

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
        $mech->content_like(qr/name="container-choice" value="23"\s+disabled/s); # indoor
        $mech->content_like(qr/name="container-choice" value="24"\s*>/s); # outdoor

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
        $mech->content_lacks('"container-choice" value="6"');
    };
    subtest 'Fortnightly collection can request a blue stripe bag' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 18 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Kingston, KT1 1AA\n\nReason: Additional bag required";
        is $report->category, 'Request new container';
        is $report->title, 'Request new Recycling Blue Stripe Bag';
    };
    subtest 'Weekly collection cannot request a blue stripe bag' => sub {
        $e->mock('GetServiceUnitsForObject', sub { $above_shop_data });
        $mech->get_ok('/waste/12345/request');
        $mech->content_lacks('"container-choice" value="18"');
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
            Coordinates => { GeoPoint => { Latitude => 51.408688, Longitude => -0.304465 } },
            Description => '2 Example Street, Kingston, KT1 1AA',
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
