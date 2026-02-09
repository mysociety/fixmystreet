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
my $communal_multi_task_data = decode_json(path(__FILE__)->sibling('waste_kingston_2666182.json')->slurp_utf8);

my $params = {
    send_method => 'Open311',
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
    cobrand => 'kingston',
};
my $kingston = $mech->create_body_ok(2480, 'Kingston Council', $params, {
        wasteworks_config => { request_timeframe_raw => 10, request_timeframe => '10 working days' }
    });
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');

sub create_contact {
    my ($params, $group, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $kingston, %$params, group => [$group]);
    $contact->set_extra_metadata( type => 'waste' );
    $contact->set_extra_fields(@extra);
    $contact->update;
}

create_contact({ category => 'Report missed collection', email => '3145' }, 'Waste',
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Request new container', email => '3129' }, 'Waste',
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Action', required => 1, automated => 'hidden_field' },
    { code => 'Reason', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 0, automated => 'hidden_field' },
    { code => 'payment', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'Complaint against time', email => '3134' }, 'Waste',
    { code => 'Notes', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'original_ref', required => 1, automated => 'hidden_field' },
);

create_contact({ category => 'Failure to Deliver Bags/Containers', email => '3141' }, 'Waste',
    { code => 'Notes', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'original_ref', required => 1, automated => 'hidden_field' },
    { code => 'container_request_guid', required => 0, automated => 'hidden_field' },
);

