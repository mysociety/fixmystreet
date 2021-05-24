package FixMyStreet::App::Form::Field::MonthDay;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Text';

my $max = 31;

apply([
    {
        check   => sub { $_[0] >= 1 && $_[0] <= $max },
        message => "Please provide a day between 1 and $max",
    }
]);

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
