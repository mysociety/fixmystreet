#!/usr/bin/env perl
use FixMyStreet::Test;

use Test::MockModule;
use Test::Warn;
use Path::Tiny 'path';
use Net::Amazon::S3::Client::Bucket;

use_ok( 'FixMyStreet::PhotoStorage::S3' );

FixMyStreet::override_config {
    PHOTO_STORAGE_OPTIONS => {
        ACCESS_KEY => 'AKIAMYFAKEACCESSKEY',
        SECRET_KEY => '1234/fAk35eCrETkEy',
        BUCKET => 'fms-test-photos',
        PREFIX => '/uploads',
    },
}, sub {

    my $s3 = FixMyStreet::PhotoStorage::S3->new();

    subtest "basic attributes are configured correctly" => sub {
        ok $s3->client, "N::A::S3::Client created";
        is $s3->client->s3->aws_access_key_id, 'AKIAMYFAKEACCESSKEY', "Correct access key used";
        is $s3->client->s3->aws_secret_access_key, '1234/fAk35eCrETkEy', "Correct secret key used";

        ok $s3->bucket, "N::A::S3::Bucket created";
        is $s3->bucket->name, 'fms-test-photos', "Correct bucket name configured";

        is $s3->prefix, '/uploads/', "Correct key prefix with trailing slash";
    };

    subtest "photos can be stored in S3" => sub {
        my $photo_blob = path('t/app/controller/sample.jpg')->slurp;
        is $s3->get_fileid($photo_blob), '74e3362283b6ef0c48686fb0e161da4043bbcc97', "File ID calculated correctly";
        is $s3->detect_type($photo_blob), 'jpeg', "File type calculated correctly";

        my $s3_object = Test::MockModule->new('Net::Amazon::S3::Client::Object');
        my $put_called = 0;
        $s3_object->mock('put', sub {
            my ($self, $photo) = @_;
            is $self->key, '/uploads/74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg', 'Object created with correct key';
            is $self->bucket->name, 'fms-test-photos', 'Object stored in correct bucket';
            is $photo, $photo_blob, 'Correct photo uploaded';
            $put_called = 1;
        });

        is $s3->store_photo($photo_blob), '/uploads/74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg', 'Photo uploaded and correct key returned';
        ok $put_called, "Object::put called";
    };

    subtest "photos can be retrieved from S3" => sub {
        my $photo_blob = path('t/app/controller/sample.jpg')->slurp;
        my $key = '/uploads/74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';

        my $s3_object = Test::MockModule->new('Net::Amazon::S3::Client::Object');
        my $exists_called = 0;
        $s3_object->mock('exists', sub {
            my ($self) = @_;
            is $self->key, $key, 'Object::exists called with correct key';
            $exists_called = 1;
            return 1;
        });
        my $get_called = 0;
        $s3_object->mock('get', sub {
            my ($self) = @_;
            is $self->key, $key, 'Object::get called with correct key';
            is $self->bucket->name, 'fms-test-photos', 'Object fetched from correct bucket';
            $get_called = 1;
            return $photo_blob;
        });

        my ($photo, $type) = $s3->retrieve_photo($key);
        ok $exists_called, "Object::exists called";
        ok $get_called, "Object::get called";
        is $photo, $photo_blob, 'Correct file content returned';
        is $type, 'jpeg', 'Correct file type returned';
    };

    subtest "init passes if bucket exists" => sub {
        my $s3_client = Test::MockModule->new('Net::Amazon::S3::Client');
        my $buckets_called = 0;
        $s3_client->mock('buckets', sub {
            my $self = shift;
            $buckets_called = 1;
            return (
                Net::Amazon::S3::Client::Bucket->new(
                    client => $self,
                    name => 'fms-test-photos'
                )
            );
        });

        ok $s3->init(), "PhotoStorage::S3::init succeeded";
        ok $buckets_called, "Client::buckets called";
    };

    subtest "init fails if bucket doesn't exist" => sub {
        my $s3_client = Test::MockModule->new('Net::Amazon::S3::Client');
        my $buckets_called = 0;
        $s3_client->mock('buckets', sub {
            my $self = shift;
            $buckets_called = 1;
            return (
                Net::Amazon::S3::Client::Bucket->new(
                    client => $self,
                    name => 'not-your-bucket'
                )
            );
        });
        my $create_bucket_called = 0;
        $s3_client->mock('create_bucket', sub {
            $create_bucket_called = 1;
        });

        warning_like {
            $s3->init();
        } qr/S3 bucket 'fms-test-photos' doesn't exist and CREATE_BUCKET is not set./, 'PhotoStorage::S3::init failed';
        ok $buckets_called, "Client::buckets called";
        ok !$create_bucket_called, "Client::create_bucket not called";
    };
};

FixMyStreet::override_config {
    PHOTO_STORAGE_OPTIONS => {
        ACCESS_KEY => 'AKIAMYFAKEACCESSKEY',
        SECRET_KEY => '1234/fAk35eCrETkEy',
        BUCKET => 'fms-test-photos',
        CREATE_BUCKET => 1,
        REGION => 'eu-west-3',
    },
}, sub {

    my $s3 = FixMyStreet::PhotoStorage::S3->new();

    subtest "init creates bucket if CREATE_BUCKET set" => sub {
        my $s3_client = Test::MockModule->new('Net::Amazon::S3::Client');
        my $create_bucket_called = 0;
        $s3_client->mock('create_bucket', sub {
            my ( $self, %conf ) = @_;
            $create_bucket_called = 1;
            is $conf{name}, "fms-test-photos", "Bucket created with correct name";
            is $conf{location_constraint}, "eu-west-3", "Bucket created in correct region";
        });
        my $buckets_called = 0;
        $s3_client->mock('buckets', sub {
            my $self = shift;
            $buckets_called = 1;
            return (
                Net::Amazon::S3::Client::Bucket->new(
                    client => $self,
                    name => 'not-your-bucket'
                ),
                $create_bucket_called ? Net::Amazon::S3::Client::Bucket->new(
                    client => $self,
                    name => 'fms-test-photos'
                ) : (),
            );
        });

        ok $s3->init(), "PhotoStorage::S3::init succeeded";
        ok $buckets_called, "Client::buckets called";
        ok $create_bucket_called, "Client::create_bucket called";
    };
};

done_testing();
