use Test::MockModule;
use FixMyStreet::TestMech;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2482, 'Bromley Council');
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $body, name => 'Staff User');
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_another_user' });
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'report_mark_private' });

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params);
    $contact->set_extra_metadata(group => ['Waste']);
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Report missed collection', email => 'missed' });
create_contact({ category => 'Request new container', email => 'request' },
    { code => 'Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'General enquiry', email => 'general' },
    { code => 'Notes', description => 'Notes', required => 1, datatype => 'text' });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['bromley', 'fixmystreet'],
    COBRAND_FEATURES => { echo => { bromley => { sample_data => 1 } }, waste => { bromley => 1 } },
}, sub {
    $mech->host('bromley.fixmystreet.com');
    subtest 'Missing address lookup' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => 'missing' } });
        $mech->content_contains('can’t find your address');
    };
    subtest 'Address lookup' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => '1000000002' } });
        $mech->content_contains('2 Example Street');
        $mech->content_contains('Food Waste');
    };
    subtest 'Report a missed bin' => sub {
        $mech->follow_link_ok({ text => 'Report a missed collection' });
        $mech->submit_form_ok({ form_number => 2 });
        $mech->content_contains('Please specify what was missed');
        $mech->submit_form_ok({ with_fields => { 'service-101' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => "Test" } });
        $mech->content_contains('Please enter your full name');
        $mech->content_contains('Please specify at least one of phone or email');
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => 'test@example.org' } });
        $mech->content_contains('Refuse collection');
        $mech->content_contains('Test McTest');
        $mech->content_contains('test@example.org');
        $mech->submit_form_ok({ form_number => 3 });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email } });
        $mech->content_contains($user->email);
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your report has been sent');

        is $user->alerts->count, 1;
    };
    subtest 'Check report visibility' => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->first;
        my $res = $mech->get('/report/' . $report->id);
        is $res->code, 403;
        $mech->log_in_ok($user->email);
        $mech->get_ok('/report/' . $report->id);
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/report/' . $report->id);

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
        $mech->get_ok('/waste/uprn/1000000002/request');
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
        $mech->content_contains('Your request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->get_extra_field_value('Quantity'), 2;
        is $report->get_extra_field_value('Container_Type'), 1;
    };
    subtest 'General enquiry, bad data' => sub {
        $mech->get_ok('/waste/uprn/1000000002/enquiry');
        is $mech->uri->path, '/waste/uprn/1000000002';
        $mech->get_ok('/waste/uprn/1000000002/enquiry?category=Bad');
        is $mech->uri->path, '/waste/uprn/1000000002';
        $mech->get_ok('/waste/uprn/1000000002/enquiry?service=1');
        is $mech->uri->path, '/waste/uprn/1000000002';
    };
    subtest 'Checking calendar' => sub {
        $mech->follow_link_ok({ text => 'Add to your calendar (.ics file)' });
        $mech->content_contains('BEGIN:VCALENDAR');
        my @events = split /BEGIN:VEVENT/, $mech->encoded_content;
        shift @events; # Header
        my $i = 0;
        foreach (@events) {
            $i++ if /DTSTART;VALUE=DATE:20200701/ && /SUMMARY:Refuse collection/;
            $i++ if /DTSTART;VALUE=DATE:20200708/ && /SUMMARY:Paper & Cardboard/;
        }
        is $i, 2, 'Two events from the sample data in the calendar';
    };
    subtest 'General enquiry, on behalf of someone else' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/uprn/1000000002/enquiry?category=General+enquiry&service_id=537');
        $mech->submit_form_ok({ with_fields => { extra_Notes => 'Some notes' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email } });
        $mech->content_contains('Some notes');
        $mech->content_contains('Test McTest');
        $mech->content_contains($user->email);
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your enquiry has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('Notes'), 'Some notes';
        is $report->user->email, $user->email;
        is $report->get_extra_metadata('contributed_by'), $staff_user->id;
    };
};

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bromley',
    COBRAND_FEATURES => { echo => { bromley => { url => 'http://example.org' } }, waste => { bromley => 1 } },
}, sub {
    subtest 'Address lookup, mocking SOAP call' => sub {
        my $integ = Test::MockModule->new('SOAP::Lite');
        $integ->mock(call => sub {
            return SOAP::Result->new(result => {
                PointInfo => [
                    { Description => '1 Example Street', SharedRef => { Value => { anyType => 1000000001 } } },
                    { Description => '2 Example Street', SharedRef => { Value => { anyType => 1000000002 } } },
                ],
            });
        });

        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->content_contains('2 Example Street');
    };
};

done_testing;
