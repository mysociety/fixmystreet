use utf8;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2482, 'Bromley Council');
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $body, name => 'Staff User');
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_another_user' });
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'report_mark_private' });

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => ['Waste']);
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Report missed collection', email => 'missed@example.org' });
create_contact({ category => 'Request new container', email => 'request@example.org' },
    { code => 'Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Action', required => 0, automated => 'hidden_field' },
    { code => 'Reason', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'General enquiry', email => 'general@example.org' },
    { code => 'Notes', description => 'Notes', required => 1, datatype => 'text' },
    { code => 'Source', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'New Garden Subscription', email => 'garden@example.com'},
        { code => 'Subscription_Type', required => 1, automated => 'hidden_field' },
        { code => 'Subscription_Details_Quantity', required => 1, automated => 'hidden_field' },
        { code => 'Subscription_Details_Container_Type', required => 1, automated => 'hidden_field' },
        { code => 'Container_Request_Details_Quantity', required => 1, automated => 'hidden_field' },
        { code => 'Container_Request_Details_Action', required => 1, automated => 'hidden_field' },
        { code => 'Container_Request_Details_Container_Type', required => 1, automated => 'hidden_field' },
        { code => 'current_containers', required => 1, automated => 'hidden_field' },
        { code => 'new_containers', required => 1, automated => 'hidden_field' },
        { code => 'payment_method', required => 1, automated => 'hidden_field' },
        { code => 'payment', required => 1, automated => 'hidden_field' },
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bromley',
    COBRAND_FEATURES => { echo => { bromley => {
        sample_data => 1, address_types => [ 1, 2, 3 ],
    } }, waste => { bromley => 1 } },
}, sub {
    subtest 'Address type check' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->content_lacks('13345');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['bromley', 'fixmystreet'],
    COBRAND_FEATURES => { echo => { bromley => { sample_data => 1 } }, waste => { bromley => 1 }, payment_gateway => { bromley => { ggw_cost => 1000 } } },
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->host('bromley.fixmystreet.com');
    subtest 'UPRN redirect' => sub {
        $mech->get_ok('/property/1000000002');
        is $mech->uri->path, '/waste/12345';
    };
    subtest 'Missing address lookup' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->content_contains('13345'); # For comparing against type check below
        $mech->submit_form_ok({ with_fields => { address => 'missing' } });
        $mech->content_contains('can’t find your address');
    };
    subtest 'Address lookup' => sub {
        set_fixed_time('2020-05-28T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => '12345' } });
        $mech->content_contains('2 Example Street');
        $mech->content_contains('Food Waste');
        $mech->content_contains('every other Monday');
    };
    subtest 'Thing already requested' => sub {
        $mech->content_contains('A food waste collection has been reported as missed');
        $mech->content_contains('A paper &amp; cardboard collection has been reported as missed'); # as part of service unit, not property
    };
    subtest 'Report a missed bin' => sub {
        $mech->content_contains('service-531', 'Can report, last collection was 27th');
        $mech->content_lacks('service-537', 'Cannot report, last collection was 27th but the service unit has a report');
        $mech->content_lacks('service-535', 'Cannot report, last collection was 20th');
        $mech->content_lacks('service-542', 'Cannot report, last collection was 18th');
        $mech->follow_link_ok({ text => 'Report a missed collection' });
        $mech->content_contains('service-531', 'Checkbox, last collection was 27th');
        $mech->content_lacks('service-537', 'No checkbox, last collection was 27th but the service unit has a report');
        $mech->content_lacks('service-535', 'No checkbox, last collection was 20th');
        $mech->content_lacks('service-542', 'No checkbox, last collection was 18th');
        $mech->submit_form_ok({ form_number => 2 });
        $mech->content_contains('Please specify what was missed');
        $mech->submit_form_ok({ with_fields => { 'service-531' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => "Test" } });
        $mech->content_contains('Please enter your full name');
        $mech->content_contains('Please specify at least one of phone or email');
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", phone => '+441234567890' } });
        $mech->content_contains('Please specify an email address');
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => 'test@example.org' } });
        $mech->content_contains('Non-Recyclable Refuse');
        $mech->content_contains('Test McTest');
        $mech->content_contains('test@example.org');
        $mech->submit_form_ok({ form_number => 3 });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email } });
        $mech->content_contains($user->email);
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Now check your email');
        my $email = $mech->get_email;
        is $email->header('Subject'), 'Confirm your report on Bromley Recycling Services';
        my $link = $mech->get_link_from_email($email);
        $mech->clear_emails_ok;
        $mech->get_ok($link);
        $mech->content_contains('Your missed collection has been reported');
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        is $emails[0]->header('To'), '"Bromley Council" <missed@example.org>';
        is $emails[1]->header('To'), $user->email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Your report to Bromley Council has been logged/;

        is $user->alerts->count, 1;
        $mech->clear_emails_ok;
    };
    subtest 'Check report visibility' => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->first;
        my $res = $mech->get('/report/' . $report->id);
        is $res->code, 403;
        $mech->log_in_ok($user->email);
        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks('Provide an update');
        $report->update({ state => 'fixed - council' });
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks('Provide an update');
        $mech->content_contains( '<a href="/waste/12345">See your bin collections</a>' );

        $mech->host('www.fixmystreet.com');
        $res = $mech->get('/report/' . $report->id);
        is $res->code, 404;
        $mech->log_in_ok($user->email);
        $res = $mech->get('/report/' . $report->id);
        is $res->code, 404;
        $mech->log_in_ok($staff_user->email);
        $res = $mech->get('/report/' . $report->id);
        is $res->code, 404;
        $mech->host('bromley.fixmystreet.com');
    };
    subtest 'Request a new container' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ form_number => 2 });
        $mech->content_contains('Please specify what you need');
        $mech->submit_form_ok({ with_fields => { 'container-1' => 1 } });
        $mech->content_contains('Quantity field is required');
        $mech->submit_form_ok({ with_fields => { 'container-1' => 1, 'quantity-1' => 2 } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email } });
        $mech->content_contains('Green Box');
        $mech->content_contains('Test McTest');
        $mech->content_contains($user->email);
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your container request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->get_extra_field_value('Quantity'), 2;
        is $report->get_extra_field_value('Container_Type'), 1;
        is $report->get_extra_field_value('Action'), '';
        is $report->get_extra_field_value('Reason'), '';
    };
    subtest 'Request a replacement garden container' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/<input type="hidden" name="quantity-44" id="quantity-44" value="1">/);
        $mech->submit_form_ok({ form_number => 2 });
        $mech->content_contains('Please specify what you need');
        $mech->submit_form_ok({ with_fields => { 'container-44' => 1 } });
        $mech->submit_form_ok({ with_fields => { replacement_reason => 'damaged' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email } });
        $mech->content_contains('Garden Waste');
        $mech->content_contains('Test McTest');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your container request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->title, 'Request new Garden Waste Container';
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->get_extra_field_value('Quantity'), 1;
        is $report->get_extra_field_value('Container_Type'), 44;
        is $report->get_extra_field_value('Reason'), 3;
        is $report->get_extra_field_value('Action'), '2::1';
    };
    subtest 'Request multiple bins' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-9' => 1, 'quantity-9' => 2, 'container-10' => 1, 'quantity-10' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email } });
        $mech->content_like(qr{Outside Food Waste Container</dt>\s*<dd[^>]*>1</dd>});
        $mech->content_like(qr{Kitchen Caddy</dt>\s*<dd[^>]*>2</dd>});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Now check your email');
        my $link = $mech->get_link_from_email; # Only one email sent, this also checks
        $mech->get_ok($link);
        $mech->content_contains('Your container request has been sent');
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        is $emails[0]->header('To'), '"Bromley Council" <request@example.org>';
        is $emails[1]->header('To'), $user->email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Your report to Bromley Council has been logged/;
        my @reports = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' }, rows => 2 });
        is $reports[0]->state, 'confirmed';
        is $reports[0]->get_extra_field_value('uprn'), 1000000002;
        is $reports[0]->get_extra_field_value('Quantity'), 2;
        is $reports[0]->get_extra_field_value('Container_Type'), 9;
        is $reports[1]->state, 'confirmed';
        is $reports[1]->get_extra_field_value('uprn'), 1000000002;
        is $reports[1]->get_extra_field_value('Quantity'), 1;
        is $reports[1]->get_extra_field_value('Container_Type'), 10;
    };
    subtest 'Thing already requested' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A new paper &amp; cardboard container request has been made');
    };
    subtest 'General enquiry, bad data' => sub {
        $mech->get_ok('/waste/12345/enquiry');
        is $mech->uri->path, '/waste/12345';
        $mech->get_ok('/waste/12345/enquiry?category=Bad');
        is $mech->uri->path, '/waste/12345';
        $mech->get_ok('/waste/12345/enquiry?service=1');
        is $mech->uri->path, '/waste/12345';
    };
    subtest 'Checking calendar' => sub {
        $mech->follow_link_ok({ text => 'Add to your calendar (.ics file)' });
        $mech->content_contains('BEGIN:VCALENDAR');
        my @events = split /BEGIN:VEVENT/, $mech->encoded_content;
        shift @events; # Header
        my $i = 0;
        foreach (@events) {
            $i++ if /DTSTART;VALUE=DATE:20200701/ && /SUMMARY:Non-Recyclable Refuse/;
            $i++ if /DTSTART;VALUE=DATE:20200708/ && /SUMMARY:Paper & Cardboard/;
        }
        is $i, 2, 'Two events from the sample data in the calendar';
    };
    subtest 'General enquiry, on behalf of someone else' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/enquiry?category=General+enquiry&service_id=537');
        $mech->submit_form_ok({ with_fields => { extra_Notes => 'Some notes' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email } });
        $mech->content_contains('Some notes');
        $mech->content_contains('Test McTest');
        $mech->content_contains($user->email);
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your enquiry has been submitted');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('Notes'), 'Some notes';
        is $report->detail, "Some notes\n\n2 Example Street, Bromley, BR1 1AA";
        is $report->user->email, $user->email;
        is $report->get_extra_metadata('contributed_by'), $staff_user->id;
        is $report->get_extra_field_value('Source'), 9, 'Correct source'
    };
};

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bromley',
    COBRAND_FEATURES => { echo => { bromley => { url => 'http://example.org' } }, waste => { bromley => 1 }, payment_gateway => { bromley => { ggw_cost => 1000 } } },
}, sub {
    subtest 'Address lookup, mocking SOAP call' => sub {
        my $integ = Test::MockModule->new('SOAP::Lite');
        $integ->mock(call => sub {
            return SOAP::Result->new(result => {
                PointInfo => [
                    { Description => '1 Example Street', Id => '11345', SharedRef => { Value => { anyType => 1000000001 } } },
                    { Description => '2 Example Street', Id => '12345', SharedRef => { Value => { anyType => 1000000002 } } },
                ],
            });
        });

        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->content_contains('2 Example Street');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bromley',
    COBRAND_FEATURES => {
        echo => { bromley => { url => 'http://example.org', sample_data => 1 } },
        waste => { bromley => 1 },
        payment_gateway => { bromley => {
            cc_url => 'http://example.com',
            ggw_cost => 2000,
            pro_rata_minimum => 500,
            pro_rata_weekly => 25,
        } },
    },
}, sub {
    my ($p) = $mech->create_problems_for_body(1, $body->id, 'New Garden Subscription', {
        user_id => $user->id,
        category => 'Request new container',
    });
    $p->update_extra_field({ name => 'property_id', value => 12345});
    $p->update;

    my $sent_params;
    my $pay = Test::MockModule->new('Integrations::SCP');

    $pay->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        return {
            transactionState => 'COMPLETE',
            scpReference => '12345',
            invokeResult => {
                status => 'SUCCESS',
                redirectURL => 'http://example.org/faq'
            }
        };
    });
    $pay->mock(query => sub {
        return {
            transactionState => 'COMPLETE',
            paymentResult => {
                status => 'SUCCESS',
            }
        };
    });

    subtest 'check payment gateway' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 2 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                new_bins => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');
        # external redirects make Test::WWW::Mechanize unhappy so clone
        # the mech for the redirect
        my $mech2 = $mech->clone;
        $mech2->submit_form_ok({ with_fields => { tandc => 1 } });

        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

        my $url = $sent_params->{returnUrl};
        my ($report_id) = ( $url =~ m#/(\d+)$# );
        my $new_report = FixMyStreet::DB->resultset('Problem')->find( { id => $report_id } );

        is $new_report->category, 'New Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Request_Details_Action'), 1, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        is $sent_params->{amount}, 2000, 'correct amount used';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok('/waste/pay_complete/' . $new_report->id);
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

    };

    subtest 'check new sub credit card payment with no bins required' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 2 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 1,
                new_bins => 0,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');
        # external redirects make Test::WWW::Mechanize unhappy so clone
        # the mech for the redirect
        my $mech2 = $mech->clone;
        $mech2->submit_form_ok({ with_fields => { tandc => 1 } });

        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

        my $url = $sent_params->{returnUrl};
        my ($report_id) = ( $url =~ m#/(\d+)$# );
        my $new_report = FixMyStreet::DB->resultset('Problem')->find( { id => $report_id } );

        is $new_report->category, 'New Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Request_Details_Action'), '', 'no container request action';
        is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), '', 'no container request';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        is $sent_params->{amount}, 2000, 'correct amount used';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok('/waste/pay_complete/' . $new_report->id);
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

    };

    subtest 'check new sub direct debit payment' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 2 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                new_bins => 1,
                payment_method => 'direct_debit',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_like( qr/txtRegularAmount[^>]*"20.00"/, 'payment amount correct');

        my ($report_id) = ( $mech->content =~ m#reference\*\|\*([^"]*)# );
        my $new_report = FixMyStreet::DB->resultset('Problem')->find( { id => $report_id } );

        is $new_report->category, 'New Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $mech->get_ok("/waste/dd_complete?reference=$report_id");
        $mech->content_contains('Direct Debit set up');

        $new_report->discard_changes;
        is $new_report->state, 'unconfirmed', 'report still not confirmed';
    };
};

done_testing;
