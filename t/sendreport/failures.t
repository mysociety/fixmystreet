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
my $tfl = FixMyStreet::DB->resultset('Body')->find_or_create({ id => 1001, name => 'TfL', cobrand => 'tfl' });
my $bromley = FixMyStreet::DB->resultset('Body')->find_or_create({ id => 1002, name => 'Bromley Council', cobrand => 'bromley' });
ok $body, "found/created body";

my $contact = $mech->create_contact_ok(
    email => 'council@example.com',
    body_id => 1000,
    category => 'category',
    note => '',
);

my $tfl_contact = $mech->create_contact_ok(
    email => 'tfl@example.com',
    body_id => $tfl->id,
    category => 'category',
    note => '',
);

my $bromley_contact = $mech->create_contact_ok(
    email => 'bromley@example.com',
    body_id => $bromley->id,
    category => 'category',
    note => '',
);
$bromley_contact->set_extra_metadata('type' => 'waste');
$bromley_contact->update;

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

my ($p_tfl) = $mech->create_problems_for_body(1, $tfl->id, 'Test', {
    cobrand => 'tfl',
    user => $user,
    bodies_str => $tfl->id,
    category => 'category',
    send_fail_timestamp => \'current_timestamp',
    send_fail_reason => 'this is a test failure',
    send_fail_count => 1
} );

my ($p_bromley) = $mech->create_problems_for_body(1, $bromley->id, 'Test', {
    cobrand => 'bromley',
    cobrand_data => 'waste',
    user => $user,
    bodies_str => $bromley->id,
    category => 'category',
    send_fail_timestamp => \'current_timestamp',
    send_fail_reason => 'this is a test failure',
    send_fail_count => 1
} );


FixMyStreet::override_config {
    COBRAND_FEATURES => { base_url => { 'tfl' => 'http://tfl.example.org', 'bromley' => 'http://bromley.example.org' } },
    BASE_URL => 'http://www.example.org',
    ALLOWED_COBRANDS => [ 'tfl', 'bromley', 'fixmystreet' ],
}, sub {
    subtest "check sendreport failure messages" => sub {
        my $e = FixMyStreet::Script::Reports->new;
        my $base = FixMyStreet->config('BASE_URL');
        my ($id1, $id2, $id3, $id4) = ( $p1->id, $p2->id, $p_bromley->id, $p_tfl->id );
        stdout_like { $e->end_summary_failures } qr%The following 4 reports had problems sending:\nBromley Council \(1\): http://bromley.example.org/admin/report_edit/$id3\nCouncil of the Thousand \(2\): http://www.example.org/admin/report_edit/$id2, http://www.example.org/admin/report_edit/$id1\nTfL \(1\): http://tfl.example.org/admin/report_edit/$id4.*report/$id2.*report/$id4.*report/$id3.*report/$id1%s, "includes count of reports and reports in fixed order"
    }
};

done_testing();
