package FixMyStreet::ImageMagick;

use Moo;

my $IM = eval {
    return 0 if FixMyStreet->test_mode;
    require Image::Magick;
    Image::Magick->import;
    1;
};

has blob => ( is => 'ro' );

has image => (
    is => 'rwp',
    lazy => 1,
    default => sub {
        my $self = shift;
        return unless $IM;
        my $image = Image::Magick->new;
        $image->BlobToImage($self->blob);
        return $image;
    },
);

sub strip {
    my $self = shift;
    return $self unless $self->image;
    $self->image->Strip();
    return $self;
}

sub rotate {
    my ($self, $direction) = @_;
    return $self unless $self->image;
    my $err = $self->image->Rotate($direction);
    return 0 if $err;
    return $self;
}

# Shrinks a picture to the specified size, but keeping in proportion.
sub shrink {
    my ($self, $size) = @_;
    return $self unless $self->image;
    my $err = $self->image->Scale(geometry => "$size>");
    throw Error::Simple("resize failed: $err") if "$err";
    return $self->strip;
}

# Shrinks a picture to 90x60, cropping so that it is exactly that.
sub crop {
    my $self = shift;
    return $self unless $self->image;
    my $err = $self->image->Resize( geometry => "90x60^" );
    throw Error::Simple("resize failed: $err") if "$err";
    $err = $self->image->Extent( geometry => '90x60', gravity => 'Center' );
    throw Error::Simple("resize failed: $err") if "$err";
    return $self->strip;
}

sub as_blob {
    my $self = shift;
    return $self->blob unless $self->image;
    my @blobs = $self->image->ImageToBlob();
    $self->_set_image(undef);
    return $blobs[0];
}

1;
