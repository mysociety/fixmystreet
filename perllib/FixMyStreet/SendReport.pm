package FixMyStreet::SendReport;

use Moose;

has 'councils' => (is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'to' => (is => 'rw', isa => 'ArrayRef', default => sub { [] } );

sub reset {
    my $self = shift;

    $self->councils( {} );
    $self->to( [] );
}

sub add_council {
    my $self = shift;
    my $council = shift;
    my $name = shift;

    $self->councils->{ $council } = $name;
}


1;
