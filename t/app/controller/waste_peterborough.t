use utf8;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use CGI::Simple;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });

my $mech = FixMyStreet::TestMech->new;

my $params = {
    send_method => 'Open311',
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
};
my $body = $mech->create_body_ok(2566, 'Peterborough Council', $params);
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');
my $staff = $mech->create_user_ok('staff@example.net', name => 'Staff User', from_body => $body->id);

sub create_contact {
    my ($params, $group, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => [$group]);
    $contact->set_extra_metadata( waste_only => 1 );
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
create_contact({ category => 'All bins', email => 'Bartec-425' }, 'Request new container');
create_contact({ category => 'Both food bins', email => 'Bartec-493' }, 'Request new container');
create_contact({ category => '240L Black - Lid', email => 'Bartec-538' }, 'Bin repairs');
create_contact({ category => '240L Black - Wheels', email => 'Bartec-541' }, 'Bin repairs', { code => 'extra_detail', required => 0, datatype => 'text'  });
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
    my $b = Test::MockModule->new('Integrations::Bartec');
    $b->mock('Authenticate', sub {
        { Token => { TokenString => "TOKEN" } }
    });
    $b->mock('Jobs_Get', sub { [
        { WorkPack => { Name => 'Waste-R1-010821' }, Name => 'Empty Bin 240L Black', ScheduledDate => '2021-08-01T07:00:00' },
        { WorkPack => { Name => 'Waste-R1-050821' }, Name => 'Empty Bin Recycling 240l', ScheduledDate => '2021-08-05T07:00:00' },
    ] });
    my $jobs_fsd_get = [
        { JobID => 123, PreviousDate => '2021-08-01T11:11:11Z', NextDate => '2021-08-08T11:11:11Z', JobName => 'Empty Bin 240L Black' },
        { JobID => 456, PreviousDate => '2021-08-05T10:10:10Z', NextDate => '2021-08-19T10:10:10Z', JobName => 'Empty Bin Recycling 240l' },
    ];
    $b->mock('Jobs_FeatureScheduleDates_Get', sub { $jobs_fsd_get });
    $b->mock('Features_Schedules_Get', sub { [
        { JobName => 'Empty Bin 240L Black', Feature => { FeatureType => { ID => 6533 } }, Frequency => 'Every two weeks' },
        { JobName => 'Empty Bin Recycling 240l', Feature => { FeatureType => { ID => 6534 } } },
    ] });
    $b->mock('ServiceRequests_Get', sub { [
        # No open requests at present
    ] });
    $b->mock('Premises_Attributes_Get', sub { [] });
    $b->mock('Premises_Events_Get', sub { [
        # No open events at present
    ] });
    $b->mock('Streets_Events_Get', sub { [
        # No open events at present
    ] });
    subtest 'Missing address lookup' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'PE1 3NA' } });
        $mech->submit_form_ok({ with_fields => { address => 'missing' } });
        $mech->content_contains('can’t find your address', "Missing message found");
    };
    subtest 'Address lookup' => sub {
        set_fixed_time('2021-08-06T10:00:00Z');
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'PE1 3NA' } });
        $mech->content_contains('1 Pope Way, Peterborough, PE1 3NA');
        $mech->submit_form_ok({ with_fields => { address => 'PE1 3NA:100090215480' } });
        $mech->content_contains('1 Pope Way, Peterborough');
        $mech->content_contains('Every two weeks');
        $mech->content_contains('Thursday, 5th August 2021');
        $mech->content_contains('Report a recycling collection as missed');
        set_fixed_time('2021-08-09T10:00:00Z');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('Report a recycling collection as missed');
        set_fixed_time('2021-08-09T14:00:00Z');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks('Report a recycling collection as missed');
    };
    subtest 'Check lock out conditions' => sub {
        set_fixed_time('2021-08-05T14:00:00Z');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('to report a missed recycling please call');

        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('Please call through to Aragon');
        $mech->log_out_ok();

        set_fixed_time('2021-08-06T10:00:00Z');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks('to report a missed recycling please call');

        $b->mock('Premises_Events_Get', sub { [
            { Features => { FeatureType => { ID => 6534 } }, EventType => { Description => 'BIN NOT OUT' }, EventDate => '2021-08-05T10:10:10' },
        ] });
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('There was a problem with your bin collection, please call');
        $mech->content_lacks('BIN NOT OUT');

        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('BIN NOT OUT');
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
    subtest 'Future collection calendar' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480/calendar.ics');
        $mech->content_contains('DTSTART;VALUE=DATE:20210808');
        $mech->content_contains('DTSTART;VALUE=DATE:20210819');
    };
    subtest 'No reporting/requesting if open request' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains('Report a recycling collection as missed');
        $mech->content_contains('Request a new recycling container');
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 420 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains('A new recycling container request has been made');
        $mech->content_contains('Report a recycling collection as missed');
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 488 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains('A recycling collection has been reported as missed');
        $mech->content_contains('Request a new recycling container');
        $b->mock('ServiceRequests_Get', sub { [
            { ServiceType => { ID => 492 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->content_contains('A recycling collection has been reported as missed');
        $b->mock('ServiceRequests_Get', sub { [ ] }); # reset
    };
    subtest 'Request a new container' => sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/PE1 3NA:100090215480/request');
        $mech->submit_form_ok({ with_fields => { 'container-425' => 1, 'reason-425' => 'Reason' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Request sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->detail, "Quantity: 1\n\n1 Pope Way, Peterborough, PE1 3NA\n\nReason: Reason";
        is $report->title, 'Request new All bins';
    };
    subtest 'Request food containers' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480/request');
        $mech->submit_form_ok({ with_fields => { 'container-424' => 1, 'container-423' => 1 }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Request sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->detail, "Quantity: 1\n\n1 Pope Way, Peterborough, PE1 3NA";
        is $report->title, 'Request new Both food bins';
    };
    subtest 'Request/report food containers from front page' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->submit_form_ok({ with_fields => { 'container-428' => 1 } });
        $mech->content_contains('name="container-428" value="1"');
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->submit_form_ok({ with_fields => { 'service-FOOD_BINS' => 1 } });
        $mech->content_contains('name="service-FOOD_BINS" value="1"');
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
        is $report->title, 'Report missed 240L Green';
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
        is $report->title, 'Report missed 240L Green';
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
            { ServiceType => { ID => 538 }, ServiceStatus => { Status => "OPEN" } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->follow_link_ok({ text => 'Report a problem with a black bin' });
        $mech->content_like(qr/name="category" value="240L Black - Lid"\s+disabled/);
        $b->mock('ServiceRequests_Get', sub { [] }); # reset
    };
    subtest 'Report broken bin' => sub {
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->follow_link_ok({ text => 'Report a problem with a black bin' });
        $mech->submit_form_ok({ with_fields => { category => '240L Black - Lid' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->content_contains('The bin’s lid is damaged', "Damaged lid category found");
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Enquiry submitted');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->title, '240L Black';
        is $report->detail, "The bin’s lid is damaged\n\n1 Pope Way, Peterborough, PE1 3NA";
    };
    subtest 'Report broken wheels' => sub {
        FixMyStreet::DB->resultset('Problem')->search(
            {
                whensent => undef
            }
        )->update( { whensent => \'current_timestamp' } );

        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->follow_link_ok({ text => 'Report a problem with a black bin' });
        $mech->submit_form_ok({ with_fields => { category => '240L Black - Wheels' } });
        $mech->content_contains('name="extra_extra_detail" rows="5" maxlength="1000"');
        $mech->submit_form_ok({ with_fields => { extra_extra_detail => 'Some extra detail' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->content_contains('The bin’s wheels are damaged', "Damaged wheel category found");
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Enquiry submitted');

        FixMyStreet::Script::Reports::send();

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        ok $report->whensent, 'Report marked as sent';
        is $report->title, '240L Black';
        is $report->detail, "The bin’s wheels are damaged\n\n1 Pope Way, Peterborough, PE1 3NA\n\nExtra detail: Some extra detail";

        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[title]'), $report->title, 'title param sent';
        is $cgi->param('attribute[extra_detail]'), undef, 'extra_detail param not sent';
    };
    subtest 'Report broken large bin' => sub {
        $b->mock('Premises_Attributes_Get', sub { [
            { AttributeDefinition => { Name => 'LARGE BIN' } },
        ] });
        $mech->get_ok('/waste/PE1 3NA:100090215480');
        $mech->follow_link_ok({ text => 'Report a problem with a black bin' });
        $mech->submit_form_ok({ with_fields => { category => '240L Black - Lid' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => 'email@example.org' }});
        $mech->content_contains('Black Bin');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Enquiry submitted');
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
        is $report->title, 'Report missed 360L Black';
        $b->mock('Premises_Attributes_Get', sub { [] });
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
    };
};

done_testing;
