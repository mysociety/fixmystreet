use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use CGI::Simple;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2224, 'East Sussex Council',
    { send_method => 'Open311', api_key => 'KEY', endpoint => 'endpoint', jurisdiction => 'eastsussex' });
my $contact = $mech->create_contact_ok(body => $body, category => 'Pothole', email => 'POTHOLE');
$contact->set_extra_fields(
    { code => 'urgent', description => 'Is it urgent?', variable => 'true' },
    { code => 'notice', description => 'This is a notice', variable => 'false' });
$contact->update;
my ($p) = $mech->create_problems_for_body(1, $body->id, 'East Sussex report', { category => 'Pothole' });
$p->set_extra_fields({ name => 'urgent', value => 'no'});
$p->update;

subtest 'Check special Open311 request handling', sub {
    my $orig_detail = $p->detail;
    my $test_data;
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => 'eastsussex',
        BASE_URL => 'https://www.fixmystreet.com',
    }, sub {
        $test_data = FixMyStreet::Script::Reports::send();
    };

    $p->discard_changes;
    ok $p->whensent, 'Report marked as sent';
    is $p->send_method_used, 'Open311', 'Report sent via Open311';
    is $p->external_id, 248, 'Report has right external ID';
    is $p->detail, $orig_detail, 'Detail in database not changed';

    my $req = $test_data->{test_req_used};
    my $c = CGI::Simple->new($req->content);
    my $expected = join "\r\n", $p->title, '', $p->detail, '',
        'Is it urgent?', 'no', '', "https://www.fixmystreet.com" . $p->url, '';
    is $c->param('description'), $expected, 'Correct description, with extra question and no notice text';
};

done_testing;
