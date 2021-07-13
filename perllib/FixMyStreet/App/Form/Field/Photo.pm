package FixMyStreet::App::Form::Field::Photo;

use Moose;
extends 'HTML::FormHandler::Field';


has '+widget' => ( default => 'Upload' );
has '+type_attr' => ( default => 'file' );

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
