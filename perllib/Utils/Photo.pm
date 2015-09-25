package Utils::Photo;

use Image::Size;

=head2 get_photo_params

Returns a hashref of details of any attached photo for use in templates.
Hashref contains height, width and url keys.

=cut

sub get_photo_params {
    my ($self, $key) = @_;

    return {} unless $self->photo;

    $key = ($key eq 'id') ? '' : "/$key";

    my $pre = "/photo$key/" . $self->id;
    my $post = '.jpeg';
    my $photo = {};

    if (length($self->photo) == 40) {
        $post .= '?' . $self->photo;
        $photo->{url_full} = "$pre.full$post";
        # XXX Can't use size here because {url} (currently 250px height) may be
        # being used, but at this point it doesn't yet exist to find the width
        # $str = FixMyStreet->config('UPLOAD_DIR') . $self->photo . '.jpeg';
    } else {
        my $str = \$self->photo;
        ( $photo->{width}, $photo->{height} ) = Image::Size::imgsize( $str );
    }

    $photo->{url} = "$pre$post";
    $photo->{url_tn} = "$pre.tn$post";
    $photo->{url_fp} = "$pre.fp$post";

    return $photo;
}

1;
