use utf8;
use Encode;
use FixMyStreet::TestMech;
use Path::Tiny;
use File::Temp 'tempdir';
use FixMyStreet::Script::Reports;
use Test::MockModule;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok( 2483, 'Hounslow Borough Council', {
    send_method => 'Open311',
    endpoint => 'endpoint',
    api_key => 'key',
    jurisdiction => 'hounslow',
});
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'General Enquiry',
    email => 'genenq@example.com',
    non_public => 1,
);
my $contact2 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'FOI Request',
    email => 'foi@example.com',
    non_public => 1,
);
my $contact3 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Other',
    email => 'other@example.com',
);
my $contact4 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Carriageway Defect',
    email => 'potholes@example.com',
);
$contact->update( { extra => { group => 'General Enquiries' } } );
$contact2->update( { extra => { group => 'General Enquiries' } } );
$contact3->update( { extra => { group => 'Other' } } );

FixMyStreet::override_config { ALLOWED_COBRANDS => ['bromley'], }, sub {
    subtest 'redirected to / if general enquiries not enabled' => sub {
        $mech->get( '/contact/enquiry' );
        is $mech->res->code, 200, "got 200 for final destination";
        is $mech->res->previous->code, 302, "got 302 for redirect";
        is $mech->uri->path, '/';
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['hounslow'],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Non-general enquiries category not shown' => sub {
        $mech->get_ok( '/contact/enquiry' );
        $mech->content_lacks('Carriageway Defect');
        $mech->content_contains('FOI Request');
    };

    subtest 'Enquiry can be submitted when logged out' => sub {
        my $problems = FixMyStreet::DB->resultset('Problem')->to_body( $body->id );

        $mech->get_ok( '/contact/enquiry' );
        $mech->submit_form_ok( {
            with_fields => {
                name => 'Test User',
                username => 'testuser@example.org',
                category => 'Other',
                detail => 'This is a general enquiry',
            }
        } );
        is $mech->uri->path, '/contact/enquiry/submit';
        $mech->content_contains("Thank you for your enquiry");

        is $problems->count, 1, 'problem created';
        my $problem = $problems->first;
        is $problem->category, 'Other', 'problem has correct category';
        is $problem->detail, 'This is a general enquiry', 'problem has correct detail';
        is $problem->non_public, 1, 'problem created non_public';
        is $problem->postcode, '';
        is $problem->used_map, 0;
        is $problem->latitude, 51.469, 'Problem has correct latitude';
        is $problem->longitude, -0.35, 'Problem has correct longitude';
        ok $problem->confirmed, 'problem confirmed';
        is $problem->user->name, undef, 'User created without name';
        is $problem->name, 'Test User', 'Report created with correct name';
        is $problem->user->email, 'testuser@example.org', 'User created with correct email';
    };

    subtest 'Enquiry can be submitted when logged in' => sub {
        my $problems = FixMyStreet::DB->resultset('Problem')->to_body( $body->id );
        my $prob_user = $problems->first->user;
        $problems->delete_all;

        my $user = $mech->log_in_ok( $prob_user->email );

        $mech->get_ok( '/contact/enquiry' );
        $mech->submit_form_ok( {
            with_fields => {
                name => 'Test User',
                category => 'FOI Request',
                detail => 'This is a general enquiry',
            }
        } );
        is $mech->uri->path, '/contact/enquiry/submit';
        $mech->content_contains("Thank you for your enquiry");

        is $problems->count, 1, 'problem created';
        my $problem = $problems->first;
        is $problem->category, 'FOI Request', 'problem has correct category';
        is $problem->detail, 'This is a general enquiry', 'problem has correct detail';
        is $problem->non_public, 1, 'problem created non_public';
        is $problem->postcode, '';
        is $problem->used_map, 0;
        is $problem->latitude, 51.469, 'Problem has correct latitude';
        is $problem->longitude, -0.35, 'Problem has correct longitude';
        ok $problem->confirmed, 'problem confirmed';
        is $problem->name, 'Test User', 'Report created with correct name';
        is $problem->user->name, 'Test User', 'User name updated in DB';
        is $problem->user->email, $user->email, 'Report user has correct email';

        $mech->log_out_ok;
    };

    subtest 'User name not changed if logged out when making report' => sub {
        my $problems = FixMyStreet::DB->resultset('Problem')->to_body( $body->id );
        my $user = $problems->first->user;
        $problems->delete_all;

        is $user->name, 'Test User', 'User has correct name';

        $mech->get_ok( '/contact/enquiry' );
        $mech->submit_form_ok( {
            with_fields => {
                name => 'Simon Neil',
                username => $user->email,
                category => 'General Enquiry',
                detail => 'This is a general enquiry',
            }
        } );
        is $mech->uri->path, '/contact/enquiry/submit';
        $mech->content_contains("Thank you for your enquiry");

        is $problems->count, 1, 'problem created';
        my $problem = $problems->first;
        is $problem->category, 'General Enquiry', 'problem has correct category';
        is $problem->detail, 'This is a general enquiry', 'problem has correct detail';
        is $problem->non_public, 1, 'problem created non_public';
        is $problem->postcode, '';
        is $problem->used_map, 0;
        is $problem->latitude, 51.469, 'Problem has correct latitude';
        is $problem->longitude, -0.35, 'Problem has correct longitude';
        ok $problem->confirmed, 'problem confirmed';
        is $problem->name, 'Simon Neil', 'Report created with correct name';
        is $problem->user->email, $user->email, 'Report user has correct email';
        $user->discard_changes;
        is $user->name, 'Test User', 'User name in DB not changed';

        $mech->log_out_ok;
    };

};

