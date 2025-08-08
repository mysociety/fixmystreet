use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2482, 'Bromley Council', { cobrand => 'bromley' }, {
    wasteworks_config => { request_timeframe => "two weeks" }
});
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');
$user->update({ phone => "07123 456789" });
my $nameless_user = $mech->create_user_ok('nameless@example.net', name => '');
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $body, name => 'Staff User');
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_anonymous_user' });
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_another_user' });
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'report_mark_private' });
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'can_pay_with_csc' });
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'report_edit' });

my $staff_non_payuser = $mech->create_user_ok('staff_no_pay@example.org', from_body => $body, name => 'Staff No Pay User');
$staff_non_payuser->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_anonymous_user' });
$staff_non_payuser->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_another_user' });
$staff_non_payuser->user_body_permissions->create({ body => $body, permission_type => 'report_mark_private' });

my $csc_user = $mech->create_user_ok('csc_staff@example.org', from_body => $body, name => 'CSC User');
my $role = FixMyStreet::DB->resultset("Role")->create({
    body => $body,
    name => 'Contact Centre Agent',
    permissions => ['contribute_as_another_user', 'contribute_as_anonymous_user', 'report_mark_private', 'can_pay_with_csc']
});
$csc_user->add_to_roles($role);


sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => ['Waste'], extra => { type => 'waste' });
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
create_contact({ category => 'Assisted collection add', email => 'assisted' },
    { code => 'Exact_Location', description => 'Exact location', required => 1, datatype => 'text' },
    { code => 'Reason', description => 'Reason for request', required => 1, datatype => 'text' },
    { code => 'staff_form', automated => 'hidden_field' },
    { code => 'Source', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'Garden Subscription', email => 'garden@example.com'},
        { code => 'Subscription_Type', required => 1, automated => 'hidden_field' },
        { code => 'Subscription_Details_Quantity', required => 1, automated => 'hidden_field' },
        { code => 'Subscription_Details_Container_Type', required => 1, automated => 'hidden_field' },
        { code => 'Container_Instruction_Quantity', required => 1, automated => 'hidden_field' },
        { code => 'Container_Instruction_Action', required => 1, automated => 'hidden_field' },
        { code => 'Container_Instruction_Container_Type', required => 1, automated => 'hidden_field' },
        { code => 'LastPayMethod', required => 0, automated => 'hidden_field' },
        { code => 'PaymentCode', required => 0, automated => 'hidden_field' },
        { code => 'current_containers', required => 1, automated => 'hidden_field' },
        { code => 'new_containers', required => 1, automated => 'hidden_field' },
        { code => 'payment_method', required => 1, automated => 'hidden_field' },
        { code => 'pro_rata', required => 0, automated => 'hidden_field' },
        { code => 'payment', required => 1, automated => 'hidden_field' },
        { code => 'Source', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'Cancel Garden Subscription', email => 'garden_renew@example.com'},
        { code => 'Subscription_End_Date', required => 1, automated => 'hidden_field' },
        { code => 'Container_Instruction_Quantity', required => 1, automated => 'hidden_field' },
        { code => 'Container_Instruction_Action', required => 1, automated => 'hidden_field' },
        { code => 'Container_Instruction_Container_Type', required => 1, automated => 'hidden_field' },
        { code => 'payment_method', required => 1, automated => 'hidden_field' },
        { code => 'Source', required => 0, automated => 'hidden_field' },
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
        $mech->content_contains('find your address in our records');
    };
    subtest 'Postcode with extra bits' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA.' } });
        $mech->content_contains('Select an address');
    };
    subtest 'Address lookup' => sub {
        set_fixed_time('2020-05-28T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => '12345' } });
        $mech->content_contains('2 Example Street');
        $mech->content_contains('Food Waste');
        # $mech->content_contains('every other Monday');
    };
    subtest 'Thing already requested' => sub {
        $mech->content_contains('A food waste collection has been reported as missed');
        $mech->content_contains('A paper &amp; cardboard collection has been reported as missed'); # as part of service unit, not property
    };
    subtest 'Report a missed bin' => sub {
        my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Bromley');
        $cobrand->mock('send_questionnaires', sub { 1 }); # To test that questionnaires aren't sent, despite being enabled on the cobrand.
        $mech->content_contains('service-531', 'Can report, last collection was 27th');
        $mech->content_lacks('service-537', 'Cannot report, last collection was 27th but the service unit has a report');
        $mech->content_lacks('service-535', 'Cannot report, last collection was 20th');
        $mech->content_lacks('service-542', 'Cannot report, last collection was 18th');
        $mech->follow_link_ok({ text => 'Report a missed collection' });
        $mech->content_contains('service-531', 'Checkbox, last collection was 27th');
        $mech->content_lacks('service-537', 'No checkbox, last collection was 27th but the service unit has a report');
        $mech->content_lacks('service-535', 'No checkbox, last collection was 20th');
        $mech->content_lacks('service-542', 'No checkbox, last collection was 18th');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->content_contains('Please specify what was missed');
        $mech->submit_form_ok({ with_fields => { 'service-531' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => "Test" } });
        $mech->content_contains('Please enter your full name');
        $mech->content_contains('Please provide an email address');
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", phone => '+441234567890' } });
        $mech->content_contains('Please provide an email address');
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => 'test@example.org' } });
        $mech->content_contains('Non-Recyclable Refuse');
        $mech->content_contains('Test McTest');
        $mech->content_contains('test@example.org');
        $mech->submit_form_ok({ form_number => 2 });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email } });
        $mech->content_contains($user->email);
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Now check your email');
        my $email = $mech->get_email;
        is $email->header('Subject'), 'Confirm your report on Bromley Recycling Services';
        my $link = $mech->get_link_from_email($email);

        # Peterborough uses first page of process (not report category) to display
        # correct confirmation message so test that it's been stored in token.
        my ($token_id) = $link =~ m{/P/(\S+)};
        my $token = FixMyStreet::DB->resultset('Token')->find(
            {
                token => $token_id,
                scope => 'problem'
            }
        );
        ok $token, 'Token found in database';
        is $token->data->{extra}->{first_page}, "report", 'token stored first_page correctly';

        $mech->clear_emails_ok;
        $mech->get_ok($link);
        $mech->content_contains('Thank you for reporting a missed collection');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        is $emails[0]->header('To'), '"Bromley Council" <missed@example.org>';
        is $emails[1]->header('To'), $user->email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Your report to Bromley Council has been logged/;

        is $user->alerts->count, 1;
        $mech->clear_emails_ok;

        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->send_questionnaire, 0;
    };
    subtest 'About You form is pre-filled when logged in' => sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => '12345' } });
        $mech->follow_link_ok({ text => 'Report a missed collection' });
        $mech->submit_form_ok({ with_fields => { 'service-531' => 1 } });
        $user->discard_changes;
        $mech->content_contains($user->name);
        $mech->content_contains($user->email);
        $mech->content_contains($user->phone);
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/report');
        $mech->submit_form_ok({ with_fields => { 'service-531' => 1 } });
        $mech->content_lacks($staff_user->name);
        $mech->content_lacks($staff_user->email);
        $mech->log_out_ok;
    };
    subtest 'Check report visibility' => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->first;
        $report->update({ geocode => {
            display_name => '12 A Street, XX1 1SZ',
        } });
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
        $mech->content_lacks('12 A Street, XX1 1SZ');

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
        $mech->submit_form_ok({ form_number => 1 });
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
        $mech->content_contains('Containers typically arrive within two weeks,');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->get_extra_field_value('Quantity'), 2;
        is $report->get_extra_field_value('Container_Type'), 1;
        is $report->get_extra_field_value('Action'), '';
        is $report->get_extra_field_value('Reason'), '';
    };
    subtest 'Request a replacement garden container' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/<input type="hidden" name="quantity-44" id="quantity-44" value="1">/);
        $mech->submit_form_ok({ form_number => 1 });
        $mech->content_contains('Please specify what you need');
        $mech->submit_form_ok({ with_fields => { 'container-44' => 1 } });
        $mech->submit_form_ok({ with_fields => { replacement_reason => 'damaged' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email } });
        $mech->content_contains('Garden Waste');
        $mech->content_contains('Test McTest');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your container request has been sent');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
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
        $mech->content_like(qr{Outside Food Waste Container</dt>\s*<dd[^>]*>\s*1 to deliver\s*</dd>});
        $mech->content_like(qr{Kitchen Caddy</dt>\s*<dd[^>]*>\s*2 to deliver\s*</dd>});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Now check your email');
        my $link = $mech->get_link_from_email; # Only one email sent, this also checks
        $mech->get_ok($link);
        $mech->content_contains('Your container request has been sent');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        is $emails[0]->header('To'), '"Bromley Council" <request@example.org>';
        is $emails[1]->header('To'), $user->email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Your request to Bromley Council has been logged/;
        my @reports = FixMyStreet::DB->resultset("Problem")->order_by('-id')->search(undef, { rows => 2 });
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
        $mech->follow_link_ok({ text => 'Add to your calendar' });
        $mech->follow_link_ok({ text_regex => qr/this link/ });
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
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->get_extra_field_value('Notes'), 'Some notes';
        is $report->detail, "Some notes\n\n2 Example Street, Bromley, BR1 1AA";
        is $report->user->email, $user->email;
        is $report->get_extra_metadata('contributed_by'), $staff_user->id;
        is $report->get_extra_field_value('Source'), 9, 'Correct source';

        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->content_contains('Created By:');
    };
    subtest "General enquiry, staff doesn't change name" => sub {
        my $original_name = $staff_user->name;
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/enquiry?category=General+enquiry&service_id=537');
        $mech->submit_form_ok({ with_fields => { extra_Notes => 'Some notes' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $staff_user->email } });
        $mech->content_contains('Some notes');
        $mech->content_contains('Test McTest');
        $mech->content_contains($staff_user->email);
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->get_extra_field_value('Notes'), 'Some notes';
        is $report->detail, "Some notes\n\n2 Example Street, Bromley, BR1 1AA";
        is $report->user->email, $staff_user->email;
        is $report->name, "Test McTest";
        is $report->get_extra_field_value('Source'), 9, 'Correct source';
        $staff_user->discard_changes;
        is $staff_user->name, $original_name, 'Staff user name stayed the same';
    };
    subtest 'test staff-only assisted collection form' => sub {
        $mech->get_ok('/waste/12345/enquiry?category=Assisted+collection+add&service_id=531');
        $mech->submit_form_ok({ with_fields => { extra_Exact_Location => 'Behind the garden gate', extra_Reason => 'Reason' } });
        $mech->submit_form_ok({ with_fields => { name => "Anne Assist", email => 'anne@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/12345"');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->get_extra_field_value('Reason'), 'Reason';
        is $report->detail, "Behind the garden gate\n\nReason\n\n2 Example Street, Bromley, BR1 1AA";
        is $report->user->email, 'anne@example.org';
        is $report->name, 'Anne Assist';
        is $report->get_extra_field_value('Source'), 9, 'Correct source';
    };
    subtest 'test staff-only form when logged out' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/12345/enquiry?category=Assisted+collection&service_id=531');
        is $mech->res->previous->code, 302;
    };
    subtest 'test assisted collection display' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Set up for assisted collection');
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', sub {
            return [ {
                Id => 1003,
                ServiceId => 531,
                ServiceName => 'Domestic Refuse Collection',
                ServiceTasks => { ServiceTask => {
                    Id => 403,
                    Data => { ExtensibleDatum => [ {
                        Value => 'LBB - Assisted Collection',
                        DatatypeName => 'Task Indicator',
                    }, {
                        Value => '01/01/2050',
                        DatatypeName => 'Indicator End Date',
                    } ] },
                    ServiceTaskSchedules => { ServiceTaskSchedule => {
                        StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                        EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                        NextInstance => {
                            CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                            OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                        },
                    } },
                } },
            } ];
        });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('This property is set up for assisted collections');
        $mech->follow_link_ok({ text => 'Update assisted collection' });
    };
    subtest 'Ignores expired services' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', sub {
            return [
                {
                    Id => 1003,
                    ServiceId => 535,
                    ServiceName => 'Domestic Container Mix Collection',
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
                }, {
                    Id => 1004,
                    ServiceId => 542,
                    ServiceName => 'Food waste collection',
                    ServiceTasks => { ServiceTask => {
                        Id => 404,
                        ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                            ScheduleDescription => 'every other Monday',
                            StartDate => { DateTime => '2019-01-01T00:00:00Z' },
                            EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                            LastInstance => {
                                OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                                CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                            },
                        }, {
                            ScheduleDescription => 'every other Monday',
                            StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                            EndDate => { DateTime => '2020-05-01T00:00:00Z' },
                            NextInstance => {
                                CurrentScheduledDate => { DateTime => '2020-05-02T00:00:00Z' },
                                OriginalScheduledDate => { DateTime => '2020-05-01T00:00:00Z' },
                            },
                            LastInstance => {
                                OriginalScheduledDate => { DateTime => '2020-04-20T00:00:00Z' },
                                CurrentScheduledDate => { DateTime => '2020-04-20T00:00:00Z' },
                                Ref => { Value => { anyType => [ 456, 789 ] } },
                            },
                        } ] },
                    } },
                }, {
                    Id => 1005,
                    ServiceId => 545,
                    ServiceName => 'Garden waste collection',
                    ServiceTasks => { ServiceTask => {
                        Id => 405,
                        Data => { ExtensibleDatum => [ {
                            DatatypeName => 'LBB - GW Container',
                            ChildData => { ExtensibleDatum => [ {
                                DatatypeName => 'Quantity',
                                Value => 1,
                            }, {
                                DatatypeName => 'Container',
                                Value => 44,
                            } ] },
                        } ] },
                        ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                            StartDate => { DateTime => '2019-01-01T00:00:00Z' },
                            EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                            LastInstance => {
                                OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                                CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                            },
                        }, {
                            ScheduleDescription => 'every other Monday',
                            StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                            EndDate => { DateTime => '2020-05-21T00:00:00Z' },
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
                }
            ];
        });
        set_fixed_time('2020-05-28T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => '12345' } });
        $mech->content_contains('2 Example Street');
        $mech->content_contains('Mixed Recycling');
        $mech->content_contains('Garden Waste');
        $mech->content_lacks('Food Waste');
    };

    subtest 'service task order is irrelevant' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', sub {
            return [
                {
                    Id => 1003,
                    ServiceId => 535,
                    ServiceName => 'Domestic Container Mix Collection',
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
                }, {
                    Id => 1004,
                    ServiceId => 542,
                    ServiceName => 'Food waste collection',
                    ServiceTasks => { ServiceTask => {
                        Id => 404,
                        ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                            ScheduleDescription => 'every other Monday',
                            StartDate => { DateTime => '2019-01-01T00:00:00Z' },
                            EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                            LastInstance => {
                                OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                                CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                            },
                        }, {
                            ScheduleDescription => 'every other Monday',
                            StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                            EndDate => { DateTime => '2020-05-01T00:00:00Z' },
                            NextInstance => {
                                CurrentScheduledDate => { DateTime => '2020-05-02T00:00:00Z' },
                                OriginalScheduledDate => { DateTime => '2020-05-01T00:00:00Z' },
                            },
                            LastInstance => {
                                OriginalScheduledDate => { DateTime => '2020-04-20T00:00:00Z' },
                                CurrentScheduledDate => { DateTime => '2020-04-20T00:00:00Z' },
                                Ref => { Value => { anyType => [ 456, 789 ] } },
                            },
                        } ] },
                    } },
                }, {
                    Id => 1005,
                    ServiceId => 545,
                    ServiceName => 'Garden waste collection',
                    ServiceTasks => { ServiceTask => {
                        Id => 405,
                        Data => { ExtensibleDatum => [ {
                            DatatypeName => 'LBB - GW Container',
                            ChildData => { ExtensibleDatum => [ {
                                DatatypeName => 'Quantity',
                                Value => 1,
                            }, {
                                DatatypeName => 'Container',
                                Value => 44,
                            } ] },
                        } ] },
                        ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                            ScheduleDescription => 'every other Monday',
                            StartDate => { DateTime => '2021-06-14T23:00:00Z' },
                            EndDate => { DateTime => '2021-07-14T23:00:00Z' },
                            NextInstance => {
                                CurrentScheduledDate => { DateTime => '2021-07-05T06:00:00Z' },
                                OriginalScheduledDate => { DateTime => '2021-07-04T23:00:00' },
                            },
                            LastInstance => {
                                OriginalScheduledDate => { DateTime => '2021-06-20T23:00:00Z' },
                                CurrentScheduledDate => { DateTime => '2021-06-21T06:00:00Z' },
                                Ref => { Value => { anyType => [ 567, 890 ] } },
                            }
                        }, {
                            StartDate => { DateTime => '2020-11-01T00:00:00Z' },
                            EndDate => { DateTime => '2021-06-15T22:59:59Z' },
                            LastInstance => {
                                OriginalScheduledDate => { DateTime => '2021-06-20T23:00:00Z' },
                                CurrentScheduledDate => { DateTime => '2021-06-21T06:00:00Z' },
                                Ref => { Value => { anyType => [ 567, 890 ] } },
                            },
                            NextInstance => {
                                CurrentScheduledDate => { DateTime => '2021-07-05T06:00:00Z' },
                                OriginalScheduledDate => { DateTime => '2021-07-04T23:00:00' },
                            },
                        } ] },
                    } },
                }
            ];
        });
        set_fixed_time('2021-06-29T12:00:00Z');
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => '12345' } });
        $mech->content_contains('2 Example Street');
        $mech->content_contains('Garden Waste');
        $mech->content_lacks('Your subscription is now overdue');
        $mech->content_contains('Your subscription is soon due for renewal');
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
                    { Description => '1 Example Street', Id => '11345', SharedRef => { Value => { anyType => '1000000001' } } },
                    { Description => '2 Example Street', Id => '12345', SharedRef => { Value => { anyType => '1000000002' } } },
                ],
            });
        });

        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->content_contains('2 Example Street');
    };
};

