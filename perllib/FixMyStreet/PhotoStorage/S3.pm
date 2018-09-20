package FixMyStreet::PhotoStorage::S3;

use Moose;
use parent 'FixMyStreet::PhotoStorage';

use Net::Amazon::S3;
use Try::Tiny;


has client => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $key = FixMyStreet->config('PHOTO_STORAGE_OPTIONS')->{ACCESS_KEY};
        my $secret = FixMyStreet->config('PHOTO_STORAGE_OPTIONS')->{SECRET_KEY};

        my $s3 = Net::Amazon::S3->new(
            aws_access_key_id     => $key,
            aws_secret_access_key => $secret,
            retry                 => 1,
        );
        return Net::Amazon::S3::Client->new( s3 => $s3 );
    },
);

has bucket => (
    is => 'ro',
    lazy => 1,
    default => sub {
        shift->client->bucket( name => FixMyStreet->config('PHOTO_STORAGE_OPTIONS')->{BUCKET} );
    },
);

has region => (
    is => 'ro',
    lazy => 1,
    default => sub {
        return FixMyStreet->config('PHOTO_STORAGE_OPTIONS')->{REGION};
    },
);

has prefix => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $prefix = FixMyStreet->config('PHOTO_STORAGE_OPTIONS')->{PREFIX};
        return "" unless $prefix;
        $prefix =~ s#/$##;
        return "$prefix/";
    },
);

sub init {
    my $self = shift;

    return 1 if $self->_bucket_exists();

    if ( FixMyStreet->config('PHOTO_STORAGE_OPTIONS')->{CREATE_BUCKET} ) {
        my $name = $self->bucket->name;
        try {
            $self->client->create_bucket(
                name => $name,
                location_constraint => $self->region,
            );
        } catch {
            warn "\x1b[31mCouldn't create S3 bucket '$name'\x1b[0m\n";
            return;
        };

        return 1 if $self->_bucket_exists();

        warn "\x1b[31mCouldn't create S3 bucket '$name'\x1b[0m\n";
        return;
    } else {
        my $bucket = $self->bucket->name;
        warn "\x1b[31mS3 bucket '$bucket' doesn't exist and CREATE_BUCKET is not set.\x1b[0m\n";
        return;
    }
}

sub _bucket_exists {
    my $self = shift;
    my $name = $self->bucket->name;
    my @buckets = $self->client->buckets;
    return grep { $_->name eq $name } @buckets;
}

sub get_object {
    my ($self, $key) = @_;
    return $self->bucket->object( key => $key );
}

sub store_photo {
    my ($self, $photo_blob) = @_;

    my $type = $self->detect_type($photo_blob) || 'jpeg';
    my $fileid = $self->get_fileid($photo_blob);
    my $key = $self->prefix . "$fileid.$type";

    my $object = $self->get_object($key);
    $object->put($photo_blob);

    return $key;
}


sub retrieve_photo {
    my ($self, $key) = @_;

    my $object = $self->get_object($key);
    if ($object->exists) {
        my ($fileid, $type) = split /\./, $key;
        return ($object->get, $type);
    }

}

sub validate_key { $_[1] }


1;
