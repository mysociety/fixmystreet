use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use Web::Scraper;
use Path::Class;

my $mech = FixMyStreet::TestMech->new;

# create a test user and report
$mech->delete_user('test@example.com');
my $user =
  FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'test@example.com', name => 'Test User' } );
ok $user, "created test user";

my $report = FixMyStreet::App->model('DB::Problem')->find_or_create(
    {
        postcode           => 'SW1A 1AA',
        council            => '2504',
        areas              => ',105255,11806,11828,2247,2504,',
        category           => 'Other',
        title              => 'Test 2',
        detail             => 'Test 2',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
        state              => 'confirmed',
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.5016605453401',
        longitude          => '-0.142497580865087',
        user_id            => $user->id,
    }
);
my $report_id = $report->id;
ok $report, "created test report - $report_id";

subtest "check that no id redirects to homepage" => sub {
    $mech->get_ok('/report');
    is $mech->uri->path, '/', "at home page";
};

subtest "test id=NNN redirects to /NNN" => sub {
    $mech->get_ok("/report?id=$report_id");
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
};

subtest "test bad council email clients web links" => sub {
    $mech->get_ok("/report/3D$report_id");
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
};

subtest "test bad ids get dealt with (404)" => sub {
    foreach my $id ( 'XXX', 99999999 ) {
        ok $mech->get("/report/$id"), "get '/report/$id'";
        is $mech->res->code, 404,           "page not found";
        is $mech->uri->path, "/report/$id", "at /report/$id";
    }
};

subtest "test a good report" => sub {
    $mech->get_ok("/report/$report_id");
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
};

fail "change report to hidden and check for 400 status";

# tidy up
$mech->delete_user('test@example.com');
done_testing();
