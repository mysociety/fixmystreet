use FixMyStreet::Test;
use Test::Exception;
use Test::MockModule;
use Test::MockObject;

use FixMyStreet::App::Model::PhotoSet;
use Path::Tiny 'path';
use File::Temp 'tempdir';

my $sample_with_gps = path('t/app/controller/sample-with-gps-exif.jpg');
my $sample_no_gps = path('t/app/controller/sample.jpg');

ok $sample_with_gps->exists, "GPS test image exists";
ok $sample_no_gps->exists, "No-GPS test image exists";

# Expected GPS coordinates from sample-with-gps-exif.jpg:
# EXIF data: N 51d 47m 57.02s, W 2d 28m 43.82s
my $expected_lat = 51 + 47/60 + 57.02/3600;
my $expected_lon = -(2 + 28/60 + 43.82/3600);

my $UPLOAD_DIR = tempdir(CLEANUP => 1);

FixMyStreet::override_config {
    PHOTO_STORAGE_BACKEND => 'FileSystem',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => $UPLOAD_DIR,
    },
}, sub {

    subtest 'stash_gps_info extracts GPS from JPEG with coordinates' => sub {
        my %stash;
        my $mock_c = Test::MockObject->new;
        $mock_c->mock('stash', sub { \%stash });

        my $photoset = FixMyStreet::App::Model::PhotoSet->new({
            c => $mock_c,
        });

        my $temp_file = path($UPLOAD_DIR, 'test_gps.jpeg');
        $sample_with_gps->copy($temp_file);

        $photoset->stash_gps_info($temp_file->stringify);

        ok $stash{photo_gps}, 'GPS info was stashed';
        ok defined $stash{photo_gps}{lat}, 'Latitude is present';
        ok defined $stash{photo_gps}{lon}, 'Longitude is present';

        # Use tolerance for floating point precision
        cmp_ok abs($stash{photo_gps}{lat} - $expected_lat), '<', 1e-10,
            "Latitude is correct: got $stash{photo_gps}{lat}, expected ~$expected_lat";
        cmp_ok abs($stash{photo_gps}{lon} - $expected_lon), '<', 1e-10,
            "Longitude is correct: got $stash{photo_gps}{lon}, expected ~$expected_lon";
    };

};

done_testing;
