package FixMyStreet::App::Form::Field::FileIdPhoto;
use Moose;

extends 'HTML::FormHandler::Field::Hidden';
use Lingua::EN::Inflect qw( NUMWORDS );
use mySociety::Locale;

sub build_tags {
    { hide => 1 }
}

has linked_field => ( is => 'ro' );

has num_photos_required => ( is => 'ro' );

has '+validate_when_empty' => ( default => 1 );

sub validate {
    my $self = shift;
    my $field = $self->linked_field;
    $self->form->process_photo($field);
    my $value = $self->form->saved_data->{$field};
    my @parts = split /,/, ( $value // '' );
    if ($self->num_photos_required && scalar @parts != $self->num_photos_required) {
        my $num = $self->num_photos_required;
        my $word = NUMWORDS($num);
        my $error = sprintf(mySociety::Locale::nget("Please supply %s photo", "Please supply %s photos", $num), $word);
        $self->add_error($error);
    }
}

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