my $REFUSE_SERVICE = {
    Id => 1001,
    ServiceId => 531,
    ServiceName => 'Refuse collection',
    ServiceTasks => { ServiceTask => {
        Id => 401,
        ScheduleDescription => 'every Wednesday',
        ServiceTaskSchedules => { ServiceTaskSchedule => {
            StartDate => { DateTime => '2020-01-01T00:00:00Z' },
            EndDate => { DateTime => '2050-01-01T00:00:00Z' },
            NextInstance => {
                CurrentScheduledDate => { DateTime => '2021-03-10T00:00:00Z' },
                OriginalScheduledDate => { DateTime => '2021-03-10T00:00:00Z' },
            },
            LastInstance => {
                OriginalScheduledDate => { DateTime => '2021-03-08T00:00:00Z' },
                CurrentScheduledDate => { DateTime => '2021-03-08T00:00:00Z' },
                Ref => { Value => { anyType => [ 123, 456 ] } },
            },
        } },
    } },
};

sub garden_waste_no_bins {
    return [ $REFUSE_SERVICE, {
        Id => 1004,
        ServiceId => 542,
        ServiceName => 'Food waste collection',
        ServiceTasks => { ServiceTask => {
            Id => 404,
            ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                ScheduleDescription => 'every other Monday',
                StartDate => { DateTime => '2019-01-01T00:00:00Z' },
                EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                },
            }, {
                ScheduleDescription => 'every other Monday',
                StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-02T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    Ref => { Value => { anyType => [ 456, 789 ] } },
                },
            } ] },
        } },
    } ];
}

