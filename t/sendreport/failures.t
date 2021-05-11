use FixMyStreet;
use FixMyStreet::DB;
use FixMyStreet::Script::Reports;
use FixMyStreet::TestMech;

use Test::Output;
use DateTime;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

# area id 1000
my $params = { id => 1000, name => 'Council of the Thousand' };
my $body = FixMyStreet::DB->resultset('Body')->find_or_create($params);
ok $body, "found/created body";

my $contact = $mech->create_contact_ok(
    email => 'council@example.com',
    body_id => 1000,
    category => 'category',
    note => '',
);

my $user = $mech->create_user_ok( 'test@example.com' );

my ($p1, $p2) = $mech->create_problems_for_body(2, $body->id, 'Test', {
    user => $user,
    bodies_str => '1000',
    category => 'category',
    send_fail_timestamp => \'current_timestamp',
    send_fail_reason => 'this is a test failure',
    send_fail_count => 1
} );

$p1->update({
    confirmed => $p1->confirmed->add( minutes => -5 ),
});

subtest "check sendreport failure messages" => sub {
    my $e = FixMyStreet::Script::Reports->new;
    my ($id1, $id2) = ( $p1->id, $p2->id );
    stdout_like { $e->end_summary_failures } qr%The following 2 reports had problems sending:\nCouncil of the Thousand \(2\): $id2, $id1.*report/$id2.*report/$id1%s, "includes count of reports and reports in fixed order"

};

done_testing();
