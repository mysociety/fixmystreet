use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use Web::Scraper;
use Path::Class;
use DateTime;
use URI::Escape;

my $mech = FixMyStreet::TestMech->new;

# create a test user and report
$mech->delete_user('commenter@example.com');
$mech->delete_user('test@example.com');

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $user2 = $mech->create_user_ok('commenter@example.com', name => 'Commenter');

my $body = $mech->create_body_ok(2504, 'Westminster City Council');

my ($report) = $mech->create_problems_for_body(1, $body->id, 'Test');
my $report_id = $report->id;

$mech->log_in_ok( $user2->email );
$mech->get_ok("/report/$report_id");

my ($csrf) = $mech->content =~ /name="token" value="([^"]*)"/;

# Create a +1 for a report when logged in

$mech->add_header(Accept => 'application/json');
my $json = $mech->get_ok_json("/report/update/plus_one?id=$report_id&token=$csrf");

is $json->{url}, "/report/$report_id?plus_one=1", 'Correct JSON is returned';

my @updates = FixMyStreet::App->model('DB::Comment')->search(
    { problem_id => $report->id }
);

my @alerts = FixMyStreet::App->model('DB::Alert')->search(
    { user_id => $user2->id }
);

is scalar(@updates), 1, 'Update is added';
is @updates[0]->text, 'User has added +1 to this report', 'Update has correct title';
is @updates[0]->name, $user2->name, 'Update has correct username';
is @updates[0]->anonymous, 1, 'Update is anonymous';
is @updates[0]->state, 'hidden', 'Update is hidden';

is scalar(@alerts), 1, 'User is subscribed to updates';
is @alerts[0]->alert_type->ref, 'new_updates', 'alert update type is correct';
is @alerts[0]->parameter, $report_id, 'alert update has the correct report id';

$mech->log_out_ok;

my $json = $mech->get_ok_json("/report/update/plus_one?id=$report_id&token=$csrf");
my $url = '\/report\/update\/plus_one';
my $params = uri_escape_utf8("id=$report_id&token=$csrf");

like $json->{url}, qr/\/auth\?plus_one=1&r=$url&p=id%3D1%26token%3D.*/, 'Correct URL is returned for logged out user';

$mech->delete_user('commenter@example.com');
$mech->delete_user('test@example.com');
done_testing();
