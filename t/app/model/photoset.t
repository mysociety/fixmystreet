use FixMyStreet::Test;
use Test::Exception;

use FixMyStreet::DB;
use DateTime;
use Path::Tiny 'path';
use File::Temp 'tempdir';

my $dt = DateTime->now;

my $UPLOAD_DIR = tempdir( CLEANUP => 1 );

my $db = FixMyStreet::DB->schema;

my $user = $db->resultset('User')->find_or_create({ name => 'Bob', email => 'bob@example.com' });

FixMyStreet::override_config {
    PHOTO_STORAGE_BACKEND => 'FileSystem',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => $UPLOAD_DIR,
    },
}, sub {

my $image_path = path('t/app/controller/sample.jpg');

sub make_report {
    my $photo_data = shift;
    return $db->resultset('Problem')->create({
        postcode           => 'BR1 3SB',
        bodies_str         => '',
        areas              => ",,",
        category           => 'Other',
        title              => 'test',
        detail             => 'test',
        used_map           => 't',
        name               => 'Anon',
        anonymous          => 't',
        state              => 'confirmed',
        confirmed          => $dt,
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.4129',
        longitude          => '0.007831',
        user => $user,
        photo => $photo_data,
    });
}


subtest 'Photoset with photo inline in DB' => sub {
    my $report = make_report( $image_path->slurp );
    my $photoset = $report->get_photoset();
    is $photoset->num_images, 1, 'Found just 1 image';
    is $photoset->data, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';
};

$image_path->copy( path( $UPLOAD_DIR, '0123456789012345678901234567890123456789.jpeg' ) );
subtest 'Photoset with 1 referenced photo' => sub {
    my $report = make_report( '0123456789012345678901234567890123456789' );
    my $photoset = $report->get_photoset();
    is $photoset->num_images, 1, 'Found just 1 image';
};

subtest 'Photoset with 3 referenced photo' => sub {
    my $report = make_report( '0123456789012345678901234567890123456789,0123456789012345678901234567890123456789,0123456789012345678901234567890123456789' );
    my $photoset = $report->get_photoset();
    is $photoset->num_images, 3, 'Found 3 images';
};

};

subtest 'Correct storage backends are instantiated' => sub {
    FixMyStreet::override_config {
        PHOTO_STORAGE_BACKEND => 'FileSystem'
    }, sub {
        my $photoset = FixMyStreet::App::Model::PhotoSet->new;
        isa_ok $photoset->storage, 'FixMyStreet::PhotoStorage::FileSystem';
    };

    FixMyStreet::override_config {
        PHOTO_STORAGE_BACKEND => undef
    }, sub {
        my $photoset = FixMyStreet::App::Model::PhotoSet->new;
        isa_ok $photoset->storage, 'FixMyStreet::PhotoStorage::FileSystem';
    };

    FixMyStreet::override_config {
        PHOTO_STORAGE_BACKEND => 'S3'
    }, sub {
        my $photoset = FixMyStreet::App::Model::PhotoSet->new;
        isa_ok $photoset->storage, 'FixMyStreet::PhotoStorage::S3';
    };

};


done_testing();
