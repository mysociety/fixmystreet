use FixMyStreet::TestMech;
use Test::Output;

use_ok 'FixMyStreet::Script::ProcessUpdateFile';
my $mech = FixMyStreet::TestMech->new;


my $body = $mech->create_body_ok(2651, 'City of Edinburgh Council');

my $contact1 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Street lighting',
    email => 'highways@example.com',
);

my $body_user = $mech->create_user_ok('bodyuser@example.org', from_body => $body);
$body->comment_user_id( $body_user->id);
$body->update;

my $response_template = $body->response_templates->create({
    title => "investigating template",
    text => "We are investigating this report.",
    auto_response => 1,
    state => "investigating"
});

my ($problem1) = $mech->create_problems_for_body(1, $body->id, 'Problem 1', { external_id => '123456' });
my ($problem2) = $mech->create_problems_for_body(1, $body->id, 'Problem 2', { external_id => '123457' });
my ($problem3) = $mech->create_problems_for_body(1, $body->id, 'Problem 3', { external_id => '123458' });
my ($problem4) = $mech->create_problems_for_body(1, $body->id, 'Problem 4', { external_id => '123459' });

my $c = $mech->create_comment_for_problem($problem1, $problem1->user, 'comment', 'text', 'f', 'confirmed', 'investigating');
$c->external_id('654321');
$c->update;

my $alert = FixMyStreet::DB->resultset('Alert')->find_or_create(
    {
        user => $problem2->user,
        parameter => $problem2->id,
        alert_type => 'new_updates',
        whensubscribed => '2015-12-01 07:00:00',
        confirmed => 1,
        cobrand => 'default',
    }
);

my $data = [
    {
        update_id => '654321',
        service_request_id => '123456',
        status => 'investigating',
        description => '',
        updated_datetime => '2021-04-21T15:59:01',
    },
    {
        update_id => '654321',
        service_request_id => '123457',
        status => 'investigating',
        description => '',
        updated_datetime => '2021-04-21T15:59:01',
    },
    {
        update_id => '654322',
        service_request_id => '123458',
        status => 'in_progress',
        description => '',
        updated_datetime => '2021-04-21T15:59:01',
    },
];

my $p = FixMyStreet::Script::ProcessUpdateFile->new(
    body_name => 'City of Edinburgh Council',
    data => $data,
    commit => 1,
    suppress_alerts => 1,
);

output_like { $p->process } qr/added 2 comments/, qr/determine update text/;

is $problem1->comments->count, 1, "problem 1 has same comment";
$problem1->discard_changes;
is $problem1->state, 'confirmed', 'problem status not changed';

is $problem2->comments->count, 1, "problem 2 has a comment";
my $u = $problem2->comments->first;
is $u->external_id, '654321', 'comment external id correct';
is $u->text, 'We are investigating this report.', 'comment text uses response template';
my $alerts_sent = FixMyStreet::DB->resultset('AlertSent')->search(
    {
        alert_id => $alert->id,
        parameter => $u->id,
    }
);
is $alerts_sent->count(), 1, 'alerts suppressed';

$problem2->discard_changes;
is $problem2->state, 'investigating', 'problem status updated correctly';

is $problem3->comments->count, 1, "problem 3 has a comment";
$u = $problem3->comments->first;
is $u->external_id, '654322', 'comment external id correct';
is $u->text, '', 'comment text is blank';

$problem3->discard_changes;
is $problem3->state, 'in progress', 'problem status updated correctly';

is $problem4->comments->count, 0, "problem 4 has no comments";


done_testing;
