use FixMyStreet::TestMech;
use Test::Output;
use Test::Exception;
use Path::Tiny;
use LWP::Protocol::PSGI;

use_ok 'FixMyStreet::Script::ProcessReportFile';

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

my $body = $mech->create_body_ok(2651, 'Test Council');

my $contact1 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Pothole',
    email => 'highways@example.com',
);

my $contact2 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Street lighting',
    email => 'lighting@example.com',
);

my $body_user = $mech->create_user_ok('bodyuser@example.org', name => 'Body User', from_body => $body);
$body->comment_user_id($body_user->id);
$body->endpoint('http://example.com/open311');
$body->api_key('test_key');
$body->jurisdiction('test_jurisdiction');
$body->update;

subtest 'body lookup' => sub {
    my $processor = FixMyStreet::Script::ProcessReportFile->new(
        body_name => 'Test Council',
        file => 't/script/process_report_file_valid_data.json',
    );

    isa_ok $processor->body, 'FixMyStreet::DB::Result::Body';
    is $processor->body->name, 'Test Council', 'correct body found';

    my $bad_processor = FixMyStreet::Script::ProcessReportFile->new(
        body_name => 'Nonexistent Council',
        file => 't/script/process_report_file_valid_data.json',
    );

    is $bad_processor->body, undef, 'nonexistent body returns undef';
};

subtest 'data loading' => sub {
    my $processor = FixMyStreet::Script::ProcessReportFile->new(
        body_name => 'Test Council',
        file => 't/script/process_report_file_valid_data.json',
    );

    my $data = $processor->data;
    isa_ok $data, 'ARRAY';
    is scalar(@$data), 2, 'correct number of records loaded';
    is $data->[0]->{service_request_id}, 'DEFECT_201582', 'first record loaded correctly';
    is $data->[1]->{service_request_id}, 'DEFECT_201590', 'second record loaded correctly';
};

subtest 'data loading - empty file' => sub {
    my $processor = FixMyStreet::Script::ProcessReportFile->new(
        body_name => 'Test Council',
        file => 't/script/process_report_file_empty_data.json',
    );

    my $data = $processor->data;
    isa_ok $data, 'ARRAY';
    is scalar(@$data), 0, 'empty array for empty file';
};

subtest 'data loading - nonexistent file' => sub {
    my $processor = FixMyStreet::Script::ProcessReportFile->new(
        body_name => 'Test Council',
        file => 't/script/process_report_file_nonexistent.json',
    );

    throws_ok { $processor->data } qr/No such file/, 'nonexistent file throws error';
};

subtest 'process method - invalid body' => sub {
    my $processor = FixMyStreet::Script::ProcessReportFile->new(
        body_name => 'Nonexistent Council',
        file => 't/script/process_report_file_valid_data.json',
    );

    throws_ok { $processor->process } qr/Problem loading body/, 'dies with invalid body';
};

subtest 'process method - dry run' => sub {
    my $processor = FixMyStreet::Script::ProcessReportFile->new(
        body_name => 'Test Council',
        file => 't/script/process_report_file_valid_data.json',
        commit => 0,
    );

    my $initial_count = FixMyStreet::DB->resultset('Problem')->count;

    stdout_like { $processor->process } qr/Dry run, not adding reports/, 'shows dry run message';

    my $final_count = FixMyStreet::DB->resultset('Problem')->count;
    is $final_count, $initial_count, 'problems were not created';

};

subtest 'process method - with commit and actual data' => sub {
    my $processor = FixMyStreet::Script::ProcessReportFile->new(
        body_name => 'Test Council',
        file => 't/script/process_report_file_valid_data.json',
        commit => 1,
        verbose => 1,
    );

    my $initial_count = FixMyStreet::DB->resultset('Problem')->count;

    lives_ok { $processor->process } 'process runs without error with commit';

    my $final_count = FixMyStreet::DB->resultset('Problem')->count;
    is $final_count, $initial_count + 2, 'two problems were created';

    my @new_reports = FixMyStreet::DB->resultset('Problem')->search(
        {},
        { order_by => { -desc => 'id' }, rows => 2 }
    )->all;

    is $new_reports[0]->external_id, 'DEFECT_201590', 'second report has correct external_id';
    is $new_reports[0]->detail, "Defect type: Pothole\nDepth: 40mm - 100mm\nWidth: 200mm - 400mm\nDistance from edge: 150mm or over\nNumber of potholes: 1", 'second report has correct detail';

    is $new_reports[1]->external_id, 'DEFECT_201582', 'first report has correct external_id';
    is $new_reports[1]->detail, 'Defect type: Overhanging Trees & Vegetation', 'first report has correct detail';
};

};

done_testing;