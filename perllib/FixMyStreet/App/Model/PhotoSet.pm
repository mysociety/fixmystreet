package FixMyStreet::App::Model::PhotoSet;

# TODO this isn't a Cat model, rename to something else

use Moose;

use Scalar::Util 'openhandle', 'blessed';
use Image::Size;
use IPC::Cmd qw(can_run);
use IPC::Open3;

use FixMyStreet;
use FixMyStreet::ImageMagick;
use FixMyStreet::PhotoStorage;

# Attached Catalyst app, if present, for feeding back errors during photo upload
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

        return [$data] if ($self->storage->detect_type($data));

        return [ split ',' => $data ];
    },
);

has storage => (
    is => 'ro',
    lazy => 1,
    default => sub {
        return FixMyStreet::PhotoStorage::backend;
    }
);

has symlinkable => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
        return $cfg ? $cfg->{SYMLINK_FULL_SIZE} : 0;
    }
);

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

                # Make sure any base64 encoding is handled.
                FixMyStreet::PhotoStorage::base64_decode_upload($self->c, $upload);

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

                # we have an image we can use - save it to storage
                $photo_blob = FixMyStreet::ImageMagick->new(blob => $photo_blob)->shrink('2048x2048')->as_blob;
                return $self->storage->store_photo($photo_blob);
            }

            # It might be a raw file stored in the DB column...
            if (my $type = $self->storage->detect_type($part)) {
                my $photo_blob = $part;
                return $self->storage->store_photo($photo_blob);
                # TODO: Should this update the DB record with a pointer to the
                # newly-stored file, instead of leaving it in the DB?
            }

            if (my $key = $self->storage->validate_key($part)) {
                $key;
            } else {
                # A bad hash, probably a bot spamming with bad data.
                ();
            }
        });
        return \@photos;
    },
);

sub get_raw_image {
    my ($self, $index) = @_;
    my $filename = $self->get_id($index);
    my ($photo, $type, $object) = $self->storage->retrieve_photo($filename);
    if ($photo) {
        return {
            $object ? (object => $object) : (),
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

    my $size = $args{size};

    if ($self->symlinkable && $image->{object} && $size eq 'full') {
        $image->{symlink} = delete $image->{object};
        return $image;
    }

    my $im = FixMyStreet::ImageMagick->new(blob => $image->{data});
    my $photo;
    if ( $size eq 'tn' ) {
        $photo = $im->shrink('x100');
    } elsif ( $size eq 'fp' ) {
        $photo = $im->crop;
    } elsif ( $size eq 'og' ) {
        $photo = $im->crop('1200x630');
    } elsif ( $size eq 'full' ) {
        $photo = $im
    } else {
        $photo = $im->shrink($args{default} || '250x250');
    }

    return {
        data => $photo->as_blob,
        width => $photo->width,
        height => $photo->height,
        content_type => $image->{content_type},
    };
}

sub delete_cached {
    my ($self, %params) = @_;
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

    # Loop through all the updates as well if requested
    if ($params{plus_updates}) {
        $_->get_photoset->delete_cached() foreach $object->comments->all;
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
    $images[$index] = FixMyStreet::ImageMagick->new(blob => $image->{data})->rotate($direction)->as_blob;

    my $new_set = (ref $self)->new({
        data_items => \@images,
        object => $self->object,
    });

    $self->delete_cached();

    return $new_set->data; # e.g. new comma-separated fileid
}

1;
