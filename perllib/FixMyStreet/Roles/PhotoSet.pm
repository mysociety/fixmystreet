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
    my $class = 'FixMyStreet::App::Model::PhotoSet';
    eval "use $class";
    return $class->new({
        db_data => $self->photo,
        object => $self,
    });
}

sub get_first_image_fp {
    my ($self) = @_;
    return $self->get_photoset->get_image_data( num => 0, size => 'fp' );
}

1;
