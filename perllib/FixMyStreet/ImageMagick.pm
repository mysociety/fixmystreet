package FixMyStreet::ImageMagick;

use FixMyStreet;
use Moo;
use Image::Size;
use IPC::Open2;

my $IM = eval {
    return 0 if FixMyStreet->test_mode;
    require Image::Magick;
    Image::Magick->import;
    1;
};

has blob => ( is => 'rwp' );

has dimensions => (
    is => 'rwp',
    lazy => 1,
    builder => 1,
);

sub _build_dimensions {
    my $self = shift;
    return [] unless $self->blob;
    my ($x, $y, $typ) = Image::Size::imgsize(\$self->blob);
    return [ $x, $y ];
}

sub update_dimensions {
    my $self = shift;
    $self->_set_dimensions($self->_build_dimensions);
}

sub width {
    my $self = shift;
    return $self->dimensions->[0];
}

sub height {
    my $self = shift;
    return $self->dimensions->[1];
}

sub rotate {
    my ($self, $direction) = @_;
    return $self unless $IM;
    my $pid = open2(my $chld_out, my $chld_in, 'convert', '-', '-rotate', $direction, '-');
    print $chld_in $self->blob;
    close $chld_in;
    my $converted = join('', <$chld_out>);
    close $chld_out;
    $self->_set_blob($converted);
    $self->update_dimensions;
    return $self;
}

sub redact {
    my ($self, $rects, $size) = @_;
    return $self unless $IM;
    my ($width, $height) = ($self->width, $self->height);
    my $ratio = $width / $size->{width};
    my @cmd = ('convert', '-');
    foreach (@$rects) {
        my $l = int($_->{x} * $ratio + 0.5);
        my $t = int($_->{y} * $ratio + 0.5);
        my $r = int(($_->{x} + $_->{w}) * $ratio + 0.5);
        my $b = int(($_->{y} + $_->{h}) * $ratio + 0.5);
        my $points = "$l,$t $r,$b";
        push @cmd, '-fill', 'black', '-draw', "rectangle $points";
    }
    my $pid = open2(my $chld_out, my $chld_in, @cmd, '-');
    print $chld_in $self->blob;
    close $chld_in;
    my $converted = join('', <$chld_out>);
    close $chld_out;
    $self->_set_blob($converted);
    return $self;
}

# Shrinks a picture to the specified size, but keeping in proportion.
sub shrink {
    my ($self, $size) = @_;
    return $self unless $IM;
    my $pid = open2(my $chld_out, my $chld_in, 'convert', '-', '-scale', "$size>", '-strip', '-');
    print $chld_in $self->blob;
    close $chld_in;
    my $converted = join('', <$chld_out>);
    close $chld_out;
    $self->_set_blob($converted);
    $self->update_dimensions;
    return $self;
}

# Shrinks a picture to a given dimension (defaults to 90x60), cropping so that
# it is exactly that.
sub crop {
    my ($self, $size) = @_;
    $size //= '90x60';
    return $self unless $IM;
    my $pid = open2(my $chld_out, my $chld_in, 'convert', '-', '-resize', "$size^", '-gravity', 'Center', '-extent', $size, '-strip', '-');
    print $chld_in $self->blob;
    close $chld_in;
    my $converted = join('', <$chld_out>);
    close $chld_out;
    $self->_set_blob($converted);
    $self->update_dimensions;
    return $self;
}

sub as_blob {
    my $self = shift;
    return $self->blob;
}

1;
