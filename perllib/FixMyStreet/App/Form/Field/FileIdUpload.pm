package FixMyStreet::App::Form::Field::FileIdUpload;
use Moose;

extends 'HTML::FormHandler::Field::Upload';

sub validate {
    my ($self) = @_;

    return if $self->tag_exists('required') && !$self->get_tag('required');
    return $self->add_error($self->get_message('upload_file_not_found'))
        unless ( defined $self->value && defined $self->value->{files}
                && $self->value->{files} )
            || ( defined $self->form->saved_data->{$self->name}->{files}
                && $self->form->saved_data->{$self->name}->{files} )
            || $self->form->params->{$self->name . '_fileid'};
}

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
