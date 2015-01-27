package FixMyStreet::App::Model::PhotoSet;

# TODO this isn't a Cat model, rename to something else

use Moose;
use Path::Tiny 'path';
use if !$ENV{TRAVIS}, 'Image::Magick';
use Scalar::Util 'openhandle', 'blessed';
use Digest::SHA qw(sha1_hex);

has c => (
    is => 'ro',
);

has item => (
    is => 'ro',
);

has data => ( # generic data from DB field
    is => 'ro',
    lazy => 1,
    default => sub {
        # yes, this is a little circular: data -> data_items -> items -> data
        # e.g. if not provided, then we're presumably uploading/etc., so calculate from 
        # the stored cached fileids
        # (obviously if you provide none of these, then you'll get an infinite loop)
        my $self = shift;
        my $data = join ',', map { $_->[0] } $self->all_images;
        return $data;
    }
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

has upload_dir => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $cache_dir = path( $self->c->config->{UPLOAD_DIR} );
        $cache_dir->mkpath;
        unless ( -d $cache_dir && -w $cache_dir ) {
            warn "Can't find/write to photo cache directory '$cache_dir'";
            return;
        }
        $cache_dir;
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
        all_images => 'elements',
    },
    default => sub {
        my $self = shift;
        my @photos = $self->map_data_items( sub {
            my $part = $_;

            if (blessed $part and $part->isa('Catalyst::Request::Upload')) {
                # check that the photo is a jpeg
                my $upload = $part;
                my $ct = $upload->type;
                $ct =~ s/x-citrix-//; # Thanks, Citrix
                # Had a report of a JPEG from an Android 2.1 coming through as a byte stream
                unless ( $ct eq 'image/jpeg' || $ct eq 'image/pjpeg' || $ct eq 'application/octet-stream' ) {
                    my $c = $self->c;
                    $c->log->info('Bad photo tried to upload, type=' . $ct);
                    $c->stash->{photo_error} = _('Please upload a JPEG image only');
                    return ();
                }

                # get the photo into a variable
                my $photo_blob = eval {
                    my $filename = $upload->tempname;
                    my $out = `jhead -se -autorot $filename 2>&1`;
                    die _("Please upload a JPEG image only"."\n") if $out =~ /Not JPEG:/;
                    my $photo = $upload->slurp;
                };
                if ( my $error = $@ ) {
                    my $format = _(
            "That image doesn't appear to have uploaded correctly (%s), please try again."
                    );
                    $self->c->stash->{photo_error} = sprintf( $format, $error );
                    return ();
                }

                # we have an image we can use - save it to the upload dir for storage
                my $fileid = $self->get_fileid($photo_blob);
                my $file = $self->get_file($fileid);
                $upload->copy_to( $file );
                return [$fileid, $photo_blob];

            }
            if (_jpeg_magic($part)) {
                my $photo_blob = $part;
                my $fileid = $self->get_fileid($photo_blob);
                my $file = $self->get_file($fileid);
                $file->spew_raw($photo_blob);
                return [$fileid, $photo_blob];
            }
            if (length($part) == 40) {
                my $fileid = $part;
                my $file = $self->get_file($fileid);
                my $photo = $file->slurp_raw;
                [$fileid, $photo];
            }
            else {
                warn sprintf "Received bad photo hash of length %d", length($part);
                ();
            }
        });
        return \@photos;
    },
);

sub get_fileid {
    my ($self, $photo_blob) = @_;
    return sha1_hex($photo_blob);
}

sub get_file {
    my ($self, $fileid) = @_;
    my $cache_dir = $self->upload_dir;
    return path( $cache_dir, "$fileid.jpeg" );
}

sub get_image_data {
    my ($self, %args) = @_;
    my $num = $args{num} || 1;

    my $data = $self->get_raw_image_data( 0 ) # for test, because of broken IE/Windows caching
        or return;

    my ($fileid, $photo) = @$data;

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