my $sample_jpeg = path(__FILE__)->parent->child("sample.jpg");
ok $sample_jpeg->exists, "sample image $sample_jpeg exists";
my $sample_pdf = path(__FILE__)->parent->child("sample.pdf");
ok $sample_pdf->exists, "sample PDF $sample_pdf exists";

my $UPLOAD_DIR = tempdir( CLEANUP => 1 );

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'hounslow' ],
    STAGING_FLAGS => { send_reports => 1 },
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_BACKEND => 'FileSystem',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => $UPLOAD_DIR,
    },
}, sub {

    my $pdf_hash = '90f7a64043fb458d58de1a0703a6355e2856b15e.pdf';
    my $image_hash = '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';

    subtest "Check photo & file upload works" => sub {
        my $problems = FixMyStreet::DB->resultset('Problem')->to_body( $body->id );
        $problems->delete_all;


        $mech->get_ok('/contact/enquiry');
        my ($csrf) = $mech->content =~ /name="token" value="([^"]*)"/;

        $mech->post( '/contact/enquiry/submit',
            Content_Type => 'form-data',
            Content =>
            {
            submit_problem => 1,
            token => $csrf,
            name => 'Test User',
            username => 'testuser@example.org',
            category => 'Other',
            detail => encode_utf8('This is a general enquiry‽'),
            photo1         => [ $sample_jpeg, undef, Content_Type => 'image/jpeg' ],
            photo2         => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
            }
        );
        ok $mech->success, 'Made request with two files uploaded';

        is $problems->count, 1, 'problem created';
        my $problem = $problems->first;
        is $problem->detail, 'This is a general enquiry‽', 'problem has correct detail';
        is $problem->non_public, 1, 'problem created non_public';
        is $problem->postcode, '';
        is $problem->used_map, 0;
        is $problem->latitude, 51.469, 'Problem has correct latitude';
        is $problem->longitude, -0.35, 'Problem has correct longitude';
        ok $problem->confirmed, 'problem confirmed';

        my $image_file = path($UPLOAD_DIR, $image_hash);
        ok $image_file->exists, 'Photo uploaded to temp';

        my $photoset = $problem->get_photoset();
        is $photoset->num_images, 1, 'Found just 1 image';
        is $photoset->data, $image_hash;

        my $pdf_file = path($UPLOAD_DIR, 'enquiry_files', $pdf_hash);
        ok $pdf_file->exists, 'PDF uploaded to temp';

        is_deeply $problem->get_extra_metadata('enquiry_files'), {
            $pdf_hash => 'sample.pdf'
        }, 'enquiry file info stored OK';
    };

    subtest 'Check Open311 sending of the above report' => sub {
        my $module = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
        $module->mock(get => sub ($) { '{}' });
        my $test_data = FixMyStreet::Script::Reports::send();
        my $req = $test_data->{test_req_used};
        my $found = 0;
        foreach ($req->parts) {
            my $cd = $_->header('Content-Disposition');
            if ($cd =~ /attribute\[description\]/) {
                is decode_utf8($_->content), 'This is a general enquiry‽', 'Correct description';
                $found++;
            }
            if ($cd =~ /sample.pdf/) {
                is $cd, 'form-data; name="file_' . $pdf_hash . '"; filename="sample.pdf"', 'Correct PDF header';
                is $_->header('Content-Type'), 'application/pdf', 'Correct PDF content type';
                $found++;
            }
            if ($cd =~ /jpeg/) {
                is $cd, 'form-data; name="photo1"; filename="' . $image_hash . '"', 'Correct image header';
                is $_->header('Content-Type'), 'image/jpeg', 'Correct image content type';
                $found++;
            }
        }
        is $found, 3, 'Found all tested headers';
    };

};

done_testing();
