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

sub redact {
    my ($self, $rects, $size) = @_;
    return $self unless $self->image;
    my ($width, $height) = $self->image->Get('width', 'height');
    my $ratio = $width / $size->{width};
    foreach (@$rects) {
        my $l = int($_->{x} * $ratio + 0.5);
        my $t = int($_->{y} * $ratio + 0.5);
        my $r = int(($_->{x} + $_->{w}) * $ratio + 0.5);
        my $b = int(($_->{y} + $_->{h}) * $ratio + 0.5);
        my $points = "$l,$t $r,$b";
        $self->image->Draw( fill => 'black', primitive => 'rectangle', points => $points );
    }
    return $self;
}

# Shrinks a picture to the specified size, but keeping in proportion.
sub shrink {
    my ($self, $size) = @_;
    return $self unless $self->image;
    my $err = $self->image->Scale(geometry => "$size>");
    die "resize failed: $err" if "$err";
    return $self->strip;
}

# Shrinks a picture to the specified percentage of the original, but keeping in proportion.
sub shrink_to_percentage {
    my ($self, $percentage) = @_;
    $self->image->Scale(geometry => "$percentage%");
    return $self;
}

# Shrinks a picture to a given dimension (defaults to 90x60(, cropping so that
# it is exactly that.
sub crop {
    my ($self, $size) = @_;
    $size //= '90x60';
    return $self unless $self->image;
    my $err = $self->image->Resize( geometry => "$size^" );
    die "resize failed: $err" if "$err";
    $err = $self->image->Extent( geometry => $size, gravity => 'Center' );
    die "resize failed: $err" if "$err";
    return $self->strip;
}

sub as_blob {
    my $self = shift;
    my %params = @_;
    return $self->blob unless $self->image;
    my @blobs = $self->image->ImageToBlob(%params);
    $self->_set_image(undef);
    return $blobs[0];
}

1;
