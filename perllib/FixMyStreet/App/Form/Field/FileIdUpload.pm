=head1 NAME

FixMyStreet::App::Form::Field::FileIdUpload - file upload field via ID

=head1 SYNOPSIS

Our Forms upload files by storing them in the upload directory and then using a
hash of the contents as the ID to pass around in multi-step forms etc. Here we
subclass the Upload field to validate the presence of the data in the various
places it could be, not assuming an Upload object is supplied as the default.

=head1 DESCRIPTION

=cut

package FixMyStreet::App::Form::Field::FileIdUpload;
use Moose;

extends 'HTML::FormHandler::Field::Upload';

=head2 validate

If we've explicitly said the field is not required, we don't perform any validation.

Otherwise we check we've got something saved in either C<< $self->value >> (the field
itself), C<< $self->form->saved_data->{$self->name} >> (saved from the previous step),
or C<< $self->form->params >> (not uploaded, but ID saved in a previous step).

We also check the file isn't zero in size at this point.

=cut

sub validate {
    my ($self) = @_;

    return if $self->tag_exists('required') && !$self->get_tag('required');

    my $key = ( defined $self->value && defined $self->value->{files}
                && $self->value->{files} )
            || ( defined $self->form->saved_data->{$self->name}->{files}
                && $self->form->saved_data->{$self->name}->{files} )
            || $self->form->params->{$self->name . '_fileid'};

    return $self->add_error($self->get_message('upload_file_not_found'))
        unless $key;

    my $out = $self->form->upload_dir->child($key);
    unless ($out->size) {
        return $self->add_error($self->get_message('upload_file_too_small'));
    }
}

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
