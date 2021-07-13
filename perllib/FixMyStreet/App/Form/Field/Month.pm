package FixMyStreet::App::Form::Field::Month;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Text';

my $max = 12;

# The HTML::FormHandler Month field is a Select with twelve options,
# which prevents us accepting e.g. "04"

apply([
    {
        check   => sub { $_[0] >= 1 && $_[0] <= $max },
        message => "Please provide a month between 1 and $max",
    }
]);

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
