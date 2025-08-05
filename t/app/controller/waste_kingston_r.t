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

my $bin_data = decode_json(path(__FILE__)->sibling('waste_kingston_4443082.json')->slurp_utf8);
my $kerbside_bag_data = decode_json(path(__FILE__)->sibling('waste_kingston_4471550.json')->slurp_utf8);
my $above_shop_data = decode_json(path(__FILE__)->sibling('waste_4499005.json')->slurp_utf8);

my $params = {
    send_method => 'Open311',
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
    cobrand => 'kingston',
};
my $kingston = $mech->create_body_ok(2480, 'Kingston Council', $params);
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

create_contact({ category => 'Report missed collection', email => '3145' }, 'Waste',
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Request new container', email => '3129' }, 'Waste',
    { code => 'uprn', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Action', required => 1, automated => 'hidden_field' },
    { code => 'Reason', required => 1, automated => 'hidden_field' },
    { code => 'PaymentCode', required => 0, automated => 'hidden_field' },
    { code => 'payment_method', required => 0, automated => 'hidden_field' },
    { code => 'payment', required => 0, automated => 'hidden_field' },
);

# Merton also covers Kingston because of an out-of-area park which is their responsibility
my $merton = $mech->create_body_ok(2500, 'Merton Council');
FixMyStreet::DB->resultset('BodyArea')->create({ area_id => 2480, body_id => $merton->id });
my $contact = $mech->create_contact_ok(body => $merton, category => 'Report missed collection', email => 'missed');
$contact->set_extra_metadata( type => 'waste' );
$contact->update;

my ($sent_params, $sent_data);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'kingston',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { kingston => {
            url => 'http://example.org/',
        } },
        waste => { kingston => 1 },
        echo => { kingston => { bulky_service_id => 986 }},
        payment_gateway => { kingston => {
            cc_url => 'http://example.com',
            request_cost_admin_fee => 1900,
            request_cost_admin_fee_more => 950,
            request_cost_garden_240 => 2300,
            request_cost_paper_240 => 2300,
            request_cost_paper_360 => 3700,
            request_cost_recycling_240 => 2300,
            request_cost_recycling_360 => 3700,
            request_cost_recycling_box => 500,
            request_cost_refuse_180 => 2300,
            request_cost_refuse_240 => 2300,
            request_cost_refuse_360 => 3700,
        } },
        waste_features => { kingston => {
            large_refuse_application_form => '/faq?refuse-application',
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
        $mech->content_like(qr/, at  4:00p\.?m\.?/);
        $mech->content_lacks('Report a mixed recycling collection as missed');
        $mech->content_contains('Report a non-recyclable refuse collection as missed');
        set_fixed_time('2022-09-09T19:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr/, at  4:00p\.?m\.?/);
        $mech->content_lacks('Report a mixed recycling collection as missed');
        $mech->content_contains('Report a non-recyclable refuse collection as missed');
        set_fixed_time('2022-09-13T19:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a non-recyclable refuse collection as missed');
        $e->mock('GetTasks', sub { [] });
    };

    foreach (
        { id => 27, name => 'Blue lid paper and cardboard bin (240L)', service => 974, price => 4200 },
        { id => 12, name => 'Green recycling box (55L)', service => 970, price => 2400 },
        { id => 3, name => 'Black rubbish bin', ordered => 2, service => 966, price => 4200 },
        { id => 15, name => 'Green recycling bin (240L)', service => 970, price => 4200 },
    ) {
        subtest "Request a new $_->{name}" => sub {
            my $ordered = $_->{ordered} || $_->{id};
            $mech->get_ok('/waste/12345/request');
            # 27 (1), 46 (1), 12 (1), 3 (1)
            $mech->content_unlike(qr/Blue lid paper.*Blue lid paper/s);
            $mech->submit_form_ok({ with_fields => { 'container-' . $_->{id} => 1, 'quantity-' . $_->{id} => 1 }});
            if ($_->{id} == 15 || $_->{id} == 12) {
                $mech->submit_form_ok({ with_fields => { 'removal-15' => 0, 'removal-12' => 0 } });
            } else {
                $mech->submit_form_ok({ with_fields => { 'removal-' . $_->{id} => 0 } });
            }
            if ($_->{id} == 3) {
                $mech->submit_form_ok({ with_fields => { 'how_many' => 'less5' }});
            }
            $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
            $mech->content_contains('Continue to payment');

            $mech->waste_submit_check({ with_fields => { process => 'summary' } });
            is $sent_params->{items}[0]{amount}, $_->{price};

            my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
            $mech->get_ok("/waste/pay_complete/$report_id/$token");
            $mech->content_contains('request has been sent');
            $mech->content_contains('>Return to property details<', "Button text changed for Kingston");
            is $report->get_extra_field_value('uprn'), 1000000002;
            is $report->detail, "2 Example Street, Kingston, KT1 1AA";
            is $report->category, 'Request new container';
            is $report->title, "Request $_->{name} delivery";
            is $report->get_extra_field_value('payment'), $_->{price}, 'correct payment';
            is $report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $report->get_extra_field_value('Container_Type'), $ordered, 'correct bin type';
            is $report->get_extra_field_value('Action'), 1, 'correct container request action';
            is $report->get_extra_field_value('service_id'), $_->{service};
            is $report->state, 'unconfirmed', 'report not confirmed';
            is $report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

            FixMyStreet::Script::Reports::send();
            my $req = Open311->test_req_used;
            my $cgi = CGI::Simple->new($req->content);
            is $cgi->param('attribute[Container_Type]'), $ordered;
            is $cgi->param('attribute[Action]'), '1';
            is $cgi->param('attribute[Reason]'), '1';
        };
    }

    subtest "Request a new green bin when you do not have a box" => sub {
        # Switch the one 12 entry to a 15
        $bin_data->[2]{Data}{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value} = '15';
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-15' => 1, 'quantity-15' => 1 }});
        $bin_data->[2]{Data}{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value} = '12';
    };

    subtest 'Request new containers' => sub {
        $mech->get_ok('/waste/12345/request');
        # Missing 3, Damaged 27, Damaged+missing 12, two missing 46
        $mech->content_contains('Only three are allowed per property');
        $mech->submit_form_ok({ with_fields => { 'container-3' => 1, 'container-27' => 1, 'container-12' => 1, 'quantity-12' => 2, 'quantity-46' => 2, 'container-46' => 1, 'quantity-27' => 1 }});
        $mech->submit_form_ok({ with_fields => { 'removal-3' => 0, 'removal-27' => 1, 'removal-12' => 1, 'removal-15' => 1, 'removal-46' => 0 } });
        $mech->submit_form_ok({ with_fields => { 'how_many' => '5more' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Continue to payment');

        $mech->content_like(qr/Food waste bin \(outdoor\)<\/dt>\s*<dd[^>]*>\s*2 to deliver\s*<\/dd>/);
        $mech->content_like(qr/Green recycling box \(55L\)<\/dt>\s*<dd[^>]*>\s*2\s+to deliver,\s+1 to remove\s*<\/dd>/);
        $mech->content_like(qr/Black rubbish bin<\/dt>\s*<dd[^>]*>\s*1 to deliver\s*<\/dd>/);
        $mech->content_like(qr/Blue lid paper and cardboard bin \(240L\)<\/dt>\s*<dd[^>]*>\s*1\s+to deliver,\s+1 to remove\s*<\/dd>/);
        $mech->content_like(qr/Green recycling bin \(240L\)<\/dt>\s*<dd[^>]*>\s*1 to remove\s*<\/dd>/);

        $mech->waste_submit_check({ with_fields => { process => 'summary' } });
        my $pay_params = $sent_params;
        is scalar @{$pay_params->{items}}, 4, 'right number of line items';

        is $sent_data->{sale}{'scpbase:saleSummary'}{'scpbase:amountInMinorUnits'}, 1900+950*3 + 2300*2+500*2, 'correct total';

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        $mech->content_contains('request has been sent');

        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "2 Example Street, Kingston, KT1 1AA";
        is $report->category, 'Request new container';
        is $report->title, 'Request Green recycling box (55L) delivery';
        is $report->get_extra_field_value('payment'), 1900+500, 'correct payment';
        is $report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $report->get_extra_field_value('Container_Type'), 12, 'correct bin type';
        is $report->get_extra_field_value('Action'), 1, 'correct container request action';
        is $report->get_extra_field_value('service_id'), 970;
        is $report->state, 'unconfirmed', 'report not confirmed';
        is $report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        my $sent_count = 1;
        foreach (@{ $report->get_extra_metadata('grouped_ids') }) {
            my $report = FixMyStreet::DB->resultset("Problem")->find($_);
            is $report->get_extra_field_value('uprn'), 1000000002;
            if ($report->title eq 'Request Green recycling bin (240L) collection') {
                is $report->get_extra_field_value('Container_Type'), 15, 'correct bin type';
                is $report->get_extra_field_value('service_id'), 970;
                is $report->get_extra_field_value('payment'), '', 'correct payment';
            } elsif ($report->title =~ /^Request Green recycling box/) {
                is $report->get_extra_field_value('Container_Type'), 12, 'correct bin type';
                is $report->get_extra_field_value('service_id'), 970;
                is $report->get_extra_field_value('payment'), 500+950, 'correct payment';
            } elsif ($report->title eq 'Request Black rubbish bin delivery') {
                is $report->get_extra_field_value('Container_Type'), 3, 'correct bin type';
                is $report->get_extra_field_value('service_id'), 966;
                is $report->get_extra_field_value('payment'), 2300+950, 'correct payment';
            } elsif ($report->title eq 'Request Food waste bin (outdoor) delivery') {
                is $report->get_extra_field_value('Container_Type'), 46, 'correct bin type';
                is $report->get_extra_field_value('service_id'), 980;
                is $report->get_extra_field_value('payment'), "", 'correct payment';
            } elsif ($report->title eq 'Request Blue lid paper and cardboard bin (240L) replacement') {
                is $report->get_extra_field_value('Container_Type'), 27, 'correct bin type';
                is $report->get_extra_field_value('service_id'), 974;
                is $report->get_extra_field_value('payment'), 2300+950, 'correct payment';
            } else {
                is $report->title, 'BAD';
            }
            is $report->detail, "2 Example Street, Kingston, KT1 1AA";
            is $report->category, 'Request new container';
            is $report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            if ($report->title =~ /replacement$/) {
                is $report->get_extra_field_value('Action'), '2::1', 'correct container request action';
            } elsif ($report->title =~ /collection$/) {
                is $report->get_extra_field_value('Action'), 2, 'correct container request action';
            } else {
                is $report->get_extra_field_value('Action'), 1, 'correct container request action';
            }
            is $report->state, 'confirmed', 'report confirmed';
            is $report->get_extra_metadata('scpReference'), undef, 'only original report has SCP ref';
            next if $report->title =~ /Food|collection/;
            is $pay_params->{items}[$sent_count]{description}, $report->title;
            is $pay_params->{items}[$sent_count]{lineId}, 'RBK-CCH-' . $report->id . '-Bob Marge';
            is $pay_params->{items}[$sent_count]{amount}, $sent_count == 0 ? 1900 : $report->title =~ /box/ ? 500+950 : 2300+950;
            $sent_count++;
        }

        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        # Not sure which one will have been sent last
        like $cgi->param('attribute[Action]'), qr/^(1|2|2::1)$/;
        like $cgi->param('attribute[Reason]'), qr/^[148]$/;
    };

    subtest 'Request refuse exchange' => sub {
        subtest "240L, ordering a larger" => sub {
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok({ text => 'Request a larger/smaller refuse container' });
            $mech->content_contains('Smaller black rubbish bin');
            $mech->content_contains('Larger black rubbish bin');
            $mech->submit_form_ok({ with_fields => { 'container-capacity-change' => 4 } });
            is $mech->uri->path_query, '/faq?refuse-application?uprn=1000000002';
        };
        subtest '180L, small household' => sub {
            $bin_data->[3]{Data}{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value} = '2';
            $mech->get_ok('/waste/12345/request?exchange=1');
            $mech->submit_form_ok({ with_fields => { 'how_many_exchange' => 'less5' }});
            $mech->content_contains('You already have the biggest sized bin allowed.');
        };
        subtest '180L, very large household' => sub {
            $bin_data->[3]{Data}{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value} = '2';
            $mech->get_ok('/waste/12345/request?exchange=1');
            $mech->submit_form_ok({ with_fields => { 'how_many_exchange' => '7more' }});
            $mech->content_contains('you can apply for more capacity');
        };
        my %names = (
            1 => 'Black rubbish bin (140L)',
            2 => 'Black rubbish bin (180L)',
            3 => 'Black rubbish bin (240L)',
            4 => 'Black rubbish bin (360L)',
        );
        foreach (
            { has => 3, id => 2 }, # 240L going smaller
            { has => 2, id => 3 }, # 180L, 5 or 6 people
            { has => 4, id => 2 }, # 360L going smaller
            { has => 4, id => 3 }, # 360L going smaller
        ) {
            subtest "Has a $names{$_->{has}}, ordering a $names{$_->{id}}" => sub {
                $bin_data->[3]{Data}{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value} = $_->{has};
                $mech->get_ok('/waste/12345/request?exchange=1');
                if ($_->{has} == 3) {
                    $mech->content_contains('Smaller black rubbish bin');
                    $mech->content_contains('Larger black rubbish bin');
                }
                if ($_->{has} == 2) {
                    $mech->submit_form_ok({ with_fields => { 'how_many_exchange' => '5or6' }});
                } else {
                    $mech->submit_form_ok({ with_fields => { 'container-capacity-change' => $_->{id} } });
                }
                $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
                $mech->content_contains('Continue to payment');

                $mech->waste_submit_check({ with_fields => { process => 'summary' } });
                is $sent_params->{items}[0]{amount}, 2300+1900;

                my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
                $mech->get_ok("/waste/pay_complete/$report_id/$token");
                $mech->content_contains('request has been sent');
                is $report->get_extra_field_value('uprn'), 1000000002;
                is $report->detail, "2 Example Street, Kingston, KT1 1AA";
                is $report->category, 'Request new container';
                is $report->title, "Request $names{$_->{id}} replacement";
                is $report->get_extra_field_value('payment'), 2300+1900, 'correct payment';
                is $report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
                is $report->get_extra_field_value('Container_Type'), "$_->{has}::$_->{id}", 'correct bin type';
                is $report->get_extra_field_value('Action'), '2::1', 'correct container request action';
                is $report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';
                is $report->get_extra_field_value('service_id'), 966;

                FixMyStreet::Script::Reports::send();
                my $req = Open311->test_req_used;
                my $cgi = CGI::Simple->new($req->content);
                is $cgi->param('attribute[Action]'), '2::1';
                is $cgi->param('attribute[Reason]'), $_->{has} < $_->{id} ? 9 : 10;
            };
        }
    };
    # Reset back to 240L
    $bin_data->[3]{Data}{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value} = '3';

    subtest 'Request bins from front page' => sub {
        $mech->get_ok('/waste/12345');
        $mech->submit_form_ok({ form_number => 7 });
        $mech->content_contains('name="container-3" value="1"');
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

        $mech->submit_form_ok({ with_fields => { 'service-980' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Thank you for reporting a missed collection');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Report missed Food waste\n\n2 Example Street, Kingston, KT1 1AA";
        is $report->title, 'Report missed Food waste';
        is $report->bodies_str, $kingston->id, 'correct bodies_str';
    };
    subtest 'No reporting/requesting if open request' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a mixed recycling collection as missed');
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
        $mech->content_contains('Report a mixed recycling collection as missed');
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
                        { Value => 43, DatatypeName => 'Container Type' },
                    ] },
                },
            ] },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A food waste container request has been made');
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-43" value="1"[^>]+disabled/s); # indoor
        $mech->content_like(qr/name="container-46" value="1"[^>]+>/s); # outdoor

        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 3145,
            EventStateId => 0,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 970,
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A mixed recycling collection has been reported as missed');
        $mech->content_contains('Request a mixed recycling container');

        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 3145,
            EventStateId => 0,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 974,
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A paper and card collection has been reported as missed');

        $e->mock('GetEventsForObject', sub { [] }); # reset
    };

    $e->mock('GetServiceUnitsForObject', sub { $kerbside_bag_data });
    subtest 'No requesting a red stripe bag' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->content_lacks('"container-10" value="1"');
    };
    subtest 'No requesting a blue stripe bag' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->content_lacks('"container-22" value="1"');
        $e->mock('GetServiceUnitsForObject', sub { $above_shop_data });
        $mech->get_ok('/waste/12345/request');
        $mech->content_lacks('"container-22" value="1"');
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

    # Mocking out only the pay response
    $pay->mock(credentials => sub { {} });
    $pay->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $sent_data = { @_ };
        return {
            transactionState => 'IN_PROGRESS',
            scpReference => '12345',
            invokeResult => {
                status => 'SUCCESS',
                redirectUrl => 'http://example.org/faq'
            }
        };
    });
    $pay->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        return $pay->original('pay')->($self, $sent_params);
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
