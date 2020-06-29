package FixMyStreet::App::Form::Waste::Request;

use utf8;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

sub validate {
    my $self = shift;
    my $any = 0;
    foreach ($self->all_fields) {
        $any = 1 if $_->name =~ /^container-/ && $_->value;
    }
    $self->add_form_error('Please specify what you need')
        unless $any;
}

1;
