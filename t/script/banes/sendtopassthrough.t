use FixMyStreet::TestMech;
use DateTime;
use Test::Output;
use Test::MockModule;
use CGI::Simple;

use_ok 'FixMyStreet::Script::BANES::PassthroughConfirm';

my $bathnes = Test::MockModule->new('FixMyStreet::Cobrand::BathNES');
$bathnes->mock('lookup_site_code', sub { '102345' } );

my $mech = FixMyStreet::TestMech->new;
my $area_id = 2551;
my $body = $mech->create_body_ok($area_id, 'Bath and North East Somerset Council', {
    endpoint => '',
    api_key => 'key',
    jurisdiction => 'BANES',
    send_method => 'open311',
    cobrand => 'bathnes',
});

my $email_category = $mech->create_contact_ok(category => 'Potholes', body_id => $body->id, email => 'potholes@example.com');
my $confirm_category = $mech->create_contact_ok(category => 'Graffiti', body_id => $body->id, email => 'confirm_graffiti');

FixMyStreet::override_config {
          ALLOWED_COBRANDS => [ 'bathnes' ],
          MAPIT_URL => 'http://mapit.uk/',
}, sub {
    my ($pothole_report) = $mech->create_problems_for_body( 1, $body->id, 'Potholes in the road', { category => $email_category->category, cobrand => 'bathnes', external_id => 'pass1' });
    my ($graffiti_report) = $mech->create_problems_for_body( 1, $body->id, 'Graffiti on the wall', { category => $confirm_category->category, cobrand => 'bathnes', external_id => 'ext1' });

    my $script = FixMyStreet::Script::BANES::PassthroughConfirm->new();
    $script->send_reports;
    $graffiti_report->discard_changes;

    my $req = Open311->test_req_used;
    my $c = CGI::Simple->new($req->content);
    is $c->{service_code}[0] eq 'passthrough-confirm_graffiti@example.org', 1, "service_code given email address to send to passthrough";
    is $c->{"attribute[title]"}[0] =~ /Graffiti on the wall/, 1, "Confirm report selected";
    is $graffiti_report->external_id eq 'ext1', 1, "external_id restored to Confirm id";
    is $graffiti_report->get_extra_metadata('passthrough_id') eq '248', 1, "Passthrough id stored on report";
    is $graffiti_report->get_extra_metadata('sent_to_banes_passthrough') eq '1', 1, "Report registered as sent";

    my $comment = $mech->create_comment_for_problem($graffiti_report, $graffiti_report->user, 'Name', 'Update', 0, 'confirmed', 'confirmed');
    $comment->external_id('update1');
    $comment->update;

    Open311->_inject_response('servicerequestupdates.xml', '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>pass_update1</update_id></request_update></service_request_updates>');
    $script->send_comments;
    $req = Open311->test_req_used;
    $c = CGI::Simple->new($req->content);

    is $c->{service_request_id}[0] eq '248', 1, "Passthrough service_request_id is set as the report's passthrough id";

    $comment->discard_changes;
    is $comment->external_id eq 'update1', 1, "Confirm external_id restored";
    is $comment->get_extra_metadata('sent_to_banes_passthrough') eq '1', 1, "Comment registered as sent to passthrough";
    is $comment->get_extra_metadata('passthrough_id') eq 'pass_update1', 1, "Passthrough id stored on comment"
};

done_testing;
