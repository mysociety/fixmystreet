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
create_contact({ category => 'Amend Garden Subscription', email => 'garden_amend@example.com'},
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
        { code => 'pro_rata', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Renew Garden Subscription', email => 'garden_renew@example.com'},
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
create_contact({ category => 'Cancel Garden Subscription', email => 'garden_renew@example.com'},
        { code => 'Container_Request_Details_Quantity', required => 1, automated => 'hidden_field' },
        { code => 'Container_Request_Details_Action', required => 1, automated => 'hidden_field' },
        { code => 'Container_Request_Details_Container_Type', required => 1, automated => 'hidden_field' },
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

    my $dd_sent_params = {};
    my $dd = Test::MockModule->new('Integrations::Pay360');
    $dd->mock('one_off_payment', sub {
        my $self = shift;
        $dd_sent_params->{'one_off_payment'} = shift;
    });

    $dd->mock('amend_plan', sub {
        my $self = shift;
        $dd_sent_params->{'amend_plan'} = shift;
    });

    $dd->mock('cancel_plan', sub {
        my $self = shift;
        $dd_sent_params->{'cancel_plan'} = shift;
    });

    subtest 'check new sub bin limits' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 2 });
        $mech->submit_form_ok({ with_fields => { existing => 'yes' } });
        $mech->content_contains('Please specify how many bins you already have');
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 0 } });
        $mech->content_contains('Please specify how many bins you already have');
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 4 } });
        $mech->content_contains('Existing bin count must be between 1 and 3');
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        my $form = $mech->form_with_fields( qw(current_bins new_bins payment_method) );
        ok $form, "form found";
        is $mech->value('current_bins'), 0, "current bins is set to 0";
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                new_bins => 0,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('The total number of bins must be at least 1');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 2,
                new_bins => 2,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('The total number of bins cannot exceed 3');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 4,
                new_bins => 0,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Value must be between 0 and 3');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                new_bins => 4,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Value must be between 0 and 3');

        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 2 });
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 2 } });
        $form = $mech->form_with_fields( qw(current_bins new_bins payment_method) );
        ok $form, "form found";
        is $mech->value('current_bins'), 2, "current bins is set to 2";
    };

    subtest 'check new sub credit card payment' => sub {
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

        my ( $report_id, $new_report ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'New Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Request_Details_Action'), 1, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        is $sent_params->{amount}, 2000, 'correct amount used';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok('/waste/pay_complete/' . $report_id);
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

        my ( $report_id, $new_report ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'New Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Request_Details_Action'), '', 'no container request action';
        is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), '', 'no container request';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        is $sent_params->{amount}, 2000, 'correct amount used';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok('/waste/pay_complete/' . $report_id);
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

    subtest 'check modify sub credit card payment' => sub {
        $mech->log_out_ok();
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/auth', 'have to be logged in to modify subscription';
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { bin_number => 2 } });
        $mech->content_contains('40.00');
        $mech->content_contains('5.50');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{amount}, 550, 'correct amount used';

        my ( $report_id, $new_report ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Amend Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 2, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Request_Details_Action'), 1, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), 1, 'correct container request count';

        $mech->get_ok('/waste/pay_complete/' . $report_id);
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
    };

    subtest 'check modify sub credit card payment reducing bin count' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $sent_params = undef;
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', sub {
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
                    } ] },
                } },
            } ];
        });

        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { bin_number => 1 } });
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Amend Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Request_Details_Action'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), 1, 'correct container request count';

        is $sent_params, undef, "no one off payment if reducing bin count";
    };

    $p->category('New Garden Subscription');
    $p->update_extra_field({ name => 'payment_method', value => 'direct_debit' });
    $p->update;

    subtest 'check modify sub direct debit payment' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { bin_number => 4 } });
        $mech->content_contains('Value must be between 1 and 3');
        $mech->submit_form_ok({ with_fields => { bin_number => 2 } });
        $mech->content_contains('40.00');
        $mech->content_contains('5.50');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Amend Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        is_deeply $dd_sent_params->{one_off_payment}, {
            payer_reference => 1,
            amount => '5.50',
            reference => $new_report->id,
            comments => '',
        }, "correct direct debit ad hoc payment params sent";
        is_deeply $dd_sent_params->{amend_plan}, {
            payer_reference => 1,
            amount => '40.00',
        }, "correct direct debit amendment params sent";
    };

    $dd_sent_params = {};
    subtest 'check modify sub direct debit payment reducing bin count' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', sub {
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
                    } ] },
                } },
            } ];
        });

        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { bin_number => 1 } });
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Amend Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        is $dd_sent_params->{one_off_payment}, undef, "no one off payment if reducing bin count";
        is_deeply $dd_sent_params->{amend_plan}, {
            payer_reference => 1,
            amount => '20.00',
        }, "correct direct debit amendment params sent";
    };

    subtest 'renew credit direct debit sub' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_renew');

        $mech->content_contains('This property has a direct debit subscription which will renew automatically.',
            "error message displayed if try to renew by direct debit");
    };

    subtest 'cancel direct debit sub' => sub {
        $mech->log_out_ok();
        $mech->get_ok('/waste/12345/garden_cancel');
        is $mech->uri->path, '/auth', 'have to be logged in to cancel subscription';
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->state, 'unconfirmed', 'report confirmed';

        is_deeply $dd_sent_params->{cancel_plan}, {
            payer_reference => 1,
        }, "correct direct debit cancellation params sent";
    };

    $p->update_extra_field({ name => 'payment_method', value => 'credit_card' });
    $p->update;

    subtest 'renew credit card sub' => sub {
        $mech->log_out_ok();
        $mech->get_ok('/waste/12345/garden_renew');
        is $mech->uri->path, '/auth', 'have to be logged in to renew subscription';
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            new_bins => 0,
            payment_method => 'credit_card',
        } });
        $mech->content_contains('Value must be between 1 and 3');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            new_bins => 0,
            payment_method => 'credit_card',
        } });
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{amount}, 2000, 'correct amount used';

        my ( $report_id, $new_report ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Renew Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Request_Details_Action'), '', 'no container request action';
        is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), '', 'no container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok('/waste/pay_complete/' . $report_id);
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
    };

    subtest 'renew credit card sub with an extra bin' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            new_bins => 3,
            payment_method => 'credit_card',
        } });
        $mech->content_contains('The total number of bins cannot exceed 3');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            new_bins => 1,
            payment_method => 'credit_card',
        } });
        $mech->content_contains('40.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{amount}, 4000, 'correct amount used';

        my ( $report_id, $new_report ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Renew Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 2, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Request_Details_Action'), 1, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok('/waste/pay_complete/' . $report_id);
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
    };

    subtest 'renew credit card sub with one less bin' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', sub {
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
                    } ] },
                } },
            } ];
        });
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        my $form = $mech->form_with_fields( qw( current_bins new_bins payment_method ) );
        ok $form, 'found form';
        is $mech->value('current_bins'), 2, "correct current bin count";
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            new_bins => 0,
            payment_method => 'credit_card',
        } });
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{amount}, 2000, 'correct amount used';

        my ( $report_id, $new_report ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Renew Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Request_Details_Action'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok('/waste/pay_complete/' . $report_id);
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
    };

    subtest 'renew credit card sub after end of sub' => sub {
        set_fixed_time('2021-04-01T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Garden Waste', "no mention of Garden Waste");
        $mech->content_lacks('/waste/12345/garden_renew', "no Garden Waste renewal link");

        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            new_bins => 0,
            payment_method => 'credit_card',
        } });
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{amount}, 2000, 'correct amount used';

        my ( $report_id, $new_report ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'New Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Request_Details_Action'), '', 'no container request action';
        is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), '', 'no container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok('/waste/pay_complete/' . $report_id);
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
    };

    subtest 'cancel credit card sub' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('Container_Request_Details_Action'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'confirmed', 'report confirmed';
    };

    for my $test ( 
        {
            return => {
                transactionState => 'INVALID_REFERENCE',
            },
            title => "lookup failed"
        },
        {
            return => {
                transactionState => 'COMPLETE',
                paymentResult => {
                    status => 'ERROR',
                }
            },
            title => "failed",
        }
    ) {
        subtest 'check new sub credit card payment ' . $test->{title} => sub {
            $pay->mock(query => sub {
                my $self = shift;
                $sent_params = shift;
                return $test->{return};
                #{
                    #transactionState => 'INVALID_REFERENCE',
                #};
            });

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

            my ( $report_id, $new_report ) = get_report_from_redirect( $sent_params->{returnUrl} );

            is $new_report->category, 'New Garden Subscription', 'correct category on report';
            is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
            is $new_report->get_extra_field_value('Container_Request_Details_Action'), 1, 'correct container request action';
            is $new_report->get_extra_field_value('Container_Request_Details_Quantity'), 1, 'correct container request count';
            is $new_report->state, 'unconfirmed', 'report not confirmed';

            is $sent_params->{amount}, 2000, 'correct amount used';

            $new_report->discard_changes;
            is $new_report->get_extra_metadata('scpReference'), '12345', 'scp reference on report';

            $mech->get_ok('/waste/pay_complete/' . $report_id);
            is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

            $new_report->discard_changes;
            is $new_report->state, 'unconfirmed', 'report unconfirmed';
            is $new_report->get_extra_metadata('payment_reference'), undef, 'no payment reference on report';

        };
    }

    subtest 'check new sub credit card redirect lookup failed' => sub {
        $pay->mock(pay => sub {
            my $self = shift;
            $sent_params = shift;
            return {
                transactionState => 'COMPLETE',
                invokeResult => {
                    status => 'ERROR',
                }
            };
        });

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

        is $mech2->uri->path, '/waste/12345/garden', 'no redirect occured';
        $mech2->content_contains('Unknown error');
    };
};

sub get_report_from_redirect {
    my $url = shift;

    my ($report_id) = ( $url =~ m#/([^/]+)$# );
    my $new_report = FixMyStreet::DB->resultset('Problem')->search( {
            extra => { like => '%scp_redirect_id,T32:'. $report_id . '%' }
    } )->first;

    return ($report_id, $new_report);
}

done_testing;
