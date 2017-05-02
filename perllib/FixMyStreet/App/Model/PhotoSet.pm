package FixMyStreet::App::Model::PhotoSet;

# TODO this isn't a Cat model, rename to something else

use Moose;
use Path::Tiny 'path';

my $IM = eval {
    require Image::Magick;
    Image::Magick->import;
    1;
};

use Scalar::Util 'openhandle', 'blessed';
use Digest::SHA qw(sha1_hex);
use Image::Size;
use IPC::Cmd qw(can_run);
use IPC::Open3;
use MIME::Base64;

has c => (
    is => 'ro',
);

# The attached report, for using its ID
has object => (
    is => 'ro',
);

# If a PhotoSet is generated from a database row, db_data is set, which then
# fills data_items -> ids -> data. If it is generated during creation,
# data_items is set, which then similarly fills ids -> data.

has db_data => ( # generic data from DB field
    is => 'ro',
);

has data => ( # String of photo hashes
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $data = join ',', $self->all_ids;
        return $data;
    }
);

has data_items => ( # either a) split from db_data or b) provided by photo upload
    isa => 'ArrayRef',
    is => 'ro',
    traits => ['Array'],
    lazy => 1,
    handles => {
        map_data_items => 'map',
    },
    default => sub {
        my $self = shift;
        my $data = $self->db_data or return [];

        return [$data] if (detect_type($data));

        return [ split ',' => $data ];
    },
);

has upload_dir => (
    is => 'ro',
    lazy => 1,
    default => sub {
        path(FixMyStreet->config('UPLOAD_DIR'))->absolute(FixMyStreet->path_to());
    },
);

sub detect_type {
    return 'jpeg' if $_[0] =~ /^\x{ff}\x{d8}/;
    return 'png' if $_[0] =~ /^\x{89}\x{50}/;
    return 'tiff' if $_[0] =~ /^II/;
    return 'gif' if $_[0] =~ /^GIF/;
    return '';
}

=head2 C<ids>, C<num_images>, C<get_id>, C<all_ids>

C<$photoset-E<GT>ids> is an arrayref containing the fileid data.

    [ $fileid1, $fileid2, ... ]

Various accessors are provided onto it:

    num_images: count
    get_id ($index): return the correct id
    all_ids: array of elements, rather than arrayref

=cut

