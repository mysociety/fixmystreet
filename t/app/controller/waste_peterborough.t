use utf8;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use CGI::Simple;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Peterborough');
$mock->mock('_fetch_features', sub { [] });

my $mech = FixMyStreet::TestMech->new;

my $params = {
    send_method => 'Open311',
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
};
my $body = $mech->create_body_ok(2566, 'Peterborough City Council', $params, { cobrand => 'peterborough' });
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');
my $user2 = $mech->create_user_ok('test2@example.net', name => 'Very Normal User');
my $staff = $mech->create_user_ok('staff@example.net', name => 'Staff User', from_body => $body->id);
$staff->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_another_user' });
$staff->user_body_permissions->create({ body => $body, permission_type => 'report_mark_private' });
my $super = $mech->create_user_ok('super@example.net', name => 'Super User', is_superuser => 1);

my $bromley = $mech->create_body_ok(2482, 'Bromley Council', {}, { cobrand => 'bromley' });

sub create_contact {
    my ($params, $group, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => [$group]);
    $contact->set_extra_metadata( type => 'waste' );
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Food', email => 'Bartec-252' }, 'Missed Collection');
create_contact({ category => 'Recycling (green)', email => 'Bartec-254' }, 'Missed Collection');
create_contact({ category => 'Refuse', email => 'Bartec-255' }, 'Missed Collection');
create_contact({ category => 'Assisted', email => 'Bartec-492' }, 'Missed Collection');
create_contact({ category => 'Green 240L bin', email => 'Bartec-420' }, 'Request new container');
create_contact({ category => 'All bins', email => 'Bartec-425' }, 'Request new container');
create_contact({ category => 'Both food bins', email => 'Bartec-493' }, 'Request new container');
create_contact({ category => 'Food bag request', email => 'Bartec-428' }, 'Request new container');
create_contact({ category => '240L Black - Lid', email => 'Bartec-538' }, 'Bin repairs');
create_contact({ category => '240L Black - Wheels', email => 'Bartec-541' }, 'Bin repairs');
create_contact({ category => '240L Green - Wheels', email => 'Bartec-540' }, 'Bin repairs');
create_contact({ category => 'Not returned to collection point', email => 'Bartec-497' }, 'Not returned to collection point');
create_contact({ category => 'Black 360L bin', email => 'Bartec-422' }, 'Request new container');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'peterborough',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => { bartec => { peterborough => {
        url => 'http://example.org/',
        auth_url => 'http://auth.example.org/',
        sample_data => 1 } },
        waste => { peterborough => 1 },
    },
    STAGING_FLAGS => {
        send_reports => 1,
    },
}, sub {
    my ($b, $jobs_fsd_get) = shared_bartec_mocks();
    subtest 'Missing address lookup' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'PE1 3NA' } });
        $mech->submit_form_ok({ with_fields => { address => 'missing' } });
        $mech->content_contains('find your address in our records', "Missing message found");
    };
    subtest 'Address lookup' => sub {
        set_fixed_time('2021-08-05T21:00:00Z');
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'PE1 3NA' } });
        $mech->content_contains('1 Pope Way, Peterborough, PE1 3NA');
        $mech->submit_form_ok({ with_fields => { address => 'PE1 3NA:100090215480' } });
        $mech->content_contains('1 Pope Way, Peterborough');
        $mech->content_contains('Every two weeks');
        $mech->content_contains('Thursday, 5th August 2021');
        $mech->content_contains('Report a recycling bin collection as missed');
        set_fixed_time('2021-08-06T14:00:00Z');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('Report a recycling bin collection as missed');
        set_fixed_time('2021-08-06T18:00:00Z');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks('Report a recycling bin collection as missed');
    };
    subtest 'Check lock out conditions' => sub {
        set_fixed_time('2021-08-05T14:00:00Z');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('to report a missed recycling bin please call');
        $mech->content_lacks('Report a missed collection');

        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('Please call through to Aragon');
        $mech->log_out_ok();

        set_fixed_time('2021-08-06T10:00:00Z');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks('to report a missed recycling bin please call');

        $b->mock('Premises_Events_Get', sub { [
            { Features => { FeatureType => { ID => 6534 } }, EventType => { Description => 'BIN NOT OUT' }, EventDate => '2021-08-05T10:10:10' },
            { Features => { FeatureType => { ID => 6534 } }, EventType => { Description => 'NO ACCESS' }, EventDate => '2021-08-05T10:10:15' },
        ] });
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('There was a problem with your bin collection, please call');
        $mech->content_lacks('BIN NOT OUT');
        $mech->content_lacks('NO ACCESS');

        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('BIN NOT OUT, NO ACCESS');
        $mech->log_out_ok();

        $b->mock('Premises_Events_Get', sub { [
            { Features => { FeatureType => { ID => 9999 } }, EventType => { Description => 'BIN NOT OUT' }, EventDate => '2021-08-05T10:10:10' },
        ] });
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks('There was a problem with your bin collection, please call');

        $b->mock('Premises_Events_Get', sub { [
            { Features => { FeatureType => { ID => 6534 } }, EventType => { Description => 'NO ACCESS' }, EventDate => '2021-08-05T10:10:10' },
        ] });
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('There was a problem with your bin collection, please call');
        $mech->content_contains('quoting your collection address in the subject line');
        $mech->content_contains('mailto:ask&#64;peterborough.gov.uk?subject=1 Pope Way, Peterborough, PE1 3NA - missed bin');

        $b->mock('Premises_Events_Get', sub { [] }); # reset

        $b->mock('Streets_Events_Get', sub { [
            { Workpack => { Name => 'Waste-R1-050821' }, EventType => { Description => 'NO ACCESS PARKED CAR' }, EventDate => '2021-08-05T10:10:10' },
        ] });
        my $alt_jobs_fsd_get = [
            { JobID => 456, PreviousDate => '2021-08-02T10:10:10Z', NextDate => '2021-08-19T10:10:10Z', JobName => 'Empty Bin Recycling 240l' },
        ];
        $b->mock('Jobs_FeatureScheduleDates_Get', sub { $alt_jobs_fsd_get });
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('There is no need to report this as there was no access');
        $mech->content_contains('Thursday, 5th August 2021');
        $b->mock('Jobs_FeatureScheduleDates_Get', sub { $jobs_fsd_get });

        $b->mock('Streets_Events_Get', sub { [
            { Workpack => { Name => 'Waste-R1-040821' }, EventType => { Description => 'NO ACCESS PARKED CAR' }, EventDate => '2021-08-04T10:10:10' },
        ] });
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks('There is no need to report this as there was no access');

        $b->mock('Streets_Events_Get', sub { [
            { Workpack => { Name => 'Waste-R1-050821' }, EventType => { Description => 'STREET COMPLETED' }, EventDate => '2021-08-05T10:10:10' },
        ] });
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks('There was a problem with your bin collection');

        $b->mock('Streets_Events_Get', sub { [] }); # reset
    };
    subtest 'Check multiple schedules' => sub {
        my $alt_jobs_fsd_get = {
            Jobs_FeatureScheduleDates => [
                { JobID => 454, PreviousDate => '2021-08-03T10:10:10Z', NextDate => '2021-08-12T10:10:10Z', JobName => 'Empty Bin 240L Black' },
                { JobID => 455, PreviousDate => '2021-07-21T10:10:10Z', NextDate => '1900-01-01T00:00:00Z', JobName => 'Empty Bin 240L Black' },
                { JobID => 456, PreviousDate => '1900-01-01T00:00:00Z', NextDate => '2021-08-19T10:10:10Z', JobName => 'Empty Bin Recycling 240l' },
                { JobID => 457, PreviousDate => '2021-08-02T10:10:10Z', NextDate => '1900-01-01T00:00:00Z', JobName => 'Empty Bin Recycling 240l' },
            ],
        };
        $b->unmock('Jobs_FeatureScheduleDates_Get');
        $b->mock('call', sub {
            if ($_[1] eq 'Jobs_FeatureScheduleDates_Get') {
                return $alt_jobs_fsd_get;
            }
            return $b->original('call')->(@_);
        });
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('Monday, 2nd August 2021');
        $mech->content_contains('Thursday, 19th August 2021');
        $b->unmock('call');
        $b->mock('Jobs_FeatureScheduleDates_Get', sub { $jobs_fsd_get });
    };
    subtest 'Check no next schedule' => sub {
        my $alt_jobs_fsd_get = [
            { JobID => 454, PreviousDate => '2021-08-03T10:10:10Z', NextDate => undef, JobName => 'Empty Bin 240L Black' },
        ];
        $b->mock('Jobs_FeatureScheduleDates_Get', sub { $alt_jobs_fsd_get });
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $b->mock('Jobs_FeatureScheduleDates_Get', sub { $jobs_fsd_get });
    };
    subtest 'No planned services or clinical collection' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_lacks('Clinical');
        $mech->content_lacks('Brown');
    };
    subtest 'Future collection calendar' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480/calendar.ics');
        $mech->content_contains('DTSTART;VALUE=DATE:20210808');
        $mech->content_contains('DTSTART;VALUE=DATE:20210819');
    };
    subtest 'No reporting/requesting if open request' => sub {
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains('Report a recycling bin collection as missed');
        $mech->content_contains('Request a new recycling bin');
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 420 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains('A new recycling bin request has been made');
        $mech->content_contains('Report a recycling bin collection as missed');
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 254 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains('A recycling bin collection has been reported as missed');
        $mech->content_contains('Request a new recycling bin');
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 422 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains('A new black bin request has been made');
        $mech->content_lacks('Report a problem with a black bin');
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 492 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains('A recycling bin collection has been reported as missed');
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 424 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480/request');
        $mech->content_lacks('Large food caddy');
        $mech->content_lacks('All bins');
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 493 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480/request');
        $mech->content_lacks('Large food caddy');
        $mech->content_lacks('Small food caddy');
        $mech->content_lacks('All bins');
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 425 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_lacks('Request a new bin');
        $mech->get_ok('/waste/PE1 3NA:100090215480/request');
        $mech->content_like(qr/name="container-420"[^>]*disabled/s); # green
        $mech->content_like(qr/name="container-419"[^>]*disabled/s); # black
        $mech->content_lacks('Large food caddy');
        $mech->content_lacks('Small food caddy');
        $mech->content_lacks('All bins');
        $b->mock('ServiceRequests_Get', sub { [ ] }); # reset
    };
    subtest 'Request a new bin' => sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/PE1 3NA:100090215480/request');
        $mech->submit_form_ok({ with_fields => { 'container-425' => 1 }});
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'lost_stolen' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Request sent');
        $mech->content_like(qr/If your bin is not received two working days before scheduled collection\s+please call 01733 747474 to discuss alternative arrangements./);
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->detail, "Quantity: 1\n\n1 Pope Way, Peterborough, PE1 3NA\n\nReason: Lost/stolen bin";
        is $report->category, 'All bins';
        is $report->title, 'Request new All bins';
    };
    subtest 'Staff-only request reason shown correctly' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480/request');
        $mech->content_lacks("(Other - PD STAFF)");
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1 3NA:100090215480/request');
        $mech->submit_form_ok({ with_fields => { 'container-425' => 1 }});
        $mech->content_contains("(Other - PD STAFF)");
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'other_staff' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Request sent');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->detail, "Quantity: 1\n\n1 Pope Way, Peterborough, PE1 3NA\n\nReason: (Other - PD STAFF)";
        is $report->category, 'All bins';
        is $report->title, 'Request new All bins';
    };
    subtest 'Request food bins' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480/request');
        $mech->submit_form_ok({ with_fields => { 'container-424' => 1, 'container-423' => 1 }});
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'lost_stolen' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Request sent');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->detail, "Quantity: 1\n\n1 Pope Way, Peterborough, PE1 3NA\n\nReason: Lost/stolen bin";
        is $report->title, 'Request new Both food bins';
    };
    subtest 'Food bags link appears on front page when logged out' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->submit_form_ok({ with_fields => { 'container-428' => 1 } });
        $mech->content_contains('About you');
    };
    subtest 'Request food bags link can be disabled via config' => sub {
        $mech->log_in_ok($user->email);

        $body->set_extra_metadata( wasteworks_config => {} );
        $body->update;

        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains("Request more food bags");
        $mech->content_lacks("Food bags currently out of stock");

        $body->set_extra_metadata( wasteworks_config => { food_bags_disabled => 1 } );
        $body->update;

        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains("Food bags currently out of stock");
        $mech->content_lacks("Request more food bags");

        $body->set_extra_metadata( wasteworks_config => {} );
        $body->update;
    };
    subtest 'Request food bags from front page as non-staff' => sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->submit_form_ok({ with_fields => { 'container-428' => 1 } });
        $mech->content_contains('About you');
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('Request food bags');
        $mech->content_contains('Submit food bags request');
        $mech->content_lacks('Request new bins');
        $mech->content_lacks('Submit bin request');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Request sent');
        $mech->content_contains('Bin liners will be delivered in due course');
        $mech->content_lacks('Bins arrive typically within two weeks');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
    };
    subtest 'Request food bins from front page' => sub {
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->submit_form_ok({ with_fields => { 'service-FOOD_BINS' => 1 } });
        $mech->content_contains('name="service-FOOD_BINS" value="1"');
    };
    subtest 'Request bins from front page' => sub {
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->submit_form_ok({ with_fields => { 'container-420' => 1 } });
        $mech->content_contains('name="container-420" value="1"');
        $mech->content_contains('Black Bin');
        $mech->content_contains('Food bins');
        $mech->content_contains('food caddy');
        $mech->content_lacks('Food bags');
    };
    subtest 'Report missed collection' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480/report');
        $mech->submit_form_ok({ with_fields => { 'service-6534' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Missed collection reported');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->detail, "1 Pope Way, Peterborough, PE1 3NA";
        is $report->title, 'Report missed 240L Green bin';
    };
    subtest 'Report missed collection with extra text' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480/report');
        $mech->submit_form_ok({ with_fields => { 'service-6534' => 1, extra_detail => 'This is the extra detail.' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Missed collection reported');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->detail, "1 Pope Way, Peterborough, PE1 3NA\n\nExtra detail: This is the extra detail.";
        is $report->title, 'Report missed 240L Green bin';
    };
    subtest 'Report missed food bin' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480/report');
        $mech->submit_form_ok({ with_fields => { 'service-FOOD_BINS' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->content_lacks('Friday, 6 August'); # No date for food bins
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Missed collection reported');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->detail, "1 Pope Way, Peterborough, PE1 3NA";
        is $report->title, 'Report missed Food bins';
    };
    subtest 'No missed food bin report if open request' => sub {
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 252 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480/report');
        $mech->content_lacks('service-FOOD_BINS');
        $b->mock('ServiceRequests_Get', sub { [] }); # reset
    };
    subtest 'No food bag request if open request' => sub {
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 428 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_lacks('container-428');
        $mech->content_contains('Food bags order pending');
        $b->mock('ServiceRequests_Get', sub { [] }); # reset
    };
    subtest 'Report assisted collection' => sub {
        $b->mock('Premises_Attributes_Get', sub { [
            { AttributeDefinition => { Name => 'ASSISTED COLLECTION' } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480/report');
        $mech->submit_form_ok({ with_fields => { 'service-6534' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Missed collection reported');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->detail, "Green bin\n\n1 Pope Way, Peterborough, PE1 3NA";
        is $report->title, 'Report missed assisted collection';
        $b->mock('Premises_Attributes_Get', sub { [] });
    };
    subtest 'Report broken bin, already reported' => sub {
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 538 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        $mech->content_like(qr/name="service-538" value="1"\s+disabled/);
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 497 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        $mech->content_like(qr/name="service-497" value="1"\s+disabled/);
        $b->mock('ServiceRequests_Get', sub { [] }); # reset
    };
    subtest 'Report broken bin' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        $mech->submit_form_ok({ with_fields => { 'service-538' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->content_contains('The bin’s lid is damaged', "Damaged lid category found");
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Damaged bin reported');
        $mech->content_contains('Please leave your bin accessible');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->title, 'Damaged 240L Black bin';
        is $report->detail, "The bin’s lid is damaged\n\n1 Pope Way, Peterborough, PE1 3NA";
        $mech->back;
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('You have already submitted this form.');
    };
    subtest 'Report bin not returned' => sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        my $tree = HTML::TreeBuilder->new_from_content($mech->content());
        my $checkbox_497 = $tree->look_down(
            'id' => 'service-497-0'
        );
        is ($checkbox_497->attr('disabled'), 'disabled', '"Bin not returned to collection point" disabled for user');
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        $tree = HTML::TreeBuilder->new_from_content($mech->content());
        $checkbox_497 = $tree->look_down(
            'id' => 'service-497-0'
        );
        is ($checkbox_497->attr('disabled'), undef, '"Bin not returned to collection point" enabled for staff');
        $mech->submit_form_ok({ with_fields => { 'service-497' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Damaged bin reported');
        $mech->content_lacks('Please leave your bin accessible');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->title, 'Bin not returned';
        is $report->detail, "The bin wasn’t returned to the collection point\n\n1 Pope Way, Peterborough, PE1 3NA";
    };
    subtest 'Report broken wheels' => sub {
        FixMyStreet::DB->resultset('Problem')->search(
            {
                send_state => 'unprocessed'
            }
        )->update( { send_state => 'sent' } );


        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        $mech->submit_form_ok({ with_fields => { 'service-541' => 1, extra_detail => 'Some extra detail.' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->content_contains('The bin’s wheels are damaged', "Damaged wheel category found");
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Damaged bin reported');
        $mech->content_contains('Please leave your bin accessible');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');

        FixMyStreet::Script::Reports::send();

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->send_state, 'sent', 'Report marked as sent';
        is $report->title, 'Damaged 240L Black bin';
        is $report->detail, "The bin’s wheels are damaged\n\n1 Pope Way, Peterborough, PE1 3NA\n\nExtra detail: Some extra detail.";

        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[title]'), $report->title, 'title param sent';
        is $cgi->param('attribute[extra_detail]'), undef, 'extra_detail param not sent';
    };
    subtest 'Report multiple problems at once' => sub {
        my $problems = FixMyStreet::DB->resultset('Problem');
        $problems->delete;

        is $problems->count, 0;

        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        $mech->submit_form_ok({ with_fields => { 'service-541' => 1, 'service-540' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->content_contains('Green bin');
        $mech->content_contains('Black bin');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Damaged bins reported');
        $mech->content_contains('Please leave your bin accessible');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');

        is $problems->count, 2;

        my ($black_report, $green_report) = $problems->search(undef, { order_by => "category" })->all;

        is $black_report->title, 'Damaged 240L Black bin';
        is $black_report->category, '240L Black - Wheels';
        is $black_report->detail, "The bin’s wheels are damaged\n\n1 Pope Way, Peterborough, PE1 3NA";
        is $green_report->title, 'Damaged 240L Green bin';
        is $green_report->category, '240L Green - Wheels';
        is $green_report->detail, "The bin’s wheels are damaged\n\n1 Pope Way, Peterborough, PE1 3NA";
    };
    subtest 'Report broken large bin' => sub {
        $b->mock('Premises_Attributes_Get', sub { [
            { AttributeDefinition => { Name => 'LARGE BIN' } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        $mech->submit_form_ok({ with_fields => { 'service-538' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->content_contains('Black bin');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Damaged bin reported');
        $mech->content_contains('Please leave your bin accessible');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->title, '360L Black';
        is $report->detail, "The bin’s lid is damaged, exchange bin\n\n1 Pope Way, Peterborough, PE1 3NA";
        $b->mock('Premises_Attributes_Get', sub { [] });
    };
    subtest 'Report missed large bin' => sub {
        set_fixed_time('2021-08-02T10:00:00Z');
        $b->mock('Premises_Attributes_Get', sub { [
            { AttributeDefinition => { Name => 'LARGE BIN' } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480/report');
        $mech->submit_form_ok({ with_fields => { 'service-6533' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Missed collection reported');
        $mech->content_contains('Show upcoming bin days');
        $mech->content_contains('/waste/PE1%203NA:100090215480"');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->detail, "1 Pope Way, Peterborough, PE1 3NA";
        is $report->title, 'Report missed 360L Black bin';
        $b->mock('Premises_Attributes_Get', sub { [] });

        # Clear any waiting emails
        FixMyStreet::Script::Reports::send();
        $mech->clear_emails_ok;
    };
    subtest 'Only staff see "Request new bin" link' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_lacks("Request a new bin");
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_lacks("Request a new bin");
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains("Request a new bin") or diag $mech->content;
        $mech->log_out_ok;
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'peterborough',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => { bartec => { peterborough => {
        url => 'http://example.org/',
        auth_url => 'http://auth.example.org/',
        sample_data => 1 } },
        waste => { peterborough => 1 },
        waste_features => {
            peterborough => {
                max_requests_per_day   => 3,
                max_properties_per_day => 1,
            },
        },
    },
    STAGING_FLAGS => {
        send_reports => 1,
    },
}, sub {
    my ($b) = shared_bartec_mocks();

    subtest 'test waste max-per-day' => sub {
        SKIP: {
            # MEMCACHED_HOST needs to be set to 'memcached.svc' in
            # general.yml-example (or whatever config file you are using)
            skip( "No memcached", 7 )
                unless Memcached::set( 'waste-prop-test', 1 );
            Memcached::delete("waste-prop-test");
            Memcached::delete("waste-req-test");
            $mech->get_ok('/waste/PE1 3NA:100090215480');
            $mech->get_ok('/waste/PE1 3NA:100090215480');
            $mech->get('/waste/PE1 3NA:100090215489');
            is $mech->res->code, 403,
                'Should be forbidden due to property limit';
            $mech->content_contains('limited the number');
            $mech->get('/waste/PE1 3NA:100090215480');
            is $mech->res->code, 403,
                'Should be forbidden due to overall view limit';
            $mech->log_in_ok('staff@example.net');
            $mech->get_ok(
                '/waste/PE1 3NA:100090215480',
                'Staff user shouldn\'t be limited'
            );

            $mech->log_out_ok;
        }
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'peterborough',
    COBRAND_FEATURES => {
        bartec => { peterborough => {
            sample_data => 1,
            blocked_uprns => [ '100090215480' ]
        } },
        waste => { peterborough => 1 }
    },
}, sub {
    subtest 'Blocked UPRN check' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'PE1 3NA' } });
        $mech->content_contains('10 Pope Way');
        $mech->content_lacks('1 Pope Way');
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'PE1 3NA' } });
        $mech->content_contains('10 Pope Way');
        $mech->content_contains('1 Pope Way');
        $mech->log_out_ok;
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'peterborough', 'bromley' ],
    COBRAND_FEATURES => {
        bartec => { peterborough => {
            sample_data => 1,
        } },
        waste => {
            peterborough => 1,
            bromley => 1
        },
        waste_features => {
            peterborough => {
                admin_config_enabled => 1,
            }
        }
    },
}, sub {
    $body->set_extra_metadata( wasteworks_config => undef );
    $body->update;

    subtest 'WasteWorks configuration editing' => sub {
        ok $mech->host('peterborough.fixmystreet.com');
        $body->unset_extra_metadata('wasteworks_config');
        $body->update;

        subtest 'Only cobrands with feature enabled are visible' => sub {
            $mech->log_in_ok($super->email);
            $mech->get_ok('/admin/waste');
            $mech->content_contains("<a href=\"waste/" . $body->id . "\">Peterborough City Council</a>");
            $mech->content_lacks("<a href=\"waste/" . $bromley->id . "\">Bromley Council</a>");
            $mech->log_out_ok;
        };

        subtest 'Permission required to access page' => sub {
            $mech->log_in_ok($staff->email);

            $mech->get('/admin/waste/' . $body->id);
            is $mech->res->code, 404, 'cannot access page';

            $staff->user_body_permissions->create({ body => $body, permission_type => 'wasteworks_config' });

            $mech->get_ok('/admin/waste/' . $body->id);
            $mech->content_lacks("Save JSON");
            $mech->log_out_ok;
        };

        subtest 'Submitting JSON with invalid syntax shows error' => sub {
            is $body->get_extra_metadata('wasteworks_config'), undef;

            $mech->log_in_ok($super->email);
            $mech->get_ok('/admin/waste/' . $body->id);

            $mech->submit_form_ok({ with_fields => { body_config => '{"foo": "bar",}' } });
            $mech->content_contains("Please correct the errors below");
            $mech->content_contains("Not a valid JSON string: &#39;&quot;&#39; expected, at character offset 14 (before &quot;}&quot;)");

            $body->discard_changes;
            is $body->get_extra_metadata('wasteworks_config'), undef;
        };

        subtest 'Submitting invalid JSON shows error' => sub {
            is $body->get_extra_metadata('wasteworks_config'), undef;

            $mech->submit_form_ok({ with_fields => { body_config => '1234' } });
            $mech->content_contains("Please correct the errors below");
            $mech->content_contains("Not a valid JSON string: JSON text must be an object or array (but found number, string, true, false or null, use allow_nonref to allow this)");

            $body->discard_changes;
            is $body->get_extra_metadata('wasteworks_config'), undef;
        };

        subtest 'Submitting valid JSON but not an object shows error' => sub {
            is $body->get_extra_metadata('wasteworks_config'), undef;

            $mech->submit_form_ok({ with_fields => { body_config => '[1,2,3,4]' } });
            $mech->content_contains("Config must be a JSON object literal, not array.");

            $body->discard_changes;
            is $body->get_extra_metadata('wasteworks_config'), undef;
        };

        subtest 'Submitting valid JSON object gets stored OK' => sub {
            is $body->get_extra_metadata('wasteworks_config'), undef;

            $mech->submit_form_ok({ with_fields => { body_config => '{"base_price": 2350, "daily_slots": 40}' } });
            $mech->content_contains("Updated!");

            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), { base_price => 2350, daily_slots => 40 };
        };

        subtest 'Submitting valid inputs gets stored OK' => sub {
            $mech->submit_form_ok({ with_fields => { per_item_costs => 1, daily_slots => 50, base_price => 1234, items_per_collection_max => 7 } });
            $mech->content_contains("Updated!");
            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), {
                show_location_page => 'noshow',
                show_individual_notes => 0,
                band1_max => '',
                band1_price => '',
                daily_slots => 50,
                free_mode => 0, # not checked
                food_bags_disabled => 0, # not checked
                base_price => 1234, per_item_costs => 1, per_item_min_collection_price => '', items_per_collection_max => 7 };
        };
    };
};

sub shared_bartec_mocks {
    my $b = Test::MockModule->new('Integrations::Bartec');
    $b->mock('Authenticate', sub {
        { Token => { TokenString => "TOKEN" } }
    });
    $b->mock('Jobs_Get', sub { [
        { WorkPack => { Name => 'Waste-R1-010821' }, Name => 'Empty Bin 240L Black', ScheduledStart => '2021-08-01T07:00:00' },
        { WorkPack => { Name => 'Waste-R1-050821' }, Name => 'Empty Bin Recycling 240l', ScheduledStart => '2021-08-05T07:00:00' },
    ] });
    my $jobs_fsd_get = [
        { JobID => 123, PreviousDate => '2021-08-01T11:11:11Z', NextDate => '2021-08-08T11:11:11Z', JobName => 'Empty Bin 240L Black' },
        { JobID => 456, PreviousDate => '2021-08-05T10:10:10Z', NextDate => '2021-08-19T10:10:10Z', JobName => 'Empty Bin Recycling 240l' },
        { JobID => 789, PreviousDate => '2021-08-06T10:10:10Z', JobName => 'Empty Brown Bin' },
        { JobID => 890, NextDate => '2022-08-06T10:10:10Z', JobName => 'Empty Clinical Waste' },
    ];
    my $fs_get = [
        { JobName => 'Empty Bin 240L Black', Feature => { Status => { Name => "IN SERVICE" }, FeatureType => { ID => 6533 } }, Frequency => 'Every two weeks' },
        { JobName => 'Empty Bin Recycling 240l', Feature => { Status => { Name => "IN SERVICE" }, FeatureType => { ID => 6534 } } },
        { JobName => 'Empty Clinical Waste', Feature => { Status => { Name => "IN SERVICE" }, FeatureType => { ID => 6815 } } },
        { JobName => 'Empty Brown Bin', Feature => { Status => { Name => "PLANNED" }, FeatureType => { ID => 6579 } } },
    ];
    $b->mock('Jobs_FeatureScheduleDates_Get', sub { $jobs_fsd_get });
    $b->mock('Features_Schedules_Get', sub { $fs_get });
    $b->mock('ServiceRequests_Get', sub { [
        # No open requests at present
    ] });
    $b->mock('Premises_Detail_Get', sub { {} });
    $b->mock('Premises_Attributes_Get', sub { [] });
    $b->mock(
        'Premises_AttributeDefinitions_Get',
        sub {
            [
                { Name => 'FREE BULKY USED', ID => 123 },
            ];
        }
    );
    $b->mock( 'Premises_Attributes_Delete', sub { } );
    $b->mock('Premises_Events_Get', sub { [
        # No open events at present
    ] });
    $b->mock('Streets_Events_Get', sub { [
        # No open events at present
    ] });

    return $b, $jobs_fsd_get, $fs_get;
}

done_testing;
