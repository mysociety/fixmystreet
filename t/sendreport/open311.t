use CGI::Simple;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok( 'eh@example.com' );
my $body = $mech->create_body_ok( 2342, 'East Hertfordshire Council');
my $contact = $mech->create_contact_ok( body_id => $body->id, category => 'Potholes', email => 'POT' );
$contact->set_extra_fields(
    { code => 'easting', datatype => 'number' },
    { code => 'northing', datatype => 'number' },
    { code => 'fixmystreet_id', datatype => 'number' },
);
$contact->update;

my ($report) = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    cobrand => 'fixmystreet',
    category => 'Potholes',
    user => $user,
});

subtest 'testing Open311 behaviour', sub {
    $body->update( { send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test' } );
    my $test_data;
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
    }, sub {
        $test_data = FixMyStreet::DB->resultset('Problem')->send_reports();
    };
    $report->discard_changes;
    ok $report->whensent, 'Report marked as sent';
    is $report->send_method_used, 'Open311', 'Report sent via Open311';
    is $report->external_id, 248, 'Report has right external ID';

    my $req = $test_data->{test_req_used};
    my $c = CGI::Simple->new($req->content);
    is $c->param('attribute[easting]'), 529025, 'Request had easting';
    is $c->param('attribute[northing]'), 179716, 'Request had northing';
    is $c->param('attribute[fixmystreet_id]'), $report->id, 'Request had correct ID';
    is $c->param('jurisdiction_id'), 'FMS', 'Request had correct jurisdiction';
};

done_testing();
