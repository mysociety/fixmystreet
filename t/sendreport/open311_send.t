package FixMyStreet::Cobrand::Tester;

use parent 'FixMyStreet::Cobrand::FixMyStreet';

sub open311_config {
    my ($self, $row, $h, $params) = @_;
    $params->{multi_photos} = 1;
}

package main;

use CGI::Simple;
use Path::Tiny;
use Test::Warn;
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

my ($bad_category_report) = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    cobrand => 'fixmystreet',
    category => 'Flytipping',
    user => $user,
});

subtest 'test handles bad category', sub {
    $body->update( { send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test' } );
    my $test_data;
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $test_data = FixMyStreet::Script::Reports::send();
    };
    $bad_category_report->discard_changes;
    ok !$bad_category_report->whensent, 'Report not marked as sent';
    like $bad_category_report->send_fail_reason, qr/Category Flytipping does not exist for body/, 'failure message set';
};

my $hounslow = $mech->create_body_ok( 2483, 'Hounslow Borough Council');
my $contact2 = $mech->create_contact_ok( body_id => $hounslow->id, category => 'Graffiti', email => 'GRAF' );
$contact2->set_extra_fields(
    { code => 'easting', datatype => 'number' },
    { code => 'northing', datatype => 'number' },
    { code => 'fixmystreet_id', datatype => 'number' },
);
$contact2->update;

my ($hounslow_report) = $mech->create_problems_for_body( 1, $hounslow->id, 'Test', {
    cobrand => 'hounslow',
    category => 'Graffiti',
    user => $user,
    latitude => 51.482286,
    longitude => -0.328163,
    cobrand => 'hounslow',
});

subtest 'Hounslow sends email upon Open311 submission', sub {
    $hounslow->update( { send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'hounslow', api_key => 'test' } );
    $mech->clear_emails_ok;
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'hounslow' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        FixMyStreet::Script::Reports::send();
    };
    $hounslow_report->discard_changes;
    ok $hounslow_report->whensent, 'Report marked as sent';
    ok $hounslow_report->get_extra_metadata('hounslow_email_sent'), "Enquiries inbox email marked as sent";
    my ($hounslow_email, $user_email) = $mech->get_email;
    my $body = $mech->get_text_body_from_email($hounslow_email);
    like $body, qr/A user of FixMyStreet has submitted the following report/;
    like $body, qr/Category: Graffiti/;
    like $body, qr/Enquiry ref: 248/;
    $body = $mech->get_text_body_from_email($user_email);
    like $body, qr/reference number is 248/;
};


done_testing();
