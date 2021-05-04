package FixMyStreet::App::Form::Field::FileIdPhoto;
use Moose;

extends 'HTML::FormHandler::Field::Hidden';

sub build_tags {
    { hide => 1 }
}

has linked_field => ( is => 'ro' );

has '+validate_when_empty' => ( default => 1 );

sub validate {
    my $self = shift;
    my $field = $self->linked_field;
    $self->form->process_photo($field);
    my $value = $self->form->saved_data->{$field};
    my @parts = split(/,/, $value);
    $self->add_error('Please supply two photos') unless scalar @parts == 2;
}

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
