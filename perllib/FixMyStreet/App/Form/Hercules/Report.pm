package FixMyStreet::App::Form::Hercules::Report;

use utf8;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

sub validate {
    my $self = shift;
    my $any = 0;
    foreach ($self->all_fields) {
        $any = 1 if $_->name =~ /^service-/ && $_->value;
    }
    $self->add_form_error('Please specify what was missed')
        unless $any;
}

1;

