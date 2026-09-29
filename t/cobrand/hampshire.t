use FixMyStreet::TestMech;
use FixMyStreet::Cobrand::Hampshire;
use Open311::PostServiceRequestUpdates;

my $mech = FixMyStreet::TestMech->new;

my $hampshire = $mech->create_body_ok(2227, 'Hampshire County Council', {
        cobrand => 'hampshire',
        send_method => 'Open311',
        endpoint => 'endpoint',
        api_key => 'key',
        jurisdiction => 'hampshire',
        send_comments => 1,
 });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet' ],
    BASE_URL => 'http://www.fixmystreet.com',
}, sub {
    my $hampshire = FixMyStreet::Cobrand::Hampshire->new;
    is $hampshire->base_url, 'http://www.fixmystreet.com', "Hampshire returns fixmystreet base_url";
    };

my $user = $mech->create_user_ok('user@example.com', name => 'Bobby Blue');
my $contact = $mech->create_contact_ok( body_id => $hampshire->id, category => 'Tree branch', email => 'TREE' );

my ($p) = $mech->create_problems_for_body( 1, $hampshire->id, 'Test updates', {
    cobrand => 'hampshire',
    category => 'Tree branch',
    user => $user,
    latitude => 51.754926,
    longitude => -1.256179,
});
$p->update({ external_id => '123456', send_method_used => 'Open311', whensent => '2026-09-18T10:00:00' });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'hampshire' ],
    BASE_URL => 'http://www.fixmystreet.com',
}, sub {
    $mech->log_in_ok($user->email);
    $mech->get_ok( '/report/' . $p->id );
    $mech->submit_form_ok( { with_fields => { update => 'Any update on this?' } });

    my $updates = Open311::PostServiceRequestUpdates->new;
    $updates->send;
    my $req = Open311->test_req_used;
    ok $req->content =~ m/Any\+update/, 'Comment sent';
    ok $req->content !~ m/marked\+as\+fixed/, 'No additional text added to comment';

    $mech->get_ok( '/report/' . $p->id );
    $mech->submit_form_ok( { with_fields => { fixed => 1, update => 'Thanks' } });
    $updates->send;
    $req = Open311->test_req_used;
    ok $req->content =~ m/description=Thanks%0A%0AReport\+marked\+as\+fixed\+by\+an\+FMS\+user/, 'Additonal text added to comment';

    $mech->get_ok( '/report/' . $p->id );
    unlike $mech->content, qr/marked as fixed/, 'Update not saved to FMS';
};

done_testing();
