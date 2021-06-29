package FixMyStreet::App::Form::Field::DOBYear;
use Moose;
extends 'HTML::FormHandler::Field::IntRange';

has min_age => ( is => 'ro', default => 16 );

has '+range_start' => (
    default => sub {
        return 1900;
    }
);
has '+range_end' => (
    default => sub {
        my $self = shift;
        my $year = (localtime)[5] - $self->min_age + 1900;
        return $year;
    }
);


__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
