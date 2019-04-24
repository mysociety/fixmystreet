package FixMyStreet::Roles::PhotoSet;
use Moo::Role;

=head1 NAME

FixMyStreet::Roles::Photoset - role for accessing photosets

=cut

=head2 get_photoset

Return a PhotoSet object for all photos attached to this field

    my $photoset = $obj->get_photoset;
    print $photoset->num_images;
    return $photoset->get_image_data(num => 0, size => 'full');

=cut

sub get_photoset {
    my ($self) = @_;
    require FixMyStreet::App::Model::PhotoSet;
    return FixMyStreet::App::Model::PhotoSet->new({
        db_data => $self->photo,
        object => $self,
    });
}

sub get_first_image_fp {
    my ($self) = @_;
    return $self->get_photoset->get_image_data( num => 0, size => 'fp' );
}

sub photos {
    my $self = shift;
    my $photoset = $self->get_photoset;
    my $i = 0;
    my $id = $self->id;
    my $typ = $self->result_source->name eq 'comment' ? 'c/' : '';

    my @photos = map {
        my $cachebust = substr($_, 0, 8);
        # Some Varnish configurations (e.g. on mySociety infra) strip cookies from
        # images, which means image requests will be redirected to the login page
        # if LOGIN_REQUIRED is set. To stop this happening, Varnish should be
        # configured to not strip cookies if the cookie_passthrough param is
        # present, which this line ensures will be if LOGIN_REQUIRED is set.
        my $extra = '';
        if (FixMyStreet->config('LOGIN_REQUIRED')) {
            $cachebust .= '&cookie_passthrough=1';
            $extra = '?cookie_passthrough=1';
        }
        my ($hash, $format) = split /\./, $_;
        {
            id => $hash,
            url_temp => "/photo/temp.$hash.$format$extra",
            url_temp_full => "/photo/fulltemp.$hash.$format$extra",
            url => "/photo/$typ$id.$i.$format?$cachebust",
            url_full => "/photo/$typ$id.$i.full.$format?$cachebust",
            url_tn => "/photo/$typ$id.$i.tn.$format?$cachebust",
            url_fp => "/photo/$typ$id.$i.fp.$format?$cachebust",
            idx => $i++,
        }
    } $photoset->all_ids;
    return \@photos;
}

1;
