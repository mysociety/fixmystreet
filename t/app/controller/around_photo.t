use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

use FixMyStreet::TestMech;
use Path::Tiny;
use File::Temp 'tempdir';
use JSON::MaybeXS;

my $mech = FixMyStreet::TestMech->new;

my $sample_file = path(__FILE__)->parent->child("sample.jpg");
ok $sample_file->exists, "sample file exists";

my $UPLOAD_DIR = tempdir(CLEANUP => 1);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_BACKEND => 'FileSystem',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => $UPLOAD_DIR,
    },
}, sub {

    subtest "Around page with valid photo_id shows preview" => sub {
        $mech->post('/photo/upload',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
            },
        );
        my $response = decode_json($mech->content);
        my $photo_id = $response->{id};
        ok $photo_id, "Got photo_id from upload";

        $mech->get_ok("/around?photo_id=$photo_id");
        $mech->content_contains('Thanks for uploading your photo', 'Shows photo info message');
        $mech->content_contains("/photo/temp.$photo_id", 'Shows photo preview URL');
        $mech->content_contains('name="photo_id"', 'Contains hidden photo_id input');
        $mech->content_contains("value=\"$photo_id\"", 'Hidden input has correct photo_id value');
    };

    subtest "Around page with invalid photo_id ignores it gracefully" => sub {
        $mech->get_ok('/around?photo_id=invalid_hash_that_does_not_exist.jpeg');
        $mech->content_lacks('Thanks for uploading your photo', 'Does not show photo message');
        # Page should still work, just without the photo
        $mech->content_contains('Report a problem', 'Page still shows normal content');
    };

    subtest "Around page with empty photo_id works normally" => sub {
        $mech->get_ok('/around?photo_id=');
        $mech->content_lacks('Thanks for uploading your photo', 'No photo message for empty photo_id');
    };

    subtest "Postcode search with photo_id redirects to /report/new with photo_id preserved" => sub {
        $mech->post('/photo/upload',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
            },
        );
        my $response = decode_json($mech->content);
        my $photo_id = $response->{id};

        $mech->get_ok("/around?photo_id=$photo_id");
        $mech->submit_form_ok(
            { with_fields => { pc => 'EH1 1BB' } },
            "Submit postcode search with photo_id"
        );

        is $mech->uri->path, '/report/new', 'Redirects to /report/new';
        like $mech->uri->query, qr{photo_id=\Q$photo_id\E}, 'photo_id preserved in redirect';
        like $mech->uri->query, qr{latitude=}, 'latitude parameter present';
        like $mech->uri->query, qr{longitude=}, 'longitude parameter present';
    };

    subtest "Photo preview image is accessible" => sub {
        $mech->post('/photo/upload',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
            },
        );
        my $response = decode_json($mech->content);
        my $photo_id = $response->{id};
        $mech->get_ok("/photo/temp.$photo_id", "Temp photo URL is accessible");
    };
};

done_testing;
