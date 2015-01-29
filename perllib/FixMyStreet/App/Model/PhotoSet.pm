package FixMyStreet::App::Model::PhotoSet;

# TODO this isn't a Cat model, rename to something else

use Moose;
use Path::Tiny 'path';
use Image::Magick;
use Scalar::Util 'openhandle';
use Digest::SHA qw(sha1_hex);

has c => (
    is => 'ro',
);

has item => (
    is => 'ro',
);

has data => ( # generic data from DB field
    is => 'rw',
);

has data_items => ( # either a) split from data or b) provided by photo upload
    isa => 'ArrayRef',
    is => 'rw',
    traits => ['Array'],
    lazy => 1,
    handles => {
        map_data_items => 'map',
    },
    default => sub {
        my $self = shift;
        my $data = $self->data
            or return [];

        return [$data] if (_jpeg_magic($data));

        return [ split ',' => $data ];
    },
);

sub _jpeg_magic {
    $_[0] =~ /^\x{ff}\x{d8}/; # JPEG
    # NB: should we also handle \x{89}\x{50} (PNG, 15 results in live DB) ?
    #     and \x{49}\x{49} (Tiff, 3 results in live DB) ?
}

has images => ( # jpeg data for actual image
    isa => 'ArrayRef',
    is => 'rw',
    traits => ['Array'],
    lazy => 1,
    handles => {
        num_images => 'count',
        get_raw_image_data => 'get',
    },
    default => sub {
        my $self = shift;
        my @photos = $self->map_data_items( sub {
            my $part = $_;

            if (_jpeg_magic($part)) {
                my $filename = $self->save_photo( $part );
                return [$filename, $part];
            }
            if (length($part) == 40) {
                my $file = path( $self->c->config->{UPLOAD_DIR}, "$part.jpeg" );
                my $photo = $file->slurp;
                [$part, $photo];
            }
            else {
                warn sprintf "Received photo hash of length %d", length($part);
                ();
            }
        });
        return \@photos;
    },
);

sub save_photo { return 'TODO' }

sub get_image_data {
    my ($self, %args) = @_;
    my $num = $args{num} || 1;

    my $data = $self->get_raw_image_data( 0 ) # for test, because of broken IE/Windows caching
        or return;

    my ($name, $photo) = @$data;

    my $size = $args{size};
    if ( $size eq 'tn' ) {
        $photo = _shrink( $photo, 'x100' );
    } elsif ( $size eq 'fp' ) {
        $photo = _crop( $photo );
    } elsif ( $size eq 'full' ) {
        # do nothing
    } else {
        $photo = _shrink( $photo, $self->c->cobrand->default_photo_resize || '250x250' );
    }

    return $photo;
}

# NB: These 2 subs stolen from A::C::Photo, should be purged from there!
#
# Shrinks a picture to the specified size, but keeping in proportion.
sub _shrink {
    my ($photo, $size) = @_;
    my $image = Image::Magick->new;
    $image->BlobToImage($photo);
    my $err = $image->Scale(geometry => "$size>");
    throw Error::Simple("resize failed: $err") if "$err";
    $image->Strip();
    my @blobs = $image->ImageToBlob();
    undef $image;
    return $blobs[0];
}

# Shrinks a picture to 90x60, cropping so that it is exactly that.
sub _crop {
    my ($photo) = @_;
    my $image = Image::Magick->new;
    $image->BlobToImage($photo);
    my $err = $image->Resize( geometry => "90x60^" );
    throw Error::Simple("resize failed: $err") if "$err";
    $err = $image->Extent( geometry => '90x60', gravity => 'Center' );
    throw Error::Simple("resize failed: $err") if "$err";
    $image->Strip();
    my @blobs = $image->ImageToBlob();
    undef $image;
    return $blobs[0];
}

1;
