use FixMyStreet::TestMech;
use Path::Tiny;
use File::Temp 'tempdir';
use JSON::MaybeXS;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $sample_no_gps = path(__FILE__)->parent->child("sample.jpg");
ok $sample_no_gps->exists, "sample file without GPS exists";

my $sample_with_gps = path(__FILE__)->parent->child("sample-with-gps-exif.jpg");
ok $sample_with_gps->exists, "sample file with GPS exists";

# Expected GPS coordinates from sample-with-gps-exif.jpg:
# EXIF data: N 51d 47m 57.02s, W 2d 28m 43.82s
my $expected_lat = 51 + 47/60 + 57.02/3600;
my $expected_lon = -(2 + 28/60 + 43.82/3600);

my $UPLOAD_DIR = tempdir(CLEANUP => 1);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_BACKEND => 'FileSystem',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => $UPLOAD_DIR,
    },
}, sub {
    subtest "Photo upload with get_latlon=1 extracts GPS coordinates" => sub {
        $mech->post('/photo/upload?get_latlon=1',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_with_gps, undef, Content_Type => 'image/jpeg' ],
            },
        );

        ok $mech->success, 'Upload with GPS succeeded';
        my $response = decode_json($mech->content);

        ok $response->{id}, 'Response contains photo id';
        ok exists $response->{lat}, 'Response contains latitude';
        ok exists $response->{lon}, 'Response contains longitude';

        # Verify GPS coordinates are reasonable (tolerance for JSON floating-point precision)
        cmp_ok abs($response->{lat} - $expected_lat), '<', 1e-10, 'Latitude is correct';
        cmp_ok abs($response->{lon} - $expected_lon), '<', 1e-10, 'Longitude is correct';
    };

    subtest "Photo upload with get_latlon=1 but NO GPS returns id only" => sub {
        $mech->post('/photo/upload?get_latlon=1',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_no_gps, undef, Content_Type => 'image/jpeg' ],
            },
        );

        ok $mech->success, 'Upload without GPS succeeded';
        my $response = decode_json($mech->content);

        ok $response->{id}, 'Response contains photo id';
        ok !exists $response->{lat}, 'Response does NOT contain latitude';
        ok !exists $response->{lon}, 'Response does NOT contain longitude';
    };

    subtest "Photo upload without get_latlon does not return GPS (backward compat)" => sub {
        # No get_latlon parameter - even with GPS photo, should not return coordinates
        $mech->post('/photo/upload',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_with_gps, undef, Content_Type => 'image/jpeg' ],
            },
        );

        ok $mech->success, 'Upload succeeded';
        my $response = decode_json($mech->content);

        ok $response->{id}, 'Response contains photo id';
        ok !exists $response->{lat}, 'Response does NOT contain lat without get_latlon';
        ok !exists $response->{lon}, 'Response does NOT contain lon without get_latlon';
    };

    subtest "Non-JS photo upload with GPS redirects to /report/new" => sub {
        # Disable redirects to inspect the redirect response itself
        $mech->requests_redirectable([]);

        # Use query string parameter for start_report to match form action pattern
        my $res = $mech->post('/photo/upload?start_report=1',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_with_gps, undef, Content_Type => 'image/jpeg' ],
            },
        );

        $mech->requests_redirectable(['GET', 'HEAD', 'POST']);

        is $res->code, 302, 'Got redirect';
        my $location = $res->header('Location');
        like $location, qr{/report/new}, 'Redirects to /report/new';
        like $location, qr{lat=}, 'URL contains lat parameter';
        like $location, qr{lon=}, 'URL contains lon parameter';
        like $location, qr{photo_id=}, 'URL contains photo_id parameter';
    };

    subtest "Non-JS photo upload without GPS redirects to /around" => sub {
        # Disable redirects to inspect the redirect response itself
        $mech->requests_redirectable([]);

        # Use query string parameter for start_report to match form action pattern
        my $res = $mech->post('/photo/upload?start_report=1',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_no_gps, undef, Content_Type => 'image/jpeg' ],
            },
        );

        $mech->requests_redirectable(['GET', 'HEAD', 'POST']);

        is $res->code, 302, 'Got redirect';
        my $location = $res->header('Location');
        like $location, qr{/around}, 'Redirects to /around';
        unlike $location, qr{lat=}, 'URL does NOT contain lat';
        unlike $location, qr{lon=}, 'URL does NOT contain lon';
        like $location, qr{photo_id=}, 'URL contains photo_id';
    };

    subtest "Photo temp URL accessible after upload" => sub {
        $mech->post('/photo/upload',
            Content_Type => 'form-data',
            Content => {
                photo => [ $sample_no_gps, undef, Content_Type => 'image/jpeg' ],
            },
        );

        my $response = decode_json($mech->content);
        my $photo_id = $response->{id};

        $mech->get_ok("/photo/temp.$photo_id", "Can access temp photo URL");
    };

};

done_testing;
