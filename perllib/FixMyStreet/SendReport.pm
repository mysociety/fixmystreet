package FixMyStreet::SendReport;

use Moose;

use Module::Pluggable
    sub_name    => 'senders',
    search_path => __PACKAGE__,
    require     => 1;

has 'councils' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'to' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has 'success' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'error' => ( is => 'rw', isa => 'Str', default => '' );
has 'skipped' => ( 'is' => 'rw', isa => 'Str', default => '' );


sub should_skip {
    return 0;
}

sub get_senders {
    my $self = shift;

    my %senders = map { $_ => 1 } $self->senders;

    return \%senders;
}

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