sub garden_waste_one_bin {
    return _garden_waste_service_units(1);
}

sub garden_waste_two_bins {
    return _garden_waste_service_units(2);
}

sub _garden_waste_service_units {
    my $bin_count = shift;

    return [ {
        Id => 1005,
        ServiceId => 545,
        ServiceName => 'Garden waste collection',
        ServiceTasks => { ServiceTask => {
            Id => 405,
            Data => { ExtensibleDatum => [ {
                DatatypeName => 'LBB - GW Container',
                ChildData => { ExtensibleDatum => [ {
                    DatatypeName => 'Quantity',
                    Value => $bin_count,
                }, {
                    DatatypeName => 'Container',
                    Value => 44,
                } ] },
            } ] },
            ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                StartDate => { DateTime => '2019-01-01T00:00:00Z' },
                EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                },
            }, {
                ScheduleDescription => 'every other Monday',
                StartDate => { DateTime => '2020-03-30T00:00:00Z' },
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
        } } } ];
}

my $dd_sent_params = {};
my $dd = Test::MockModule->new('Integrations::Pay360');
$dd->mock('one_off_payment', sub {
    my ($self, $params) = @_;
    delete $params->{orig_sub};
    $dd_sent_params->{'one_off_payment'} = $params;
});
$dd->mock('amend_plan', sub {
    my ($self, $params) = @_;
    delete $params->{orig_sub};
    $dd_sent_params->{'amend_plan'} = $params;
});
$dd->mock('cancel_plan', sub {
    my ($self, $params) = @_;
    delete $params->{report};
    $dd_sent_params->{'cancel_plan'} = $params;
});
$dd->mock('get_payer', sub { });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bromley',
    MAPIT_URL => 'http://mapit.uk/',
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
    my ($p) = $mech->create_problems_for_body(1, $body->id, 'Garden Subscription - New', {
        user_id => $user->id,
        category => 'Garden Subscription',
    });
    $p->title('Garden Subscription - New');
    $p->update_extra_field({ name => 'property_id', value => '12345'});
    $p->update;
    $user->update({ phone => "" });

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

    subtest 'check bin calendar with multiple service tasks' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $sent_params = undef;
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', sub {
            return [ {
                Id => 1005,
                ServiceId => 545,
                ServiceName => 'Garden waste collection',
                ServiceTasks => { ServiceTask => [ {
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
                        StartDate => { DateTime => '2019-01-01T00:00:00Z' },
                        EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                        LastInstance => {
                            OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                            CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                        },
                    }, {
                        StartDate => { DateTime => '2020-01-30T00:00:00Z' },
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
                },
                {
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
                        StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                        EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                        LastInstance => {
                            OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                            CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                        },
                    }, {
                        StartDate => { DateTime => '2020-03-30T00:00:00Z' },
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
                } ] },
            } ];
        });

        $mech->get_ok('/waste/12345');
        $mech->content_like(qr#Renewal</dt>\s*<dd[^>]*>30 March 2021#m);
        $mech->content_lacks('Subscribe to Green Garden Waste');
    };

    subtest 'check subscription link present' => sub {
        set_fixed_time('2021-03-09T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Subscribe to Green Garden Waste', 'Subscribe link not present for active sub');
        set_fixed_time('2021-04-05T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Subscribe to Green Garden Waste', 'Subscribe link not present if in renew window');
        set_fixed_time('2021-05-05T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Subscribe to Green Garden Waste', 'Subscribe link present if expired');

        # Just the 537 paper service (which has report + request),
        # to test whether garden waste sub still shown
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', sub {
            return [ $REFUSE_SERVICE, {
                Id => 1002,
                ServiceId => 537,
                ServiceName => 'Paper recycling collection',
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
            } ];
        } );
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Subscribe to Green Garden Waste', 'Subscribe link present even if all requested');

        set_fixed_time('2021-03-09T17:00:00Z');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_no_bins);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Subscribe to Green Garden Waste', 'Subscribe link present if never had a sub');
    };

    subtest 'check overdue, soon due messages and modify link' => sub {
        $mech->log_in_ok($user->email);
        set_fixed_time('2021-04-05T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Garden Waste');
        $mech->content_lacks('Change your garden waste subscription');
        $mech->content_contains('Your subscription is now overdue', "overdue link if after expired");
        set_fixed_time('2021-03-05T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Your subscription is soon due for renewal', "due soon link if within 7 weeks of expiry");
        $mech->content_lacks('Change your garden waste subscription');
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/waste/12345', 'link redirect to bin list if modify in renewal period';
        set_fixed_time('2021-02-10T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Your subscription is soon due for renewal', "due soon link if 7 weeks before expiry");
        set_fixed_time('2021-02-08T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Your subscription is soon due for renewal', "no renewal notice if over 7 weeks before expiry");
        $mech->content_contains('Change your garden waste subscription');
        $mech->log_out_ok;
    };

    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_no_bins);

    subtest 'check cannot cancel sub that does not exist' => sub {
        $mech->get_ok('/waste/12345/garden_cancel');
        is $mech->uri->path, '/waste/12345', 'cancel link redirect to bin list if no sub';
    };

    subtest 'check new sub bin limits' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'yes' } });
        $mech->content_contains('Please specify how many bins you already have');
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 0 } });
        $mech->content_contains('Existing bin count must be between 1 and 6');
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 7 } });
        $mech->content_contains('Existing bin count must be between 1 and 6');
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        my $form = $mech->form_with_fields( qw(current_bins bins_wanted payment_method) );
        ok $form, "form found";
        is $mech->value('current_bins'), 0, "current bins is set to 0";
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 0,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('The total number of bins must be at least 1');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 2,
                bins_wanted => 7,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('The total number of bins cannot exceed 6');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 7,
                bins_wanted => 0,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Value must be between 1 and 6');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 7,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Value must be between 1 and 6');

        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 2 } });
        $form = $mech->form_with_fields( qw(current_bins bins_wanted payment_method) );
        ok $form, "form found";
        $mech->content_like(qr#Total to pay now: £<span[^>]*>40.00#, "initial cost set correctly");
        is $mech->value('current_bins'), 2, "current bins is set to 2";
    };

    subtest 'check new sub credit card payment' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');
        $mech->content_contains('1 bin');
        $mech->submit_form_ok({ with_fields => { goto => 'details' } });
        $mech->content_contains('<span id="cost_pa">20.00');
        $mech->content_contains('<span id="cost_now">20.00');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        # external redirects make Test::WWW::Mechanize unhappy so clone the mech for the redirect
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - New', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), 44, 'correct container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), 1, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get('/waste/pay/xx/yyyyyyyyyyy');
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get("/waste/pay_complete/$report_id/NOTATOKEN");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
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

    subtest 'check new sub credit card payment with no bins required' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 1,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');

        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - New', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), '', 'no container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), '', 'no container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), '', 'no container request';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        is $new_report->get_extra_field_value('LastPayMethod'), 2, 'correct echo payment method field';
        is $new_report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
        $new_report->delete;
    };

    subtest 'check new sub credit card payment with one less bin required' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 2,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');

        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - New', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), '44', 'correct container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), '2', 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), '1', 'correct container request';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        is $new_report->get_extra_field_value('LastPayMethod'), 2, 'correct echo payment method field';
        is $new_report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
        $new_report->delete;
    };

    subtest 'check new sub direct debit payment' => sub {
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                payment_method => 'direct_debit',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_like( qr/txtRegularAmount[^>]*"20.00"/, 'payment amount correct');

        my ($token, $report_id) = ( $mech->content =~ m#reference\*\|\*([^*]*)\*\|\*report_id\*\|\*(\d+)"# );
        my $new_report = FixMyStreet::DB->resultset('Problem')->search( {
            id => $report_id,
            extra => { '@>' => '{"redirect_id":"' . $token . '"}' },
        } )->first;

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - New', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $mech->get_ok('/waste/12345');
        $mech->content_contains('You have a pending garden subscription');
        $mech->content_contains('Subscribe to Green Garden Waste'); # Nothing in DD system yet, might have given up and want to pay by CC instead

        $mech->get("/waste/dd_complete?reference=$token&report_id=xxy");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get("/waste/dd_complete?reference=NOTATOKEN&report_id=$report_id");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get_ok("/waste/dd_complete?reference=$token&report_id=$report_id");
        $mech->content_contains('confirmation details once your Direct Debit');

        $dd->mock('get_payer', sub { 'Creation Pending' });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('You have a pending garden subscription');
        $mech->content_lacks('Subscribe to Green Garden Waste'); # Now pending in DD system
        $dd->mock('get_payer', sub { });

        $mech->email_count_is( 1, "email sent for direct debit sub");
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/waste subscription/s, 'direct debit email confirmation looks correct';
        $new_report->discard_changes;
        is $new_report->state, 'unconfirmed', 'report still not confirmed';
        $new_report->delete;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'check modify sub with bad details' => sub {
        set_fixed_time('2021-01-09T17:00:00Z'); # After sample data collection
        $mech->log_out_ok();
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/auth', 'have to be logged in to modify subscription';
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 2, bins_wanted => 2 } });
        $mech->content_contains('2 bins');
        $mech->content_contains('40.00');
        $mech->content_contains('7.50');
    };
    subtest 'check modify sub credit card payment' => sub {
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->content_contains('2 bins');
        $mech->content_contains('40.00');
        $mech->content_contains('7.50');
        $mech->submit_form_ok({ with_fields => { goto => 'alter' } });
        $mech->content_contains('<span id="cost_per_year">40.00');
        $mech->content_contains('<span id="pro_rata_cost">7.50');
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        is $sent_params->{items}[0]{amount}, 750, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Amend', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 2, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), 44, 'correct container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), 1, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
        $new_report->delete;
    };

    $p->update_extra_field({ name => 'payment_method', value => 'csc' }); # Originally done by staff
    $p->update;

    subtest 'check modify sub credit card payment reducing bin count' => sub {
        set_fixed_time('2021-01-09T17:00:00Z'); # After sample data collection
        $sent_params = undef;
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_two_bins);

        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 2, bins_wanted => 1 } });
        $mech->content_contains('20.00');
        $mech->content_lacks('Continue to payment');
        $mech->content_contains('Confirm changes');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
        )->order_by('-id')->first;

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Amend', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), 44, 'correct container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $new_report->get_extra_field_value('payment'), '0', 'no payment if removing bins';
        is $new_report->get_extra_field_value('pro_rata'), '', 'no pro rata payment if removing bins';
        $new_report->delete;

        is $sent_params, undef, "no one off payment if reducing bin count";

        $mech->back;
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains('You have already submitted this form.');
    };

    $p->category('Garden Subscription');
    $p->title('Garden Subscription - New');
    $p->update_extra_field({ name => 'payment_method', value => 'direct_debit' });
    my $dd_ref = 'LBB-' . $p->id . '-1000000002';
    $p->set_extra_metadata('payerReference', $dd_ref);
    $p->update;

    subtest 'check modify sub direct debit payment' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        set_fixed_time('2021-01-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 7 } });
        $mech->content_contains('Value must be between 1 and 6');
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->content_contains('40.00');
        $mech->content_contains('7.50');
        $mech->content_contains('Amend Direct Debit');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
        )->order_by('-id')->first;

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Amend', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';
        is $new_report->get_extra_field_value('payment'), '4000', 'payment correctly set to future value';
        is $new_report->get_extra_field_value('pro_rata'), '750', 'pro rata payment correctly set';

        my $ad_hoc_payment_date = '2021-01-15T17:00:00';

        is_deeply $dd_sent_params->{one_off_payment}, {
            payer_reference => $dd_ref,
            amount => '7.50',
            reference => $new_report->id,
            comments => '',
            date => $ad_hoc_payment_date,
        }, "correct direct debit ad hoc payment params sent";
        is_deeply $dd_sent_params->{amend_plan}, {
            payer_reference => $dd_ref,
            amount => '40.00',
        }, "correct direct debit amendment params sent";
        $new_report->delete;
    };

    $dd_sent_params = {};
    subtest 'check modify sub direct debit payment reducing bin count' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins=> 2, bins_wanted => 1 } });
        $mech->content_like(qr#Total to pay today</dt>\s*<dd[^>]*>£0.00#);
        $mech->content_like(qr#Total</dt>\s*<dd[^>]*>£20.00#);
        $mech->content_contains('Amend Direct Debit');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
        )->order_by('-id')->first;

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Amend', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->get_extra_field_value('payment'), '2000', 'payment correctly set to future value';
        is $new_report->get_extra_field_value('pro_rata'), '', 'no pro rata payment if removing bins';
        is $new_report->state, 'unconfirmed', 'report not confirmed';
        $new_report->delete;

        is $dd_sent_params->{one_off_payment}, undef, "no one off payment if reducing bin count";
        is_deeply $dd_sent_params->{amend_plan}, {
            payer_reference => $dd_ref,
            amount => '20.00',
        }, "correct direct debit amendment params sent";
    };

    subtest 'renew direct debit sub' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $dd->mock('get_payer', sub { 'Active' });

        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Renew subscription today');
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->content_contains('This property has a direct debit subscription which will renew automatically.',
            "error message displayed if try to renew by direct debit");

        $mech->log_out_ok();
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Renew subscription today');
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->content_contains('This property has a direct debit subscription which will renew automatically.',
            "error message displayed if try to renew by direct debit");

        $p->state('hidden');
        $p->update;

        $mech->get_ok('/waste/12345');
        $mech->content_contains('Renew subscription today');
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->content_lacks('This property has a direct debit subscription which will renew automatically.',
            "error message displayed not displayed for hidden direct debit sub");

        $p->state('confirmed');
        $p->update;
        $dd->mock('get_payer', sub { });
    };

    subtest 'renew direct debit after expiry' => sub {
        set_fixed_time('2021-04-09T17:00:00Z'); # After expiry
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Renew subscription today');
        set_fixed_time('2021-03-09T17:00:00Z');
    };

    subtest 'cancel direct debit sub' => sub {
        $mech->get_ok('/waste/12345/garden_cancel');
        is $mech->uri->path, '/auth', 'have to be logged in to cancel subscription';
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
        )->order_by('-id')->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->state, 'unconfirmed', 'report confirmed';

        is_deeply $dd_sent_params->{cancel_plan}, {
            payer_reference => $dd_ref,
        }, "correct direct debit cancellation params sent";

        $mech->get_ok('/waste/12345');
        $mech->content_contains('Cancellation in progress');
    };

    $p->update_extra_field({ name => 'payment_method', value => 'credit_card' });
    $p->update;

    subtest 'renew credit card sub' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        $mech->log_out_ok();
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted => 0,
            payment_method => 'credit_card',
        } });
        $mech->content_contains('Value must be between 1 and 6');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('1 bin');
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { goto => 'intro' } });
        $mech->content_contains('<span id="cost_pa">20.00');
        $mech->content_contains('<span id="cost_now">20.00');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Renew', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), '', 'no container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), '', 'no container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), '', 'no container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        is $new_report->get_extra_field_value('LastPayMethod'), 2, 'correct echo payment method field';
        is $new_report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
    };

    subtest 'renew credit card sub with direct debit' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'direct_debit',
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        $mech->content_like( qr/txtRegularAmount[^>]*"20.00"/, 'payment amount correct');

        my ($token, $report_id) = ( $mech->content =~ m#reference\*\|\*([^*]*)\*\|\*report_id\*\|\*(\d+)"# );
        my $new_report = FixMyStreet::DB->resultset('Problem')->search( {
            id => $report_id,
            extra => { '@>' => '{"redirect_id":"' . $token . '"}' },
        } )->first;

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Renew', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Type'), 2, 'correct subscription type';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), '', 'no container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), '', 'no container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), '', 'no container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $mech->get_ok('/waste/12345');
        $mech->content_contains('You have a pending garden subscription');
        $mech->content_lacks('Subscribe to Green Garden Waste');

        $mech->get("/waste/dd_complete?reference=$token&report_id=xxy");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get("/waste/dd_complete?reference=NOTATOKEN&report_id=$report_id");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get_ok("/waste/dd_complete?reference=$token&report_id=$report_id");
        $mech->content_contains('confirmation details once your Direct Debit');

        $new_report->discard_changes;
        is $new_report->state, 'unconfirmed', 'report still not confirmed';

        # Delete report otherwise next test thinks we have a DD subscription (which we do now)
        $new_report->delete;
    };

    subtest 'renew credit card sub with an extra bin' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 7,
            payment_method => 'credit_card',
        } });
        $mech->content_contains('The total number of bins cannot exceed 6');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 2,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('40.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 4000, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Renew', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 2, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), 44, 'correct container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), 1, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        is $new_report->get_extra_field_value('LastPayMethod'), 2, 'correct echo payment method field';
        is $new_report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
    };

    subtest 'renew credit card sub with one less bin' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_two_bins);

        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_renew');
        my $form = $mech->form_with_fields( qw( current_bins payment_method ) );
        ok $form, 'found form';
        is $mech->value('current_bins'), 2, "correct current bin count";
        $mech->submit_form_ok({ with_fields => {
            current_bins => 2,
            bins_wanted => 1,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('20.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Renew', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), 44, 'correct container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        is $new_report->get_extra_field_value('LastPayMethod'), 2, 'correct echo payment method field';
        is $new_report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
    };

    remove_test_subs( $p->id );

    subtest 'renew credit card sub after end of sub' => sub {
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        set_fixed_time('2021-04-01T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345');
        $mech->content_contains('subscription is now overdue');
        $mech->content_contains('Renew your garden waste subscription', 'renew link still on expired subs');
        $mech->content_lacks('garden_cancel', 'cancel link not on expired subs');
        $mech->content_lacks('garden_modify', 'modify link not on expired subs');

        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('20.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - New', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), '', 'no container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), '', 'no container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), '', 'no container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        is $new_report->get_extra_field_value('LastPayMethod'), 2, 'correct last pay method';
        is $new_report->get_extra_field_value('PaymentCode'), '54321', 'correct payment code';
    };

    remove_test_subs( $p->id );

    subtest 'renew credit card sub after end of sub increasing bins' => sub {
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        set_fixed_time('2021-04-01T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345');
        $mech->content_contains('subscription is now overdue');
        $mech->content_contains('Renew your garden waste subscription', 'renew link still on expired subs');
        $mech->content_lacks('garden_cancel', 'cancel link not on expired subs');
        $mech->content_lacks('garden_modify', 'modify link not on expired subs');

        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 2,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('40.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        is $sent_params->{items}[0]{amount}, 4000, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - New', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 2, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), '44', 'correct container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), '1', 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), '1', 'correct container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';
    };

    subtest 'cancel credit card sub' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
        )->order_by('-id')->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('Subscription_End_Date'), '09/03/2021', 'cancel date set to current date';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'confirmed', 'report confirmed';
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_no_bins);

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
            $mech->submit_form_ok({ form_number => 1 });
            $mech->submit_form_ok({ with_fields => { existing => 'no' } });
            $mech->submit_form_ok({ with_fields => {
                    current_bins => 0,
                    bins_wanted => 1,
                    payment_method => 'credit_card',
                    name => 'Test McTest',
                    email => 'test@example.net'
            } });
            $mech->content_contains('Test McTest');
            $mech->content_contains('£20.00');

            $mech->waste_submit_check({ with_fields => { tandc => 1 } });

            my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

            is $new_report->category, 'Garden Subscription', 'correct category on report';
            is $new_report->title, 'Garden Subscription - New', 'correct title on report';
            is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
            is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
            is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), 44, 'correct container request bin type';
            is $new_report->get_extra_field_value('Container_Instruction_Action'), 1, 'correct container request action';
            is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
            is $new_report->state, 'unconfirmed', 'report not confirmed';

            is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';

            $new_report->discard_changes;
            is $new_report->get_extra_metadata('scpReference'), '12345', 'scp reference on report';

            $mech->get_ok("/waste/pay_complete/$report_id/$token");
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
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');

        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $mech->uri->path, '/waste/12345/garden', 'no redirect occured';
        $mech->content_contains('Payment failed: ERROR');

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

        $mech->waste_submit_check({ form_number => 1 });
    };

    my $report = FixMyStreet::DB->resultset("Problem")->search({
        category => 'Garden Subscription',
        title => 'Garden Subscription - New',
        extra => { '@>' => '{"_fields":[{"name":"property_id","value":"12345"}]}' },
    })->order_by('-id')->first;
    $report->update_extra_field({ name => 'payment_method', value => 'direct_debit' });
    $report->update;


    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'check staff cannot update direct debit subs' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->log_out_ok;
        $mech->log_in_ok($staff_user->email);

        $mech->get_ok('/waste/12345/garden_renew');
        $mech->content_contains('This property has a direct debit subscription which will renew');

        $mech->get_ok('/waste/12345/garden_modify');
        $mech->content_contains('can only be updated by the original user');

        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->content_contains('can only be updated by the original user');
    };

    $report->update_extra_field({ name => 'payment_method', value => 'credit_card' });
    $report->update;

    subtest 'check staff non pay no CSC access ' => sub {
        $mech->log_out_ok;
        $mech->log_in_ok($staff_non_payuser->email);
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->content_contains('Direct Debit', "payment method on page");
    };

    subtest 'check staff renewal' => sub {
        $mech->log_out_ok;
        $mech->log_in_ok($staff_user->email);
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->content_lacks('Direct Debit', "no payment method on page");
        $mech->submit_form_ok({ with_fields => {
            name => 'a user',
            email => 'a_user@example.net',
            current_bins => 1,
            bins_wanted => 1,
        }});

        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains('Enter paye.net code');
        $mech->submit_form_ok({ with_fields => {
            payenet_code => 54321
        }});
        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number is <strong>(\d+)<#);

        my $report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });
        is $report->title, 'Garden Subscription - Renew', 'correct title on report';
        is $report->get_extra_field_value('payment_method'), 'csc', 'correct payment method on report';
        is $report->get_extra_field_value('LastPayMethod'), 1, 'correct last pay method';
        is $report->get_extra_field_value('PaymentCode'), 54321, 'correct payment code';
        is $report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $report->get_extra_field_value('Container_Instruction_Action'), '', 'no container request action';
        is $report->get_extra_field_value('Container_Instruction_Quantity'), '', 'no container request count';
        is $report->state, 'confirmed', 'report confirmed';
        $report->delete; # Otherwise next test sees this as latest
    };

    subtest 'check staff renewal - no email' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->content_lacks('Direct Debit', "no payment method on page");
        $mech->submit_form_ok({ with_fields => {
            name => 'a user',
            email => '',
            current_bins => 1,
            bins_wanted => 1,
        }});

        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains('Enter paye.net code');
        $mech->submit_form_ok({ with_fields => {
            payenet_code => 54321
        }});
        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number is <strong>(\d+)<#);

        my $report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });
        is $report->title, 'Garden Subscription - Renew', 'correct title on report';
        is $report->get_extra_field_value('payment_method'), 'csc', 'correct payment method on report';
        is $report->get_extra_field_value('LastPayMethod'), 1, 'correct last pay method';
        is $report->get_extra_field_value('PaymentCode'), 54321, 'correct payment code';
        is $report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $report->get_extra_field_value('Container_Instruction_Action'), '', 'no container request action';
        is $report->get_extra_field_value('Container_Instruction_Quantity'), '', 'no container request count';
        is $report->state, 'confirmed', 'report confirmed';
        is $report->get_extra_metadata('contributed_by'), $staff_user->id;
        is $report->get_extra_metadata('contributed_as'), 'anonymous_user';
        $report->delete; # Otherwise next test sees this as latest
    };

    subtest 'check modify sub staff' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 2,
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('40.00');
        $mech->content_contains('7.50');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains('Enter paye.net code');
        $mech->submit_form_ok({ with_fields => {
            payenet_code => 64321
        }});
        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number is <strong>(\d+)<#);
        my $report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });

        is $report->category, 'Garden Subscription', 'correct category on report';
        is $report->title, 'Garden Subscription - Amend', 'correct title on report';
        is $report->get_extra_field_value('payment_method'), 'csc', 'correct payment method on report';
        is $report->state, 'confirmed', 'report confirmed';
        is $report->get_extra_field_value('Subscription_Details_Quantity'), 2, 'correct bin count';
        is $report->get_extra_field_value('Container_Instruction_Action'), 1, 'correct container request action';
        is $report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $report->get_extra_metadata('payment_reference'), '64321', 'correct payment reference on report';
        is $report->name, 'Test McTest', 'non staff user name';
        is $report->user->email, 'test@example.net', 'non staff email';

        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
        $report->delete; # Otherwise next test sees this as latest
    };

    subtest 'check modify sub staff reducing bin count' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_two_bins);

        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 2,
            bins_wanted => 1,
            name => 'A user',
            email => '',
        } });
        $mech->content_contains('20.00');
        $mech->content_lacks('Continue to payment');
        $mech->content_contains('Confirm changes');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->content_lacks($staff_user->email);
        $mech->content_lacks('sent to your email address');

        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number is <strong>(\d+)<#);
        my $new_report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Amend', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'csc', 'correct payment method on report';
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $new_report->get_extra_metadata('contributed_by'), $staff_user->id;
        is $new_report->get_extra_metadata('contributed_as'), 'anonymous_user';
        is $new_report->get_extra_field_value('payment'), '0', 'no payment if removing bins';
        is $new_report->get_extra_field_value('pro_rata'), '', 'no pro rata payment if removing bins';
    };

    subtest 'cancel staff sub' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        my $new_report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('Subscription_End_Date'), '09/03/2021', 'cancel date set to current date';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('contributed_by'), $staff_user->id;
        is $new_report->get_extra_metadata('contributed_as'), 'anonymous_user';
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_no_bins);

    subtest 'staff create new subscription' => sub {
        $mech->log_out_ok;
        $mech->log_in_ok($csc_user->email);
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
        $mech->content_lacks('name="password', 'no password field');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');
        $mech->content_contains('1 bin');
        # external redirects make Test::WWW::Mechanize unhappy so clone
        # the mech for the redirect
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains('Enter paye.net code');
        $mech->submit_form_ok({ with_fields => {
            payenet_code => 64321
        }});
        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number is <strong>(\d+)<#);
        my $report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });

        is $report->category, 'Garden Subscription', 'correct category on report';
        is $report->title, 'Garden Subscription - New', 'correct title on report';
        is $report->get_extra_field_value('payment_method'), 'csc', 'correct payment method on report';
        is $report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $report->get_extra_field_value('Container_Instruction_Container_Type'), 44, 'correct container request bin type';
        is $report->get_extra_field_value('Container_Instruction_Action'), 1, 'correct container request action';
        is $report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $report->state, 'confirmed', 'report confirmed';
        is $report->state, 'confirmed', 'report confirmed';
        is $report->get_extra_field_value('LastPayMethod'), 1, 'correct echo payment method field';
        is $report->get_extra_field_value('PaymentCode'), '64321', 'correct echo payment reference field';
        is $report->get_extra_field_value('Source'), '3', 'correct echo source for staff';
        is $report->get_extra_metadata('payment_reference'), '64321', 'correct payment reference on report';
        is $report->user->email, 'test@example.net';
        is $report->get_extra_metadata('contributed_by'), $csc_user->id;

    };

    subtest 'staff create new subscription - payment failed' => sub {
        $mech->log_out_ok;
        $mech->log_in_ok($staff_user->email);
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
        $mech->content_lacks('name="password', 'no password field');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');
        $mech->content_contains('1 bin');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains('Enter paye.net code');

        my $content = $mech->content;
        my ($id) = ($content =~ m#report_id"\s+value="(\d+)"#);
        my $report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });

        $mech->submit_form_ok({ with_fields => {
            payment_failed => 'Payment Failed'
        }});
        $mech->content_contains('A payment failed notification has been sent');
        $mech->content_contains('test@example.net');
        $mech->content_contains('No subscription will be created');
        $mech->email_count_is( 1, "email sent for failed CSC payment");
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/problem collecting payment/s, 'csc payment failure email content correct';

        $report->discard_changes;
        is $report->get_extra_field_value('payment_method'), 'csc', 'correct payment method on report';
        is $report->state, 'unconfirmed', 'report not confirmed';
        is $report->get_extra_field_value('payment_reference'), 'FAILED', 'payment reference marked as failed';
    };

    subtest 'staff create new subscription no email' => sub {
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                name => 'Test McTest',
                email => '',
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');
        $mech->content_contains('1 bin');
        # external redirects make Test::WWW::Mechanize unhappy so clone
        # the mech for the redirect
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains('Enter paye.net code');
        $mech->submit_form_ok({ with_fields => {
            payenet_code => 64321
        }});
        $mech->content_lacks($staff_user->email);
        $mech->content_lacks('sent to your email address');
        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number is <strong>(\d+)<#);
        my $report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });

        is $report->category, 'Garden Subscription', 'correct category on report';
        is $report->title, 'Garden Subscription - New', 'correct title on report';
        is $report->get_extra_field_value('payment_method'), 'csc', 'correct payment method on report';
        is $report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $report->get_extra_field_value('Container_Instruction_Container_Type'), 44, 'correct container request bin type';
        is $report->get_extra_field_value('Container_Instruction_Action'), 1, 'correct container request action';
        is $report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $report->state, 'confirmed', 'report confirmed';
        is $report->state, 'confirmed', 'report confirmed';
        is $report->get_extra_field_value('LastPayMethod'), 1, 'correct echo payment method field';
        is $report->get_extra_field_value('PaymentCode'), '64321', 'correct echo payment reference field';
        is $report->get_extra_metadata('payment_reference'), '64321', 'correct payment reference on report';
        is $report->get_extra_metadata('contributed_by'), $staff_user->id;
        is $report->get_extra_metadata('contributed_as'), 'anonymous_user';

        my $alerts = FixMyStreet::App->model('DB::Alert')->search( {
            alert_type => 'new_updates',
            parameter => $report->id,
        } );
        is $alerts->count, 0, "no alerts created";
    };

    subtest 'staff create new subscription no email - payment failed' => sub {
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                name => 'Test McTest',
                email => '',
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');
        $mech->content_contains('1 bin');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains('Enter paye.net code');
        $mech->submit_form_ok({ with_fields => {
            payment_failed => 'Payment Failed'
        }});
        $mech->content_lacks('A payment failed notification has been sent');
        $mech->content_contains('No subscription will be created');
        $mech->email_count_is( 0, "No email sent for failed CSC payment");
    };

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

    subtest 'renew credit card sub change name' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        $mech->log_out_ok();
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
            email => 'test@example.net',
            name => 'A New Name'
        } });
        $mech->content_contains('A New Name');
        $mech->content_contains('20.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Renew', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), '', 'no container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), '', 'no container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), '', 'no container request count';
        is $new_report->name, 'A New Name', 'changes name';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        is $new_report->get_extra_field_value('LastPayMethod'), 2, 'correct echo payment method field';
        is $new_report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
    };

    # remove all reports
    remove_test_subs( 0 );

    subtest 'renew credit card sub after end of sub with no existing sub' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', sub {
            return [ {
                Id => 1005,
                ServiceId => 545,
                ServiceName => 'Garden waste collection',
                ServiceTasks => { ServiceTask => {
                    Id => 405,
                    Data => { ExtensibleDatum => [ {
                        DatatypeName => 'LBB - GW Container',
                        ChildData => { ExtensibleDatum => {
                            DatatypeName => 'Quantity',
                            Value => 1,
                        } },
                    } ] },
                    ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                        StartDate => { DateTime => '2019-04-01T23:00:00Z' },
                        EndDate => { DateTime => '2020-05-14T23:00:00Z' },
                        LastInstance => undef,
                        NextInstance => undef,
                    }, {
                        StartDate => { DateTime => '2020-05-14T23:00:00Z' },
                        EndDate => { DateTime => '2020-10-31T00:00:00Z' },
                        LastInstance => undef,
                        NextInstance => undef,
                    }, {
                        StartDate => { DateTime => '2020-10-31T00:00:00Z' },
                        EndDate => { DateTime => '2020-11-01T00:00:00Z' },
                        LastInstance => undef,
                        NextInstance => undef,
                    }, {
                        StartDate => { DateTime => '2020-11-01T00:00:00Z' },
                        EndDate => { DateTime => '2021-05-19T22:59:59Z', OffsetMinutes => 60 },
                        LastInstance => undef,
                        NextInstance => undef,
                    } ] },
                } },
            } ]
        } );
        set_fixed_time('2021-05-20T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345');
        $mech->content_contains('subscription is now overdue');
        $mech->content_contains('Renew your garden waste subscription', 'renew link still on expired subs');
        $mech->content_lacks('garden_cancel', 'cancel link not on expired subs');
        $mech->content_lacks('garden_modify', 'modify link not on expired subs');

        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net',

        } });
        $mech->content_contains('20.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - New', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Type'), 1, 'correct subscription type';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), '', 'no container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), '', 'no container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        is $new_report->get_extra_field_value('LastPayMethod'), 2, 'correct echo last pay method';
        is $new_report->get_extra_field_value('PaymentCode'), 54321, 'correct echo payment code';
    };

    remove_test_subs( 0 );

    subtest 'renew credit card sub for user with no name' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', sub {
            return [ {
                Id => 1005,
                ServiceId => 545,
                ServiceName => 'Garden waste collection',
                ServiceTasks => { ServiceTask => {
                    Id => 405,
                    Data => { ExtensibleDatum => [ {
                        DatatypeName => 'LBB - GW Container',
                        ChildData => { ExtensibleDatum => {
                            DatatypeName => 'Quantity',
                            Value => 1,
                        } },
                    } ] },
                    ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                        StartDate => { DateTime => '2019-04-01T23:00:00Z' },
                        EndDate => { DateTime => '2020-05-14T23:00:00Z' },
                        LastInstance => undef,
                        NextInstance => undef,
                    }, {
                        StartDate => { DateTime => '2020-05-14T23:00:00Z' },
                        EndDate => { DateTime => '2020-10-31T00:00:00Z' },
                        LastInstance => undef,
                        NextInstance => undef,
                    }, {
                        StartDate => { DateTime => '2020-10-31T00:00:00Z' },
                        EndDate => { DateTime => '2020-11-01T00:00:00Z' },
                        LastInstance => undef,
                        NextInstance => undef,
                    }, {
                        StartDate => { DateTime => '2020-11-01T00:00:00Z' },
                        EndDate => { DateTime => '2021-05-19T22:59:59Z', OffsetMinutes => 60 },
                        LastInstance => undef,
                        NextInstance => undef,
                    } ] },
                } },
            } ]
        } );
        set_fixed_time('2021-05-20T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($nameless_user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
            name => 'A user',
            email => 'nameless@example.net',
        } });
        $mech->content_contains('20.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - New', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->get_extra_field_value('Subscription_Type'), 1, 'correct subscription type';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), '', 'no container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), '', 'no container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';
        is $new_report->name, 'A user', 'report has correct name';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        is $new_report->get_extra_field_value('LastPayMethod'), 2, 'correct echo last pay method';
        is $new_report->get_extra_field_value('PaymentCode'), 54321, 'correct echo payment code';

        # need to do this to get changes so update marks as dirty
        $nameless_user->discard_changes;
        $nameless_user->update({ name => '' });
    };

    # remove all reports
    remove_test_subs( 0 );

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'modify sub with no existing waste sub - credit card payment' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->log_out_ok();
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/auth', 'have to be logged in to modify subscription';
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->content_contains('40.00');
        $mech->content_contains('7.50');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        is $sent_params->{items}[0]{amount}, 750, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Amend', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 2, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), 44, 'correct container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), 1, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
    };

    remove_test_subs( 0 );

    subtest 'modify sub user with no name' => sub {
        $mech->log_out_ok();
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->log_in_ok($nameless_user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->content_contains('Your name is required');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 2,
            name => 'A Name',
        } });
        $mech->content_contains('A Name');
        $mech->content_contains('40.00');
        $mech->content_contains('7.50');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        is $sent_params->{items}[0]{amount}, 750, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Amend', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $new_report->discard_changes;
        is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 2, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Container_Type'), 44, 'correct bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Container_Type'), 44, 'correct container request bin type';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), 1, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $new_report->name, 'A Name', 'correct name on report';

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        $new_report->discard_changes;
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
    };

    remove_test_subs( 0 );

    subtest 'cancel credit card sub with no record in waste' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
        )->order_by('-id')->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('Subscription_End_Date'), '09/03/2021', 'cancel date set to current date';
        is $new_report->get_extra_field_value('Container_Instruction_Action'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Container_Instruction_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'confirmed', 'report confirmed';
    };

    remove_test_subs( 0 );

    subtest 'check staff renewal with no existing sub' => sub {
        $mech->log_out_ok;
        $mech->log_in_ok($staff_user->email);
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->content_lacks('Direct Debit', "no payment method on page");
        $mech->submit_form_ok({ with_fields => {
            name => 'a user',
            email => 'a_user@example.net',
            current_bins => 1,
            bins_wanted => 1,
        }});

        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains('Enter paye.net code');
        $mech->submit_form_ok({ with_fields => {
            payenet_code => 54321
        }});
        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number is <strong>(\d+)<#);

        my $report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });
        is $report->title, 'Garden Subscription - Renew', 'correct title on report';
        is $report->get_extra_field_value('payment_method'), 'csc', 'correct payment method on report';
        is $report->get_extra_field_value('LastPayMethod'), 1, 'correct last pay method';
        is $report->get_extra_field_value('PaymentCode'), 54321, 'correct payment code';
        is $report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $report->get_extra_field_value('Container_Instruction_Action'), '', 'no container request action';
        is $report->get_extra_field_value('Container_Instruction_Quantity'), '', 'no container request count';
        is $report->state, 'confirmed', 'report confirmed';
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bromley',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { bromley => { url => 'http://example.org', sample_data => 1 } },
        waste => { bromley => 1 },
        waste_features => { bromley => { garden_waste_staff_only => 1 } },
        payment_gateway => { bromley => { cc_url => 'http://example.com', ggw_cost => 2000, pro_rata_minimum => 500, pro_rata_weekly => 25, } },
    },
}, sub {
    set_fixed_time('2021-01-09T17:00:00Z'); # After sample data collection
    $mech->log_in_ok($staff_user->email);
    $mech->get_ok('/waste/12345');
    $mech->content_contains('Change your garden waste subscription');
    $mech->log_out_ok;
    $mech->get_ok('/waste/12345');
    $mech->content_lacks('Change your garden waste subscription');
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bromley',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { bromley => { url => 'http://example.org', sample_data => 1 } },
        waste => { bromley => 1 },
        waste_features => { bromley => { garden_disabled => 1 } },
        payment_gateway => { bromley => { cc_url => 'http://example.com', ggw_cost => 2000, pro_rata_minimum => 500, pro_rata_weekly => 25, } },
    },
}, sub {
    $mech->log_in_ok($staff_user->email);
    $mech->get_ok('/waste/12345');
    $mech->content_lacks('Change your garden waste subscription');
    $mech->log_out_ok;
    $mech->get_ok('/waste/12345');
    $mech->content_lacks('Change your garden waste subscription');
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

sub remove_test_subs {
    my $base_id = shift;

    FixMyStreet::DB->resultset('Problem')->search({
                id => { '<>' => $base_id },
                category => [ 'Garden Subscription', 'Cancel Garden Subscription' ],
    })->delete;
}

done_testing;
