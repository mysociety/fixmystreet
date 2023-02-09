use utf8;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Path::Tiny;
use File::Temp 'tempdir';
use CGI::Simple;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Peterborough');
$mock->mock('_fetch_features', sub { [] });

my $cobrand = FixMyStreet::Cobrand::Peterborough->new;

my $sample_file = path(__FILE__)->parent->child("sample.jpg");

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
my $staff_bromley = $mech->create_user_ok('staff_bromley@example.net', name => 'Bromley Staff User', from_body => $bromley->id);
$staff_bromley->user_body_permissions->create({ body => $bromley, permission_type => 'contribute_as_another_user' });
$staff_bromley->user_body_permissions->create({ body => $bromley, permission_type => 'report_mark_private' });

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
create_contact(
    { category => 'Bulky collection', email => 'Bartec-238' },
    'Bulky goods',
    { code => 'ITEM_01', required => 1 },
    { code => 'ITEM_02' },
    { code => 'ITEM_03' },
    { code => 'ITEM_04' },
    { code => 'ITEM_05' },
    { code => 'CHARGEABLE' },
    { code => 'CREW NOTES' },
    { code => 'DATE' },
    { code => 'payment' },
    { code => 'payment_method' },
    { code => 'property_id' },
);
create_contact(
    { category => 'Bulky cancel', email => 'Bartec-545' },
    'Bulky goods',
    { code => 'ORIGINAL_SR_NUMBER', required => 1 },
    { code => 'COMMENTS',           required => 1 },
);

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
        set_fixed_time('2021-08-06T10:00:00Z');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('Report a recycling bin collection as missed');
        set_fixed_time('2021-08-06T14:00:00Z');
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
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'cracked' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Request sent');
        $mech->content_like(qr/If your bin is not received two working days before scheduled collection\s+please call 01733 747474 to discuss alternative arrangements./);
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->detail, "Quantity: 1\n\n1 Pope Way, Peterborough, PE1 3NA\n\nReason: Cracked bin\n\nPlease remove cracked bin.";
        is $report->category, 'All bins';
        is $report->title, 'Request new All bins';
    };
    subtest 'Report a cracked bin raises a bin delivery request' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        $mech->submit_form_ok({ with_fields => { 'service-420' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('The bin is cracked', "Cracked category found");
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Damaged bin reported');
        $mech->content_contains('Please leave your bin accessible');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->detail, "Quantity: 1\n\n1 Pope Way, Peterborough, PE1 3NA\n\nReason: Cracked bin\n\nPlease remove cracked bin.";
        is $report->category, 'Green 240L bin';
        is $report->title, 'Request new 240L Green';
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
        $mech->content_contains('Food bags will be supplied by the crew on your next collection day.');
        $mech->content_lacks('Bins arrive typically within two weeks');
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
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->detail, "Green bin\n\n1 Pope Way, Peterborough, PE1 3NA";
        is $report->title, 'Report missed assisted collection';
        $b->mock('Premises_Attributes_Get', sub { [] });
    };
    subtest 'Report broken bin, already reported' => sub {
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 419 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        $mech->content_like(qr/name="service-419" value="1"\s+disabled/);
        $mech->content_like(qr/name="service-538" value="1"\s+disabled/);
        $mech->content_like(qr/name="service-541" value="1"\s+disabled/);
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
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->title, 'Damaged 240L Black bin';
        is $report->detail, "The bin’s lid is damaged\n\n1 Pope Way, Peterborough, PE1 3NA";
        $mech->back;
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('You have already submitted this form.');
    };
    subtest 'Report bin not returned' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        $mech->submit_form_ok({ with_fields => { 'service-497' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Damaged bin reported');
        $mech->content_lacks('Please leave your bin accessible');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->title, 'Bin not returned';
        is $report->detail, "The bin wasn’t returned to the collection point\n\n1 Pope Way, Peterborough, PE1 3NA";
    };
    subtest 'Report broken wheels' => sub {
        FixMyStreet::DB->resultset('Problem')->search(
            {
                whensent => undef
            }
        )->update( { whensent => \'current_timestamp' } );


        $mech->get_ok('/waste/PE1 3NA:100090215480/problem');
        $mech->submit_form_ok({ with_fields => { 'service-541' => 1, extra_detail => 'Some extra detail.' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->content_contains('The bin’s wheels are damaged', "Damaged wheel category found");
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Damaged bin reported');
        $mech->content_contains('Please leave your bin accessible');

        FixMyStreet::Script::Reports::send();

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        ok $report->whensent, 'Report marked as sent';
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
    ALLOWED_COBRANDS => 'peterborough',
    COBRAND_FEATURES => {
        bartec => { peterborough => {
            sample_data => 1,
        } },
        waste => { peterborough => 1 },
    },
}, sub {
    my ($b, $jobs_fsd_get) = shared_bartec_mocks();

    subtest 'Bulky goods not available if feature flag not set' => sub {
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks("Book bulky goods collection");

        $mech->get_ok('/waste/PE1%203NA:100090215480/bulky');
        is $mech->res->code, 200, "got 200";
        is $mech->res->previous->code, 302, "got 302 for redirect";
        is $mech->uri->path, '/waste/PE1%203NA:100090215480', 'redirected to property page';
    };
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'peterborough',
    COBRAND_FEATURES => {
        bartec => { peterborough => {
            sample_data => 1,
        } },
        waste => { peterborough => 1 },
        waste_features => { peterborough => {
            bulky_enabled => 1,
        } },
        payment_gateway => { peterborough => {
            cc_url => 'https://example.org/scp/',
            scp_fund_code => 2,
            customer_ref => 'ABC12345',
            siteID => 999,
            scpID => 1234567,
            hmac_id => 789,
            hmac => 'bmV2ZXIgZ29ubmEgZ2l2ZSB5b3UgdXAKbmV2ZXIgZ29ubmEgbGV0IHlvdSBkb3duCm5ldmVyIGdvbm5hIHJ1bg==',
        } },
    },
    STAGING_FLAGS => {
        send_reports => 1,
    },
    PHOTO_STORAGE_BACKEND => 'FileSystem',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => tempdir( CLEANUP => 1 ),
    },
}, sub {
    my ($b, $jobs_fsd_get) = shared_bartec_mocks();

    subtest 'Bulky Waste on bin days page' => sub {
        my $bin_days_url = 'http://localhost/waste/PE1%203NA:100090215480';

        note 'No pricing at all';
        my $cfg = {};
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_lacks('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £0.00</strong>');

        note 'Base price defined';
        $cfg = { base_price => '1525' };
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_lacks('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £15.25</strong>');

        note 'Per item cost:';
        note '    with no items';
        $cfg = {
            %$cfg,
            per_item_costs => 1,
        };
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_lacks('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £0.00</strong>');

        note '    with a 0-cost item';
        $cfg = {
            %$cfg,
            item_list => [
                { price => 0 },
                { price => 2000 },
            ],
        };
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_lacks('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £0.00</strong>');

        note '    with a non-0-cost item';
        $cfg = {
            %$cfg,
            item_list => [
                { price => 2000 },
                { price => 1999 },
            ],
        };
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_lacks('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £19.99</strong>');

        note 'Free collection';
        $cfg = {
            %$cfg,
            free_mode => 1,
        };
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_contains('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £19.99</strong> Afterwards');
    };

    $body->set_extra_metadata(
        wasteworks_config => {
            base_price => '2350',
            per_item_costs => 0,
            free_mode => '0',
            item_list => [
                {   bartec_id => '1001',
                    category  => 'Audio / Visual Elec. equipment',
                    message   => '',
                    name      => 'Amplifiers',
                    price     => '1001',
                },
                {   bartec_id => '1001',
                    category  => 'Audio / Visual Elec. equipment',
                    message   => '',
                    name      => 'DVD/BR Video players',
                    price     => '2002',
                    max => 1,
                },
                {   bartec_id => '1001',
                    category  => 'Audio / Visual Elec. equipment',
                    message   => '',
                    name      => 'HiFi Stereos',
                    price     => '3003',
                    max => 2,
                },

                {   bartec_id => '1002',
                    category  => 'Baby / Toddler',
                    message   => '',
                    name      => 'Childs bed / cot',
                    price     => '4040',
                },
                {   bartec_id => '1002',
                    category  => 'Baby / Toddler',
                    message   => '',
                    name      => 'High chairs',
                    price     => '5050',
                },

                {   bartec_id => '1003',
                    category  => 'Bedroom',
                    message   => '',
                    name      => 'Chest of drawers',
                    price     => '6060',
                },
                {   bartec_id => '1003',
                    category  => 'Bedroom',
                    message   => 'Please dismantle',
                    name      => 'Wardrobes',
                    price     => '7070',
                },
                {   bartec_id => '1004',
                    category  => 'Bedroom',
                    message   => 'Please place in a clear bag',
                    name      => 'Linen & Bedding',
                    price     => '7070',
                },
            ],
        },
    );
    $body->update;

    my $sent_params;
    my $call_params;
    my $pay = Test::MockModule->new('Integrations::SCP');

    $pay->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $call_params = { @_ };
    });
    $pay->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        $pay->original('pay')->($self, $sent_params);
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
                    authDetails => {
                        authCode              => 112233,
                        continuousAuditNumber => 123,
                    },
                    paymentHeader => {
                        uniqueTranId => 54321
                    }
                }
            }
        };
    });

    subtest 'Bulky goods collection booking' => sub {
        # XXX NB Currently, these tests do not describe the correct
        # behaviour of the system. They are here to remind us to update them as
        # we break them by implementing the correct behaviour :)

        subtest '?type=bulky redirect before any bulky booking made' => sub {
            $mech->get_ok('/waste?type=bulky');
            is $mech->uri, 'http://localhost/waste?type=bulky',
                'No redirect if no address data';
            $mech->content_contains( 'What is your address?',
                'user on address page' );

            $mech->submit_form_ok(
                { with_fields => { postcode => 'PE1 3NA' } } );
            $mech->submit_form_ok(
                { with_fields => { address => 'PE1 3NA:100090215480' } } );
            is $mech->uri,
                'http://localhost/waste/PE1%203NA:100090215480/bulky',
                'Redirected to /bulky if address data';
        };

        subtest 'No commercial bookings' => sub {
            $b->mock('Premises_Detail_Get', sub { { BLPUClassification => { ClassificationCode => 'C001' } } });
            $mech->get_ok('/waste/PE1%203NA:100090215480');
            $mech->content_contains('listed as a commercial premises');
            $mech->content_lacks('Book bulky goods collection');
            $b->mock('Premises_Detail_Get', sub { {} });
        };

        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks( 'Cancel booking', 'Cancel option unavailable' );
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );

        subtest 'Intro page' => sub {
            $mech->content_contains('Book bulky goods collection');
            $mech->content_contains('Before you start your booking');
            # XXX make this dynamic according to config in DB
            $mech->content_contains('You can request up to <strong>5 items per collection');
            # XXX and this one too
            $mech->content_contains('You can cancel your booking anytime up until 23:55 the day before the collection is scheduled');
            $mech->submit_form_ok;
        };

        subtest 'Residency check page' => sub {
            $mech->content_contains('Do you live at the property or are you booking on behalf of the householder?');
            $mech->submit_form_ok({ with_fields => { resident => 'No' } });
            $mech->content_contains('cannot book');
            $mech->back;
            $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        };

        subtest 'About you page' => sub {
            $mech->content_contains('About you');
            $mech->content_contains('Aragon Direct Services may contact you to obtain more');
            $mech->submit_form_ok({ with_fields => { name => 'Bob Marge' } });
            $mech->content_contains('Please provide email and/or phone');
            $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        };

        subtest 'Choose date page' => sub {
            $mech->content_contains('Choose date for collection');
            $mech->content_contains('Available dates');
            $mech->content_contains('05 August');
            $mech->content_contains('12 August');
            $mech->content_contains('19 August');
            $mech->content_contains('26 August');
            $mech->content_lacks('02 September'); # Max of 4 dates fetched
            $mech->submit_form_ok(
                {   with_fields =>
                        { chosen_date => '2022-08-19T00:00:00' }
                }
            );
        };

        subtest 'Add items page' => sub {
            $mech->content_contains('Add items for collection');
            $mech->content_contains('Item 1');
            $mech->content_contains('Item 2');
            $mech->content_contains('Item 3');
            $mech->content_contains('Item 4');
            $mech->content_contains('Item 5');
            $mech->content_like(
                qr/<option value="Amplifiers".*>Amplifiers<\/option>/);
            $mech->content_contains('data-extra="{&quot;message&quot;:&quot;Please place in a clear bag&quot;}"');

            $mech->submit_form_ok;
            $mech->content_contains(
                'Please select an item');

            $mech->submit_form_ok(
                {   with_fields => {
                        'item_1' => 'Amplifiers',
                        'item_photo_1' => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
                        'item_2' => 'High chairs',
                        'item_3' => 'Wardrobes',
                    },
                },
            );
        };

        subtest 'Location details page' => sub {
            $mech->content_contains('Location details');
            $mech->content_contains('Please tell us about anything else you feel is relevant');
            $mech->content_contains('Help us by attaching a photo of where the items will be left for collection');
            $mech->submit_form_ok({ with_fields => {
                location => 'behind the hedge in the front garden',
                location_photo => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
            } });
        };

        sub test_summary {
            my $date_day = shift;
            $mech->content_contains('Request a bulky waste collection');
            $mech->content_lacks('Your bulky waste collection');
            $mech->content_contains('Booking Summary');
            $mech->content_contains('Please read carefully all the details');
            $mech->content_contains('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Amplifiers/s);
            $mech->content_contains('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*High chairs/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Wardrobes/s);
            # Extra text for wardrobes
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">Please dismantle/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('2 remaining slots available');
            $mech->content_contains('behind the hedge in the front garden');
            $mech->content_contains('<img class="img-preview is--medium" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_lacks('No image of the location has been attached.');
            $mech->content_contains('£23.50');
            $mech->content_contains("<dd>$date_day August</dd>");
            my $day_before = $date_day - 1;
            $mech->content_contains("23:55 on $day_before August 2022");
            $mech->content_lacks('Cancel this booking');
            $mech->content_lacks('Show upcoming bin days');
        }
        sub test_summary_submission {
            # external redirects make Test::WWW::Mechanize unhappy so clone
            # the mech for the redirect
            my $mech2 = $mech->clone;
            $mech2->submit_form_ok({ with_fields => { tandc => 1 } });
            is $mech2->res->previous->code, 302, 'payments issues a redirect';
            is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";
        }
        sub test_payment_page {
            my $sent_params = shift;
            my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

            is $new_report->category, 'Bulky collection', 'correct category on report';
            is $new_report->title, 'Bulky goods collection', 'correct title on report';
            is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $new_report->state, 'unconfirmed', 'report not confirmed';

            is $sent_params->{items}[0]{amount}, 2350, 'correct amount used';

            $new_report->discard_changes;
            is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

            return ($token, $new_report, $report_id);
        }

        subtest 'Summary page' => sub { test_summary(19) }; # 19th August

        subtest 'Slot has become fully booked' => sub {
            # Slot has become fully booked in the meantime - should
            # redirect to date selection

            # Mock out a bulky workpack with maximum number of jobs
            $b->mock(
                'WorkPacks_Get',
                sub {
                    [   {   'ID'   => '190822',
                            'Name' => 'Waste-BULKY WASTE-190822',
                        },
                    ];
                },
            );
            my $other_uprn = 10001;
            $b->mock( 'Jobs_Get_for_workpack',
                [ map { { Job => { UPRN => $other_uprn++ } } } 1 .. 40 ]
            );

            $mech->submit_form_ok( { with_fields => { tandc => 1 } } );
            $mech->content_contains('Choose date for collection');
            $mech->content_contains(
                'Unfortunately, the slot you originally chose has become fully booked. Please select another date.',
            );
            $mech->content_lacks( '2022-08-19T00:00:00', 'Original date no longer an option' );
        };

        subtest 'New date selected, submit pages again' => sub {
            $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
            $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs', 'item_3' => 'Wardrobes' } });
            $mech->submit_form_ok({ with_fields => { location => 'behind the hedge in the front garden' } });
        };

        subtest 'Summary submission' => \&test_summary_submission;

        subtest 'Payment page' => sub {
            my ($token, $new_report, $report_id) = test_payment_page($sent_params);
            # Check changing your mind from payment page
            $mech->get_ok("/waste/pay_cancel/$report_id/$token?property_id=PE1%203NA:100090215480");
        };

        subtest 'Summary page' => sub { test_summary(26) }; # 26th August
        subtest 'Summary submission again' => \&test_summary_submission;
        subtest 'Payment page again' => sub {
            my ($token, $new_report, $report_id) = test_payment_page($sent_params);

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
            is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        };

        my $report;
        subtest 'Confirmation page' => sub {
            $mech->content_contains('Payment successful');

            $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            is $report->detail, "Address: 1 Pope Way, Peterborough, PE1 3NA";
            is $report->category, 'Bulky collection';
            is $report->title, 'Bulky goods collection';
            is $report->get_extra_field_value('uprn'), 100090215480;
            is $report->get_extra_field_value('DATE'), '2022-08-26T00:00:00';
            is $report->get_extra_field_value('CREW NOTES'), 'behind the hedge in the front garden';
            is $report->get_extra_field_value('CHARGEABLE'), 'CHARGED';
            is $report->get_extra_field_value('ITEM_01'), 'Amplifiers';
            is $report->get_extra_field_value('ITEM_02'), 'High chairs';
            is $report->get_extra_field_value('ITEM_03'), 'Wardrobes';
            is $report->get_extra_field_value('ITEM_04'), '';
            is $report->get_extra_field_value('ITEM_05'), '';
            is $report->get_extra_field_value('property_id'), 'PE1 3NA:100090215480';
            is $report->photo,
                '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg,74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';
        };

        # Collection date: 2022-08-26T00:00:00
        # Time/date that is within the cancellation & refund window:
        my $good_date = '2022-08-25T05:44:59Z'; # 06:44:59 UK time
        # Time/date that is within the cancellation but not refund window:
        my $no_refund_date = '2022-08-25T12:00:00Z'; # 13:00:00 UK time
        # Time/date that isn't:
        my $bad_date = '2022-08-25T23:55:00Z';

        subtest 'View own booking' => sub {
            $mech->log_in_ok($user->email);
            $mech->get_ok('/report/' . $report->id);

            $mech->content_contains('Booking Summary');
            $mech->content_contains('1 Pope Way, Peterborough, PE1 3NA');
            $mech->content_lacks('Please read carefully all the details');
            $mech->content_lacks('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Amplifiers/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*High chairs/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Wardrobes/s);
            # Extra text for wardrobes
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">Please dismantle/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('2 remaining slots available');
            $mech->content_contains('behind the hedge in the front garden');
            $mech->content_contains('£23.50');
            $mech->content_contains('26 August');
            $mech->content_lacks('Request a bulky waste collection');
            $mech->content_contains('Your bulky waste collection');
            $mech->content_contains('Show upcoming bin days');

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');

            set_fixed_time($good_date);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains("You can cancel this booking till");
            $mech->content_contains("23:55 on 25 August 2022");

            # Presence of external_id in report implies we have sent request
            # to Bartec
            $mech->content_lacks('/waste/PE1%203NA:100090215480/bulky_cancel');
            $mech->content_lacks('Cancel this booking');

            $report->external_id('Bartec-SR00100001');
            $report->update;
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains('/waste/PE1%203NA:100090215480/bulky_cancel');
            $mech->content_contains('Cancel this booking');

            # Cannot cancel if cancellation window passed
            set_fixed_time($bad_date);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_lacks("You can cancel this booking till");
            $mech->content_lacks("23:55 on 25 August 2022");
            $mech->content_lacks('/waste/PE1%203NA:100090215480/bulky_cancel');
            $mech->content_lacks('Cancel this booking');

            set_fixed_time($good_date);
        };

        subtest "Can't view booking logged-out" => sub {
            $mech->log_out_ok;
            $mech->get('/report/' . $report->id);

            is $mech->res->code, 403, "got 403";
            $mech->content_contains('Sorry, you don’t have permission to do that.');
        };

        subtest "Can't view someone else's booking" => sub {
            $mech->log_in_ok($user2->email);
            $mech->get('/report/' . $report->id);

            is $mech->res->code, 403, "got 403";
            $mech->content_contains('Sorry, you don’t have permission to do that.');
        };

        subtest "Staff can view booking" => sub {
            $mech->log_in_ok($staff->email);
            $mech->get_ok('/report/' . $report->id);

            $mech->content_contains('Booking Summary');
            $mech->content_contains('Your bulky waste collection');

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');
            $mech->content_contains("You can cancel this booking till");
            $mech->content_contains('/waste/PE1%203NA:100090215480/bulky_cancel');
            $mech->content_contains('Cancel this booking');
        };

        subtest "Superusers can view booking" => sub {
            $mech->log_in_ok($super->email);
            $mech->get_ok('/report/' . $report->id);

            $mech->content_contains('Booking Summary');
            $mech->content_contains('Your bulky waste collection');

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');
            $mech->content_contains("You can cancel this booking till");
            $mech->content_contains('/waste/PE1%203NA:100090215480/bulky_cancel');
            $mech->content_contains('Cancel this booking');
        };

        subtest "Can follow link to booking from bin days page" => sub {
            $mech->get_ok('/waste/PE1%203NA:100090215480');
            $mech->follow_link_ok( { text_regex => qr/Check collection details/i, }, "follow 'Check collection...' link" );
            is $mech->uri->path, '/report/' . $report->id , 'Redirected to waste base page';
        };

        subtest 'Email confirmation of booking' => sub {
            FixMyStreet::Script::Reports::send();
            my $email = $mech->get_email->as_string;
            like $email, qr/1 Pope Way/;
            like $email, qr/Collection date: 26 August/;
            like $email, qr{rborough.example.org/waste/PE1%203NA%3A100090215480/bulky_cancel};
            $mech->clear_emails_ok;
        };

        sub reminder_check {
            my ($day, $time, $days) = @_;
            set_fixed_time("2022-08-$day" . "T$time:00:00Z");
            $cobrand->bulky_reminders;
            if ($days) {
                my $email = $mech->get_email->as_string;
                like $email, qr/26 August/;
                like $email, qr/Wardrobe/;
                like $email, qr{peterborough.example.org/waste/PE1%203NA%3A100090};
                like $email, qr{215480/bulky_cancel};
                if ($days == 3) {
                    like $email, qr/This is a reminder that your collection is in 3 days./;
                } else {
                    like $email, qr/This is a reminder that your collection is tomorrow./;
                }
                $mech->clear_emails_ok;
            } else {
                $mech->email_count_is(0);
            }
        }
        subtest 'Email reminders' => sub {
            reminder_check(22, 10, 0);
            reminder_check(23, 10, 3);
            reminder_check(23, 11, 0);
            reminder_check(24, 10, 0);
            reminder_check(25, 10, 1);
            reminder_check(25, 11, 0);
            reminder_check(26, 10, 0);
        };

        $report->discard_changes;
        $report->update({ external_id => undef }); # For cancellation

        subtest '?type=bulky redirect after bulky booking made' => sub {
            $mech->get_ok('/waste?type=bulky');
            $mech->content_contains( 'What is your address?',
                'user on address page' );
            $mech->submit_form_ok(
                { with_fields => { postcode => 'PE1 3NA' } } );
            $mech->submit_form_ok(
                { with_fields => { address => 'PE1 3NA:100090215480' } } );
            is $mech->uri->path, '/waste/PE1%203NA:100090215480', 'Redirected to waste base page';
            $mech->content_lacks('None booked');
        };

        subtest 'Cancellation' => sub {
            set_fixed_time($good_date);

            # Presence of external_id in report implies we have sent request
            # to Bartec
            $report->external_id(undef);
            $report->update;
            $mech->content_lacks( 'Cancel booking',
                'Cancel option unavailable before request sent to Bartec' );

            $report->external_id('Bartec-SR00100001');
            $report->update;
            $mech->get_ok('/waste/PE1%203NA:100090215480');
            $mech->content_contains( 'Cancel booking',
                'Cancel option available after request sent to Bartec' );

            $mech->log_in_ok( $user2->email );
            $mech->get_ok('/waste/PE1%203NA:100090215480');
            $mech->content_lacks(
                'Cancel booking',
                'Cancel option unavailable if booking does not belong to user',
            );

            $mech->log_in_ok( $staff->email );
            $mech->get_ok('/waste/PE1%203NA:100090215480');
            $mech->content_contains( 'Cancel booking',
                'Cancel option available to staff' );

            $mech->log_in_ok( $user->email );

            set_fixed_time($bad_date);
            $mech->get_ok('/waste/PE1%203NA:100090215480');
            $mech->content_lacks( 'Cancel booking',
                'Cancel option unavailable if outside cancellation window' );

            set_fixed_time($no_refund_date);
            $mech->get_ok('/waste/PE1%203NA:100090215480/bulky_cancel');
            $mech->content_lacks("If you cancel this booking you will receive a refund");
            $mech->content_contains("No Refund Will Be Issued");

            $report->update_extra_field({ name => 'CHARGEABLE', value => 'FREE'});
            $report->update;
            $mech->get_ok('/waste/PE1%203NA:100090215480/bulky_cancel');
            $mech->content_lacks("If you cancel this booking you will receive a refund");
            $mech->content_lacks("No Refund Will Be Issued");
            $report->update_extra_field({ name => 'CHARGEABLE', value => 'CHARGED'});
            $report->update;

            set_fixed_time($good_date);
            $mech->get_ok('/waste/PE1%203NA:100090215480/bulky_cancel');
            $mech->content_contains("If you cancel this booking you will receive a refund");
            $mech->submit_form_ok( { with_fields => { confirm => 1 } } );
            $mech->content_contains(
                'Your booking has been cancelled',
                'Cancellation confirmation page shown',
            );
            $mech->follow_link_ok( { text => 'Go back home' } );
            is $mech->uri->path, '/waste/PE1%203NA:100090215480',
                'Returned to bin days';
            $mech->content_lacks( 'Cancel booking',
                'Cancel option unavailable if already cancelled' );

            my $cancellation_report;
            subtest 'reports' => sub {
                $report->discard_changes;
                is $report->state, 'closed', 'Original report closed';
                like $report->detail, qr/Cancelled at user request/,
                    'Original report detail field updated';

                subtest 'cancellation report' => sub {
                    $cancellation_report
                        = FixMyStreet::DB->resultset('Problem')->find(
                        {   extra => {
                                like =>
                                    '%T18:ORIGINAL_SR_NUMBER,T5:value,T10:SR00100001%',
                            },
                        }
                        );
                    is $cancellation_report->category, 'Bulky cancel',
                        'Correct category';
                    is $cancellation_report->title,
                        'Bulky goods cancellation',
                        'Correct title';
                    is $cancellation_report->get_extra_field_value(
                        'COMMENTS'),
                        'Cancellation at user request',
                        'Correct extra comment field';
                    is $cancellation_report->state, 'confirmed',
                        'Report confirmed';
                    like $cancellation_report->detail,
                        qr/Original report ID: ${\$report->id}/,
                        'Original report ID in detail field';

                    # Cancellation of own booking
                    my $id = $cancellation_report->id;
                    my $path = "/report/$id";

                    $mech->log_in_ok($user->email);
                    $mech->get($path);
                    $mech->content_contains( 'Bulky goods cancellation',
                        'User can view cancellation report' );

                    # Superuser
                    $mech->log_in_ok($super->email);
                    $mech->get_ok($path);
                    $mech->content_contains( 'Bulky goods cancellation',
                        'Superuser can view cancellation report' );

                    # P'bro staff
                    $mech->log_in_ok($staff->email);
                    $mech->get_ok($path);
                    $mech->content_contains( 'Bulky goods cancellation',
                        'Peterborough staff can view cancellation report' );

                    # Other staff
                    $mech->log_in_ok($staff_bromley->email);
                    $mech->get($path);
                    is $mech->res->code, 403,
                        'Staff from other cobrands cannot view cancellation report';

                    # Logged out
                    $mech->log_out_ok;
                    $mech->get($path);
                    is $mech->res->code, 403,
                        'Logged out users cannot view cancellation report';

                    # Other user
                    $mech->log_in_ok($user2->email);
                    $mech->get($path);
                    is $mech->res->code, 403,
                        'Other logged-in user cannot view cancellation report';
                };
            };

            subtest 'Viewing original report summary after cancellation' => sub {
                my $id   = $report->id;
                my $path = "/report/$id";

                $mech->log_in_ok( $user->email );
                $mech->get_ok($path);
                $mech->content_contains('This collection has been cancelled');
                $mech->content_lacks('View cancellation report');
                $mech->content_lacks("You can cancel this booking till");
                $mech->content_lacks("23:55 on 25 August 2022");
                $mech->content_lacks('Cancel this booking');

                # Superuser
                $mech->log_in_ok( $super->email );
                $mech->get_ok($path);
                $mech->content_contains('This collection has been cancelled');
                $mech->content_contains('View cancellation report');
                $mech->content_lacks("You can cancel this booking till");
                $mech->content_lacks("23:55 on 25 August 2022");
                $mech->content_lacks('Cancel this booking');

                # P'bro staff
                $mech->log_in_ok( $staff->email );
                $mech->get_ok($path);
                $mech->content_contains('This collection has been cancelled');
                $mech->content_contains('View cancellation report');
                $mech->content_lacks("You can cancel this booking till");
                $mech->content_lacks("23:55 on 25 August 2022");
                $mech->content_lacks('Cancel this booking');
            };

            subtest 'refund request email' => sub {
                my $email = $mech->get_email;

                is $email->header('Subject'),
                    'Refund requested for cancelled bulky goods collection SR00100001',
                    'Correct subject';
                is $email->header('To'),
                    '"Peterborough City Council" <team@example.org>',
                    'Correct recipient';

                my $text = $email->as_string;
                like $text, qr/Capita SCP Response: 12345/,
                    'Correct SCP response';
                # XXX Not picking up on mocked time
                like $text, qr|Payment Date: \d{2}/\d{2}/\d{2} \d{2}:\d{2}|,
                    'Correct date format';
                like $text, qr/CAN: 123/, 'Correct CAN';
                like $text, qr/Auth Code: 112233/, 'Correct auth code';
                like $text, qr/Original Service Request Number: SR00100001/,
                    'Correct SR number';
            };

            $mech->clear_emails_ok;
            $cancellation_report->delete;
        };

        $report->delete; # So can have another one below
    };

    subtest 'Bulky collection, per item maximum message hidden if no maximums set' => sub {
        my $cfg = $body->get_extra_metadata('wasteworks_config');
        my $orig = $cfg->{item_list};
        $cfg->{item_list} = [
            {   bartec_id => '1001',
                category  => 'Audio / Visual Elec. equipment',
                message   => '',
                name      => 'Amplifiers',
                price     => '1001',
            },
            {   bartec_id => '1002',
                category  => 'Baby / Toddler',
                message   => '',
                name      => 'Childs bed / cot',
                price     => '4040',
            },
            {   bartec_id => '1002',
                category  => 'Baby / Toddler',
                message   => '',
                name      => 'High chairs',
                price     => '5050',
            },

            {   bartec_id => '1003',
                category  => 'Bedroom',
                message   => '',
                name      => 'Chest of drawers',
                price     => '6060',
            },
            {   bartec_id => '1003',
                category  => 'Bedroom',
                message   => 'Please dismantle',
                name      => 'Wardrobes',
                price     => '7070',
            },
        ];
        $body->set_extra_metadata(wasteworks_config => $cfg);
        $body->update;

        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->content_lacks("The following types of item have a maximum number that can be collected");

        $cfg->{item_list} = $orig;
        $body->set_extra_metadata(wasteworks_config => $cfg);
        $body->update;
    };

    subtest 'Bulky collection, per item maximum' => sub {
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->content_contains("The following types of item have a maximum number that can be collected");
        $mech->content_contains('HiFi Stereos: 2');
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'HiFi Stereos', 'item_2' => 'HiFi Stereos', item_3 => 'HiFi Stereos' } });
        $mech->content_contains('Too many of item: HiFi Stereos');
    };

    subtest 'Bulky collection, per item payment' => sub {
        $mech->log_in_ok($user->email);
        my $cfg = $body->get_extra_metadata('wasteworks_config');
        $cfg->{per_item_costs} = 1;
        $body->set_extra_metadata(wasteworks_config => $cfg);
        $body->update;

        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs' } });
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $report->get_extra_field_value('payment_method'), 'credit_card';
        is $report->get_extra_field_value('payment'), 1001 + 5050;
        is $report->get_extra_field_value('uprn'), 100090215480;
    };

    subtest 'Bulky collection, payment by staff' => sub {
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs' } });
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains("Confirm Booking");
        $mech->content_lacks("Confirm Subscription");
        $mech->submit_form_ok({ with_fields => { payenet_code => 123456 } });

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->detail, "Address: 1 Pope Way, Peterborough, PE1 3NA";
        is $report->category, 'Bulky collection';
        is $report->title, 'Bulky goods collection';
        is $report->get_extra_field_value('payment_method'), 'csc';
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->get_extra_field_value('DATE'), '2022-08-26T00:00:00';
        is $report->get_extra_field_value('CREW NOTES'), 'in the middle of the drive';
        $mech->log_out_ok;
        $report->delete;
    };

    subtest 'Bulky collection, free' => sub {
        my $cfg = $body->get_extra_metadata('wasteworks_config');
        $cfg->{free_mode} = 1;
        $cfg->{per_item_costs} = 0;
        $body->set_extra_metadata(wasteworks_config => $cfg);
        $body->update;

        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->content_contains('£0.00');
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs' } });
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        $mech->content_contains('Your booking is not complete yet');
        my $link = $mech->get_link_from_email;
        $mech->get_ok($link);
        $mech->content_contains('Collection booked');

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->detail, "Address: 1 Pope Way, Peterborough, PE1 3NA";
        is $report->category, 'Bulky collection';
        is $report->title, 'Bulky goods collection';
        is $report->get_extra_field_value('payment_method'), '';
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->get_extra_field_value('DATE'), '2022-08-26T00:00:00';
        is $report->get_extra_field_value('CREW NOTES'), 'in the middle of the drive';
        is $report->get_extra_field_value('CHARGEABLE'), 'FREE';

        subtest 'cancel free collection' => sub {
            # Time/date that is within the cancellation & refund window
            set_fixed_time('2022-08-25T05:44:59Z');  # 06:44:59 UK time

            # Presence of external_id in report implies we have sent request
            # to Bartec
            $report->external_id('Bartec-SR00100001');
            $report->update;

            $mech->get_ok('/waste/PE1%203NA:100090215480/bulky_cancel');
            $mech->submit_form_ok( { with_fields => { confirm => 1 } } );

            # No refund request sent
            $mech->email_count_is(0);

            $report->discard_changes;
            is $report->state, 'closed', 'Original report closed';

            my $cancellation_report
                = FixMyStreet::DB->resultset('Problem')->find(
                {   extra => {
                        like =>
                            '%T18:ORIGINAL_SR_NUMBER,T5:value,T10:SR00100001%',
                    },
                }
            );
            like $cancellation_report->detail,
                qr/Original report ID: ${\$report->id}/,
                'Original report ID in detail field';
        };

        $mech->log_out_ok;
        $report->delete;
    };

    subtest 'Bulky collection, free already used' => sub {
        # Main config still has free from above

        $b->mock('Premises_Attributes_Get', sub { [
            { AttributeDefinition => { Name => 'FREE BULKY USED' } },
        ] });

        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->content_contains('£23.50');
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs' } });
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $report->get_extra_field_value('payment_method'), 'credit_card';
        is $report->get_extra_field_value('payment'), 2350;
        is $report->get_extra_field_value('uprn'), 100090215480;

        $report->delete;
        $b->mock('Premises_Attributes_Get', sub { [] });
    };

};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'peterborough',
    COBRAND_FEATURES => {
        bartec => { peterborough => {
            sample_data => 1,
        } },
        waste => { peterborough => 1 },
        waste_features => { peterborough => {
            bulky_enabled => 'staff',
        } },
    },
}, sub {
    my ($b, $jobs_fsd_get) = shared_bartec_mocks();

    my $bin_days_url = 'http://localhost/waste/PE1%203NA:100090215480';

    subtest 'Logged-out users can’t see bulky goods when set to staff-only' => sub {
        $mech->log_out_ok;

        $mech->get_ok($bin_days_url);
        $mech->content_lacks('Bulky Waste');
    };

    subtest 'Logged-in users can’t see bulky goods when set to staff-only' => sub {
        $mech->log_in_ok($user->email);

        $mech->get_ok($bin_days_url);
        $mech->content_lacks('Bulky Waste');
    };

    subtest 'Logged-in staff can see bulky goods when set to staff-only' => sub {
        $mech->log_in_ok($staff->email);

        $mech->get_ok($bin_days_url);
        $mech->content_contains('Bulky Waste');
    };

    subtest 'Logged-in superusers can see bulky goods when set to staff-only' => sub {
        $mech->log_in_ok($super->email);

        $mech->get_ok($bin_days_url);
        $mech->content_contains('Bulky Waste');
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
                bulky_enabled => 1
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
                daily_slots => 50,
                free_mode => 0, # not checked
                base_price => 1234, per_item_costs => 1, items_per_collection_max => 7 };
        };
    };

    subtest 'WasteWorks bulky goods item list administration' => sub {
        ok $mech->host('peterborough.fixmystreet.com');
        my ($b, $jobs_fsd_get) = shared_bartec_mocks();

        subtest 'List admin page is linked from config page' => sub {
            $mech->log_in_ok($super->email);
            $mech->get_ok('/admin/waste/' . $body->id);
            $mech->follow_link_ok( { text_regex => qr/Bulky items list/i, }, "follow 'Bulky items list' link" );
            is $mech->uri->path, '/admin/waste/' . $body->id . '/bulky_items', 'ended up on correct page';
        };

        subtest 'Items can be stored correctly' => sub {
            $body->set_extra_metadata(wasteworks_config => {});
            $body->update;

            # check validation of required fields
            $mech->get_ok('/admin/waste/' . $body->id . '/bulky_items');
            $mech->submit_form_ok({ with_fields => {
                'bartec_id[9999]' => 1234,
                'category[9999]' => 'Furniture',
                'name[9999]' => '', # name is required
                'price[9999]' => '0',
                'message[9999]' => '',
            }});
            $mech->content_lacks("Updated!");
            $mech->content_contains("Please correct the errors below");

            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), {};

            # correctly store an item
            $mech->get_ok('/admin/waste/' . $body->id . '/bulky_items');
            $mech->submit_form_ok({ with_fields => {
                'bartec_id[9999]' => 1234,
                'category[9999]' => 'Furniture',
                'name[9999]' => 'Sofa',
                'price[9999]' => '0',
                'message[9999]' => 'test',
            }});
            $mech->content_contains("Updated!");

            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), {
                item_list => [ {
                    bartec_id => "1234",
                    category => "Furniture",
                    message => "test",
                    name => "Sofa",
                    max => "",
                    price => "0"
                }]
            };

            # and add a new one
            $mech->submit_form_ok({ with_fields => {
                'bartec_id[9999]' => 4567,
                'category[9999]' => 'Furniture',
                'name[9999]' => 'Armchair',
                'price[9999]' => '10',
                'message[9999]' => '',
            }});

            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), {
                item_list => [
                    {
                        bartec_id => "4567",
                        category => "Furniture",
                        message => "",
                        name => "Armchair",
                        max => "",
                        price => "10"
                    },
                    {
                        bartec_id => "1234",
                        category => "Furniture",
                        message => "test",
                        name => "Sofa",
                        max => "",
                        price => "0"
                    },
                ]
            };

            # delete the first item
            $mech->submit_form_ok({
                fields => {
                    "delete" => "0",
                },
                button => "delete",
            });

            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), {
                item_list => [
                    {
                        bartec_id => "1234",
                        category => "Furniture",
                        message => "test",
                        name => "Sofa",
                        max => "",
                        price => "0"
                    },
                ]
            };
        };

        subtest 'Bartec feature list is shown correctly' => sub {
            $body->set_extra_metadata(wasteworks_config => {});
            $body->update;

            $b->mock('Features_Types_Get', sub { [
                {
                    Name => "Bookcase",
                    ID => 6941,
                    FeatureClass => {
                        ID => 282
                    },
                },
                {
                    Name => "Dining table",
                    ID => 6917,
                    FeatureClass => {
                        ID => 282
                    },
                },
                {
                    Name => "Dishwasher",
                    ID => 6990,
                    FeatureClass => {
                        ID => 283
                    },
                },
            ] });


            $mech->get_ok('/admin/waste/' . $body->id . '/bulky_items');
            $mech->content_contains('<option value="6941">Bookcase</option>') or diag $mech->content;
            $mech->content_contains('<option value="6917">Dining table</option>');
            $mech->content_contains('<option value="6990">Dishwasher</option>');
            $mech->submit_form_ok({ with_fields => {
                'bartec_id[9999]' => 6941,
                'category[9999]' => 'Furniture',
                'name[9999]' => 'Bookcase',
                'price[9999]' => '0',
                'max[9999]' => '',
                'message[9999]' => '',
            }});
            $mech->content_contains("Updated!");

            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), {
                item_list => [ {
                    bartec_id => "6941",
                    category => "Furniture",
                    message => "",
                    name => "Bookcase",
                    max => "",
                    price => "0"
                }]
            };
        };

        subtest 'Feature classes can set in config to limit feature types' => sub {
            $body->set_extra_metadata(wasteworks_config => { bulky_feature_classes => [ 282 ] });
            $body->update;

            $mech->get_ok('/admin/waste/' . $body->id . '/bulky_items');
            $mech->content_contains('<option value="6941">Bookcase</option>') or diag $mech->content;
            $mech->content_contains('<option value="6917">Dining table</option>');
            $mech->content_lacks('<option value="6990">Dishwasher</option>');
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
    $b->mock('Jobs_FeatureScheduleDates_Get', sub { $jobs_fsd_get });
    $b->mock('Features_Schedules_Get', sub { [
        { JobName => 'Empty Bin 240L Black', Feature => { Status => { Name => "IN SERVICE" }, FeatureType => { ID => 6533 } }, Frequency => 'Every two weeks' },
        { JobName => 'Empty Bin Recycling 240l', Feature => { Status => { Name => "IN SERVICE" }, FeatureType => { ID => 6534 } } },
        { JobName => 'Empty Clinical Waste', Feature => { Status => { Name => "IN SERVICE" }, FeatureType => { ID => 6815 } } },
        { JobName => 'Empty Brown Bin', Feature => { Status => { Name => "PLANNED" }, FeatureType => { ID => 6579 } } },
    ] });
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
    $b->mock( 'Premises_FutureWorkpacks_Get', &_future_workpacks );
    $b->mock( 'WorkPacks_Get',                [] );
    $b->mock( 'Jobs_Get_for_workpack',        [] );
    $b->mock('Features_Types_Get', sub { [
        # No feature types at present
    ] });

    return $b, $jobs_fsd_get;
}

sub _future_workpacks {
    [   {   'WorkPackDate' => '2022-08-05T00:00:00',
            'Actions'      => {
                'Action' => [ { 'ActionName' => 'Empty Bin 240L Black' } ],
            },
        },
        {   'WorkPackDate' => '2022-08-12T00:00:00',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Black 240l Bin' } },
        },
        {   'WorkPackDate' => '2022-08-19T00:00:00',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
        {   'WorkPackDate' => '2022-08-26T00:00:00',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
        {   'WorkPackDate' => '2022-09-02T00:00:00',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
    ];
}

sub get_report_from_redirect {
    my $url = shift;

    my ($report_id, $token) = ( $url =~ m#/(\d+)/([^/]+)$# );
    my $new_report = FixMyStreet::DB->resultset('Problem')->find( {
            id => $report_id,
    });

    return undef unless $new_report->get_extra_metadata('redirect_id') eq $token;
    return ($token, $new_report, $report_id);
}


done_testing;
