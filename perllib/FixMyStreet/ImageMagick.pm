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

has width => (
    is => 'rwp',
    lazy => 1,
    default => sub {
        my $self = shift;
        return unless $self->image;
        return $self->image->Get('width');
    }
);

has height => (
    is => 'rwp',
    lazy => 1,
    default => sub {
        my $self = shift;
        return unless $self->image;
        return $self->image->Get('height');
    }
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
    $self->_set_width_and_height();
    return $self;
}

# Shrinks a picture to the specified size, but keeping in proportion.
sub shrink {
    my ($self, $size) = @_;
    return $self unless $self->image;
    my $err = $self->image->Scale(geometry => "$size>");
    throw Error::Simple("resize failed: $err") if "$err";
    $self->_set_width_and_height();
    return $self->strip;
}

# Shrinks a picture to a given dimension (defaults to 90x60(, cropping so that
# it is exactly that.
sub crop {
    my ($self, $size) = @_;
    $size //= '90x60';
    return $self unless $self->image;
    my $err = $self->image->Resize( geometry => "$size^" );
    throw Error::Simple("resize failed: $err") if "$err";
    $err = $self->image->Extent( geometry => $size, gravity => 'Center' );
    throw Error::Simple("resize failed: $err") if "$err";
    $self->_set_width_and_height();
    return $self->strip;
}

sub as_blob {
    my $self = shift;
    return $self->blob unless $self->image;
    my @blobs = $self->image->ImageToBlob();
    $self->_set_width_and_height();
    $self->_set_image(undef);
    return $blobs[0];
}

sub _set_width_and_height {
    my $self = shift;
    return unless $self->image;
    my ($width, $height) = $self->image->Get('width', 'height');
    $self->_set_width($width);
    $self->_set_height($height);
}

1;
