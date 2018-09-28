package FixMyStreet::Cobrand::Tester;

use parent 'FixMyStreet::Cobrand::FixMyStreet';

sub open311_config {
    my ($self, $row, $h, $params) = @_;
    $params->{multi_photos} = 1;
}

package main;

use CGI::Simple;
use Path::Tiny;
use FixMyStreet::Script::Reports;
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
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $test_data = FixMyStreet::Script::Reports::send();
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

my ($photo_report) = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    cobrand => 'fixmystreet',
    category => 'Potholes',
    user => $user,
});
my $sample_file = path(__FILE__)->parent->parent->child("app/controller/sample.jpg");
my $UPLOAD_DIR = File::Temp->newdir();
my @files = map { $_ x 40 . ".jpeg" } (1..3);
$sample_file->copy(path($UPLOAD_DIR, $_)) for @files;
$photo_report->photo(join(',', @files));
$photo_report->update;

subtest 'test report with multiple photos only sends one', sub {
    $body->update( { send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test' } );
    my $test_data;

    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
        PHOTO_STORAGE_BACKEND => 'FileSystem',
        PHOTO_STORAGE_OPTIONS => {
            UPLOAD_DIR => $UPLOAD_DIR,
        },
    }, sub {
        $test_data = FixMyStreet::Script::Reports::send();
    };
    $photo_report->discard_changes;
    ok $photo_report->whensent, 'Report marked as sent';
    is $photo_report->send_method_used, 'Open311', 'Report sent via Open311';
    is $photo_report->external_id, 248, 'Report has right external ID';

    my $req = $test_data->{test_req_used};
    my $c = CGI::Simple->new($req->content);
    is $c->param('attribute[easting]'), 529025, 'Request had easting';
    is $c->param('attribute[northing]'), 179716, 'Request had northing';
    is $c->param('attribute[fixmystreet_id]'), $photo_report->id, 'Request had correct ID';
    is $c->param('jurisdiction_id'), 'FMS', 'Request had correct jurisdiction';
    my @media = $c->param('media_url');
    is_deeply \@media, [
        'http://www.example.org/photo/' . $photo_report->id .'.0.full.jpeg?11111111'
    ], 'One photo in media_url';
};

$photo_report->whensent(undef);
$photo_report->cobrand('tester');
$photo_report->send_method_used('');
$photo_report->update();

subtest 'test sending multiple photos', sub {
    $body->update( { send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test' } );
    my $test_data;

    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'tester' ],
        MAPIT_URL => 'http://mapit.uk/',
        PHOTO_STORAGE_BACKEND => 'FileSystem',
        PHOTO_STORAGE_OPTIONS => {
            UPLOAD_DIR => $UPLOAD_DIR,
        },
    }, sub {
        $test_data = FixMyStreet::Script::Reports::send();
    };
    $photo_report->discard_changes;
    ok $photo_report->whensent, 'Report marked as sent';
    is $photo_report->send_method_used, 'Open311', 'Report sent via Open311';
    is $photo_report->external_id, 248, 'Report has right external ID';

    my $req = $test_data->{test_req_used};
    my $c = CGI::Simple->new($req->content);
    my @media = $c->param('media_url');
    is_deeply \@media, [
        'http://www.example.org/photo/' . $photo_report->id .'.0.full.jpeg?11111111',
        'http://www.example.org/photo/' . $photo_report->id .'.1.full.jpeg?22222222',
        'http://www.example.org/photo/' . $photo_report->id .'.2.full.jpeg?33333333'
    ], 'Multiple photos in media_url';
};

done_testing();
