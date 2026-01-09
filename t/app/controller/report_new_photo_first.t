use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

use FixMyStreet::TestMech;
use Path::Tiny;
use File::Temp 'tempdir';
use JSON::MaybeXS;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $sample_file = path(__FILE__)->parent->child("sample.jpg");
ok $sample_file->exists, "sample file exists";

my $body = $mech->create_body_ok(2651, 'City of Edinburgh Council');
$mech->create_contact_ok(body_id => $body->id, category => 'Potholes', email => 'potholes@example.com');

my $UPLOAD_DIR = tempdir(CLEANUP => 1);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_BACKEND => 'FileSystem',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => $UPLOAD_DIR,
    },
}, sub {

    subtest "Photo with GPS (photo_first=1) shows confirmation page" => sub {
        $mech->post('/photo/upload',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
            },
        );
        my $response = decode_json($mech->content);
        my $photo_id = $response->{id};

        $mech->get_ok("/report/new?lat=55.952&lon=-3.189&photo_id=$photo_id&photo_first=1");

        $mech->content_contains('data-page-name="photo-confirm"', 'Photo confirmation page present');
        $mech->content_contains('Photo uploaded successfully', 'Shows success message');
        $mech->content_contains("/photo/temp.$photo_id", 'Shows photo preview URL');
        $mech->content_contains('js-reporting-page--desktop-only', 'Desktop-only class present');

        $mech->content_contains('name="photo_id"', 'Hidden photo_id input present');
        $mech->content_contains("value=\"$photo_id\"", 'Hidden input has correct photo_id value');
    };

    subtest "Photo without GPS (no photo_first) does NOT show confirmation page" => sub {
        $mech->post('/photo/upload',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
            },
        );
        my $photo_id = decode_json($mech->content)->{id};

        # User uploaded photo without GPS, entered location on /around, then was redirected here
        $mech->get_ok("/report/new?lat=55.952&lon=-3.189&photo_id=$photo_id");

        $mech->content_lacks('data-page-name="photo-confirm"', 'No photo confirmation page');
        $mech->content_lacks('Photo uploaded successfully', 'No photo success message');
        $mech->content_lacks('js-reporting-page--desktop-only', 'No desktop-only class');

        # Category page should be active since no photo confirmation page
        $mech->content_contains('js-reporting-page--category', 'Category page present');

        # But photo_id should still be preserved for form submission
        $mech->content_contains(qq(name="photo_id" value="$photo_id"), 'photo_id hidden input still present');
        $mech->content_contains(qq(name="upload_fileid" value="$photo_id"), 'upload_fileid populated from photo_id');
    };

    subtest "Report new without any photo does not show photo confirmation page" => sub {
        $mech->get_ok('/report/new?lat=55.952&lon=-3.189');

        $mech->content_lacks('data-page-name="photo-confirm"', 'No photo confirmation page');
        $mech->content_lacks('Photo uploaded successfully', 'No photo success message');

        # Category is the default first page in the normal flow
        $mech->content_contains('js-reporting-page--category', 'Category page present');
    };

    subtest "photo_id is preserved through form validation errors" => sub {
        $mech->post('/photo/upload',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
            },
        );
        my $photo_id = decode_json($mech->content)->{id};

        $mech->log_in_ok('test@example.com');
        $mech->get_ok("/report/new?lat=55.952&lon=-3.189&photo_id=$photo_id&photo_first=1");

        my ($csrf) = $mech->content =~ /name="token" value="([^"]*)"/;

        # Empty title/detail triggers validation errors
        $mech->post('/report/new',
            Content_Type => 'form-data',
            Content => {
                submit_problem => 1,
                token => $csrf,
                title => '',
                detail => '',
                photo_id => $photo_id,
                photo_first => 1,
                lat => 55.952,
                lon => -3.189,
                category => 'Potholes',
                name => 'Test User',
                email => 'test@example.com',
            },
        );

        # Photo should still be attached even after form re-renders with errors
        $mech->content_contains("value=\"$photo_id\"", 'photo_id preserved after validation error');
        $mech->content_contains("/photo/temp.$photo_id", 'Photo preview still shown');
    };

};

done_testing;