create_contact(
    { category => 'Report out-of-time missed collection', email => 3140 },
    'Waste',
    { code => 'Notes', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
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
        $mech->content_contains('Every other Friday');
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
            is $report->uprn, 1000000002;
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

        is $report->uprn, 1000000002;
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
            is $report->uprn, 1000000002;
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
                is $report->uprn, 1000000002;
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
        is $report->uprn, 1000000002;
        is $report->detail, "Report missed Food waste\n\n2 Example Street, Kingston, KT1 1AA";
        is $report->title, 'Report missed Food waste';
        is $report->bodies_str, $kingston->id, 'correct bodies_str';
    };
    subtest 'Report missed collection out of time - can make non-actionable report' => sub {
        set_fixed_time('2022-09-14T19:00:00Z');

        $mech->get_ok('/waste/12345/report');
        is $mech->uri->path, '/waste/12345',
            'redirected as nothing to report via normal missed collection path';

        $mech->content_contains('Report a paper and card collection as missed');
        $mech->content_contains('Report a food waste collection as missed');

        $mech->follow_link_ok(
            { text_regex => qr/Report a food waste collection as missed/ } );

        # About you
        $mech->submit_form_ok(
            { with_fields => { name => 'Bob Marge', email => $user->email } }
        );

        # Summary.
        # Is an enquiry form but should look like a missed collection.
        $mech->content_contains('Submit missed bin report');
        $mech->content_contains('before you submit your missed collection');
        $mech->content_like(qr/govuk-summary-list__key.*Missed collection/s);
        $mech->content_contains('Food waste');
        $mech->content_contains('Friday, 9th September');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });

        # Confirmation page
        $mech->content_contains('Thank you for reporting a missed collection');
        $mech->content_contains('A copy has been sent to your email address');
        $mech->content_lacks('Your reference number');

        # Check report
        my $report
            = FixMyStreet::DB->resultset("Problem")
            ->search( undef, { order_by => { -desc => 'id' } } )
            ->first;
        my $report_id = $report->id;

        is $report->category, 'Report out-of-time missed collection';
        is $report->title, 'Report missed Food waste';
        is $report->get_extra_field_value('service_id'), 980;
        is $report->get_extra_field_value('Notes'), 'Non-actionable missed collection report';
        is $report->state, 'confirmed', 'Report is initially confirmed';

        # Send report
        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send(0,0,0,$report_id);

        # Check again - should be closed
        $report->discard_changes;
        is $report->state, 'no further action',
            'Report is closed - no further action';

        # Check email
        $mech->email_count_is(1);
        my $email = $mech->get_email;
        unlike $email->header('Subject'), qr/RBK-$report_id/,
            'no report ID in subject';

        my $html = $mech->get_html_body_from_email($email);
        like $html, qr/missed Food waste/;
        unlike $html, qr/RBK-$report_id/, 'no report ID in HTML';

        my $plain = $mech->get_text_body_from_email($email);
        like $plain, qr/Food waste/;
        unlike $plain, qr/RBK-$report_id/, 'no report ID in plaintext';

        # Mock enquiry event
        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 3140,
            EventDate => { DateTime => "2022-09-14T19:00:00Z" },
            ServiceId => 980,
        } ] });

        $mech->get_ok('/waste/12345');
        $mech->content_like(
            qr/food waste.*reported as missed.*on Wednesday, 14 September/s);
        $mech->content_lacks('Report a food waste collection as missed');

        set_fixed_time('2022-09-13T19:00:00Z');
        $e->mock( 'GetEventsForObject', sub { [] } );
    };

    subtest 'No reporting/requesting if open request' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a mixed recycling collection as missed');
        $mech->content_contains('Request a mixed recycling container');

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
        $mech->content_contains('A mixed recycling container request was made');
        $mech->content_contains('Report a mixed recycling collection as missed');
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-12" value="1"[^>]+disabled/s); # green

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
        $mech->content_contains('A food waste container request was made');
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-43" value="1"[^>]+disabled/s); # indoor
        $mech->content_like(qr/name="container-46" value="1"[^>]+>/s); # outdoor

        set_fixed_time('2022-09-12T19:00:00Z');
        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 3145,
            EventStateId => 0,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 970,
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A mixed recycling collection has been reported as missed');
        $mech->content_contains('We aim to resolve this by Tuesday, 13 September');
        $mech->content_contains('Request a mixed recycling container');
        set_fixed_time('2022-09-13T19:00:00Z');

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

    subtest 'Okay with a property with multiple one-schedule service tasks' => sub {
        $e->mock('GetServiceUnitsForObject', sub { $communal_multi_task_data });
        $e->mock('GetServiceTaskInstances', sub {
            # Check both task IDs are passed in to get them all
            is $_[3], '22988289';
            is $_[4], '24130503';
            return [];
        });
        set_fixed_time('2025-10-16T16:46:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr/Next collection<\/dt>\s*<dd[^>]*>\s*Friday, 17th October/);
        $mech->content_like(qr/Last collection<\/dt>\s*<dd[^>]*>\s*Friday, 10th October/);
        set_fixed_time('2025-10-08T16:46:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr/Next collection<\/dt>\s*<dd[^>]*>\s*Friday, 10th October/);
        $mech->content_like(qr/Last collection<\/dt>\s*<dd[^>]*>\s*Friday, 3rd October/);
        $mech->get_ok('/waste/12345/calendar.ics');
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

    subtest 'Escalations of missed collections' => sub {
        subtest 'No missed collection' => sub {
            set_fixed_time('2022-09-10T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');

            set_fixed_time('2022-09-13T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');

            set_fixed_time('2022-09-15T17:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');

            set_fixed_time('2022-09-15T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');
        };

        subtest 'Open missed collection but by a different flat' => sub {
            # So say this result was what was returned by a ServiceUnit GetEventsForObject call, not the address one
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19240, # Allocated to Crew
                ServiceId => 966, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12346 } } } ] },
            } ] });

            set_fixed_time('2022-09-13T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');
        };

        subtest 'Open missed collection' => sub {
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                ClientReference => 'LBS-123',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19240, # Allocated to Crew
                ServiceId => 966, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-10T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');

            set_fixed_time('2022-09-13T23:59:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');

            set_fixed_time('2022-09-14T00:01:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_contains('please report the problem here');

            subtest 'actually make the report' => sub {
                $mech->follow_link_ok({ text => 'please report the problem here' });
                $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } });
                $mech->submit_form_ok( { with_fields => { submit => '1' } });
                $mech->content_contains('Your enquiry has been submitted');
                $mech->content_contains('Return to property details');
                $mech->content_contains('/waste/12345"');
                my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
                is $report->category, 'Complaint against time', "Correct category";
                is $report->title, 'Issue with collection';
                is $report->detail, "Non-recyclable Refuse\n\n2 Example Street, Kingston, KT1 1AA", "Details of report contain information about problem";
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
                        ServiceId => 966, # Refuse
                        EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                        EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
                    },
                    {
                        Id => '112112321',
                        ClientReference => 'LBS-123',
                        EventTypeId => 3134, # Missed collection escalation
                        EventStateId => 19240, # Allocated to Crew
                        ServiceId => 966, # Refuse
                        EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                        EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
                    }
                ] });
                $mech->get_ok('/waste/12345');
                $mech->content_contains("We aim to resolve this by Monday, 12 September");
            };

            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                ClientReference => 'LBS-123',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19240, # Allocated to Crew
                ServiceId => 966, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-14T17:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_contains('please report the problem here');

            set_fixed_time('2022-09-15T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');
        };

        subtest 'Completed missed collection - no escalation' => sub {
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19241, # Completed
                ResolvedDate => { DateTime => "2022-09-10T17:00:00Z" },
                ServiceId => 966, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-10T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');

            set_fixed_time('2022-09-13T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');

            set_fixed_time('2022-09-15T17:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');

            set_fixed_time('2022-09-15T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');
        };

        subtest 'Not Completed missed collection' => sub {
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3145, # Missed collection
                EventStateId => 19242, # Not Completed
                ResolvedDate => { DateTime => "2022-09-10T17:00:00Z" },
                ServiceId => 966, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-10T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');

            set_fixed_time('2022-09-13T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');

            set_fixed_time('2022-09-15T17:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');

            set_fixed_time('2022-09-15T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');
        };

        subtest 'Existing escalation event' => sub {
            # Now mock there is an existing escalation
            $e->mock('GetEventsForObject', sub { [ {
                Id => '112112321',
                EventTypeId => 3145, # Missed collection
                EventStateId => 0,
                ServiceId => 966, # Refuse
                EventDate => { DateTime => "2022-09-10T17:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            }, {
                Id => '112112322',
                EventTypeId => 3134, # Complaint against time
                EventStateId => 0,
                ServiceId => 966, # Refuse
                EventDate => { DateTime => "2022-09-13T19:00:00Z" },
                EventObjects => { EventObject => [ { EventObjectType => 'Source', ObjectRef => { Key => "Id", Type => "PointAddress", Value => { anyType => 12345 } } } ] },
            } ] });

            set_fixed_time('2022-09-14T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');
            $mech->content_contains('Thank you for reporting an issue with this collection; we are investigating.');
        };

        $e->mock('GetEventsForObject', sub { [] }); # reset
    };

    subtest 'Escalations of container delivery failure' => sub {
        my $request_time = "2025-02-03T08:00:00Z";

        my $window_start_time = "2025-02-17T00:00:00Z";
        my $just_before_window = "2025-02-16T23:59:59Z";

        my $window_end_time = "2025-03-03T23:59:59Z";
        my $just_after_window = "2025-03-04T00:00:00Z";

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
                        { Value => 3, DatatypeName => 'Container Type' }, # Refuse container
                    ] },
                },
            ] },
            Guid => 'container-request-event-guid',
        };
        my $escalation_event = {
            Id => '112112323',
            EventTypeId => 3141, # Failure to Deliver Bags/Containers
            EventStateId => 0,
            ServiceId => 966, # Refuse
            EventDate => { DateTime => "2025-02-19T19:00:00Z" },
            Guid => 'container-escalation-event-guid',
        };
        my ($escalation_report) = $mech->create_problems_for_body(
            1, $kingston->id,
            'Container escalation', {
                cobrand => 'kingston',
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
                    $mech->content_lacks('please report the problem here');
                    $mech->content_contains('A non-recyclable refuse container request was made on Monday, 3 February');
                    $mech->content_contains('Thank you for reporting an issue with this delivery; we are investigating and aim to deliver the container by Wednesday, 26 February.');
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
                    $mech->content_lacks('please report the problem here');
                    $mech->content_contains('A non-recyclable refuse container request was made on Monday, 3 February');
                    $mech->content_lacks('Thank you for reporting an issue with this delivery');
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
                    $mech->content_contains('please report the problem here');
                    $mech->content_contains('A non-recyclable refuse container request was made on Monday, 3 February');
                    $mech->content_contains('We expect to deliver your container on or before Monday, 17 February');
                    $mech->content_lacks('Thank you for reporting an issue with this delivery');
                };
            }
        };

        subtest 'Making an escalation' => sub {
            set_fixed_time($window_start_time);
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok({ text => 'please report the problem here' });

            $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } });

            $mech->submit_form_ok( { with_fields => { submit => '1' } });
            $mech->content_contains('Your enquiry has been submitted');
            $mech->content_contains('Return to property details');
            $mech->content_contains('/waste/12345"');
            my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            is $report->category, 'Failure to Deliver Bags/Containers', "Correct category";
            is $report->title, 'Issue with delivery';
            is $report->detail, "Non-recyclable Refuse\n\n2 Example Street, Kingston, KT1 1AA", "Details of report contain information about problem";
            is $report->user->email, 'schmoe@example.org', 'User email added to report';
            is $report->name, 'Joe Schmoe', 'User name added to report';
            is $report->get_extra_field_value('Notes'), 'Originally Echo Event #112112321';
            is $report->get_extra_field_value('container_request_guid'), 'container-request-event-guid';
            is $report->get_extra_field_value('original_ref'), 'LBS-789';
        };

        $e->mock('GetEventsForObject', sub { [] }); # reset

        subtest "No open request; can't escalate" => sub {
            foreach my $config ((
                { 'time' => $window_start_time, label => 'window start' },
                { 'time' => $window_end_time,  label => 'window end' },
            )) {
                subtest $config->{label} => sub {
                    set_fixed_time($config->{time});
                    $mech->get_ok('/waste/12345');
                    $mech->content_contains('Request a non-recyclable refuse container');
                    $mech->content_lacks('please report the problem here');
                    $mech->content_lacks('A non-recyclable refuse container request was made');
                    $mech->content_lacks('Thank you for reporting an issue with this delivery');
                };
            }
        };
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