has ids => ( #  Arrayref of $fileid tuples (always, so post upload/raw data processing)
    isa => 'ArrayRef',
    is => 'ro',
    traits => ['Array'],
    lazy => 1,
    handles => {
        num_images => 'count',
        get_id => 'get',
        all_ids => 'elements',
    },
    default => sub {
        my $self = shift;
        my @photos = $self->map_data_items( sub {
            my $part = $_;

            if (blessed $part and $part->isa('Catalyst::Request::Upload')) {
                my $upload = $part;
                my $ct = $upload->type;
                $ct =~ s/x-citrix-//; # Thanks, Citrix
                my ($type) = $ct =~ m{image/(jpeg|pjpeg|gif|tiff|png)};
                $type = 'jpeg' if $type && $type eq 'pjpeg';
                # Had a report of a JPEG from an Android 2.1 coming through as a byte stream
                $type = 'jpeg' if !$type && $ct eq 'application/octet-stream';
                unless ( $type ) {
                    my $c = $self->c;
                    $c->log->info('Bad photo tried to upload, type=' . $ct);
                    $c->stash->{photo_error} = _('Please upload an image only');
                    return ();
                }

                # base64 decode the file if it's encoded that way
                # Catalyst::Request::Upload doesn't do this automatically
                # unfortunately.
                my $transfer_encoding = $upload->headers->header('Content-Transfer-Encoding');
                if (defined $transfer_encoding && $transfer_encoding eq 'base64') {
                    my $decoded = decode_base64($upload->slurp);
                    if (open my $fh, '>', $upload->tempname) {
                        binmode $fh;
                        print $fh $decoded;
                        close $fh
                    } else {
                        my $c = $self->c;
                        $c->log->info('Couldn\'t open temp file to save base64 decoded image: ' . $!);
                        $c->stash->{photo_error} = _("Sorry, we couldn't save your image(s), please try again.");
                        return ();
                    }
                }

                # get the photo into a variable
                my $photo_blob = eval {
                    my $filename = $upload->tempname;
                    my $out;
                    if ($type eq 'jpeg' && can_run('jhead')) {
                        my $pid = open3(undef, my $stdout, undef, 'jhead', '-se', '-autorot', $filename);
                        $out = join('', <$stdout>);
                        waitpid($pid, 0);
                        close $stdout;
                    }
                    unless (defined $out) {
                        my ($w, $h, $err) = Image::Size::imgsize($filename);
                        die _("Please upload an image only") . "\n" if !defined $w || $err !~ /JPG|GIF|PNG|TIF/;
                    }
                    die _("Please upload an image only") . "\n" if $out && $out =~ /Not JPEG:/;
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
                my $file = $self->get_file($fileid, $type);
                $upload->copy_to( $file );
                return $file->basename;

            }
            if (my $type = detect_type($part)) {
                my $photo_blob = $part;
                my $fileid = $self->get_fileid($photo_blob);
                my $file = $self->get_file($fileid, $type);
                $file->spew_raw($photo_blob);
                return $file->basename;
            }
            my ($fileid, $type) = split /\./, $part;
            $type ||= 'jpeg';
            if ($fileid && length($fileid) == 40) {
                my $file = $self->get_file($fileid, $type);
                $file->basename;
            } else {
                # A bad hash, probably a bot spamming with bad data.
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
    my ($self, $fileid, $type) = @_;
    my $cache_dir = $self->upload_dir;
    return path( $cache_dir, "$fileid.$type" );
}

sub get_raw_image {
    my ($self, $index) = @_;
    my $filename = $self->get_id($index);
    my ($fileid, $type) = split /\./, $filename;
    my $file = $self->get_file($fileid, $type);
    if ($file->exists) {
        my $photo = $file->slurp_raw;
        return {
            data => $photo,
            content_type => "image/$type",
            extension => $type,
        };
    }
}

sub get_image_data {
    my ($self, %args) = @_;
    my $num = $args{num} || 0;

    my $image = $self->get_raw_image( $num )
        or return;
    my $photo = $image->{data};

    my $size = $args{size};
    if ( $size eq 'tn' ) {
        $photo = _shrink( $photo, 'x100' );
    } elsif ( $size eq 'fp' ) {
        $photo = _crop( $photo );
    } elsif ( $size eq 'full' ) {
        # do nothing
    } else {
        $photo = _shrink( $photo, $args{default} || '250x250' );
    }

    return {
        data => $photo,
        content_type => $image->{content_type},
    };
}

sub delete_cached {
    my ($self) = @_;
    my $object = $self->object or return;
    my $id = $object->id or return;

    my @dirs = ('web', 'photo');
    push @dirs, 'c' if ref $object eq 'FixMyStreet::DB::Result::Comment';

    # Old files without an index number; will always be .jpeg
    foreach my $size ("", ".fp", ".tn", ".full") {
        unlink FixMyStreet->path_to(@dirs, "$id$size.jpeg");
    }

    # New files with index number
    my @images = $self->all_ids;
    foreach (map [ $_, $images[$_] ], 0 .. $#images) {
        my ($i, $file) = @$_;
        my ($fileid, $type) = split /\./, $file;
        foreach my $size ("", ".fp", ".tn", ".full") {
            unlink FixMyStreet->path_to(@dirs, "$id.$i$size.$type");
        }
    }
}

sub remove_images {
    my ($self, $ids) = @_;

    my @images = $self->all_ids;
    my $dec = 0;
    for (sort { $a <=> $b } @$ids) {
        splice(@images, $_ + $dec, 1);
        --$dec;
    }

    $self->delete_cached();

    return undef if !@images;

    my $new_set = (ref $self)->new({
        data_items => \@images,
        object => $self->object,
    });

    return $new_set->data; # e.g. new comma-separated fileid
}

sub rotate_image {
    my ($self, $index, $direction) = @_;

    my @images = $self->all_ids;
    return if $index > $#images;

    my $image = $self->get_raw_image($index);
    $images[$index] = _rotate_image( $image->{data}, $direction );

    my $new_set = (ref $self)->new({
        data_items => \@images,
        object => $self->object,
    });

    $self->delete_cached();

    return $new_set->data; # e.g. new comma-separated fileid
}

sub _rotate_image {
    my ($photo, $direction) = @_;
    return $photo unless $IM;
    my $image = Image::Magick->new;
    $image->BlobToImage($photo);
    my $err = $image->Rotate($direction);
    return 0 if $err;
    my @blobs = $image->ImageToBlob();
    undef $image;
    return $blobs[0];
}


# Shrinks a picture to the specified size, but keeping in proportion.
sub _shrink {
    my ($photo, $size) = @_;
    return $photo unless $IM;
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
    return $photo unless $IM;
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
