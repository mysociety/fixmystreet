package FixMyStreet::SendReport;

use Moose;

use Module::Pluggable
    sub_name    => 'senders',
    search_path => __PACKAGE__,
    require     => 1;

has 'body_config' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'bodies' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has 'to' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has 'success' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'error' => ( is => 'rw', isa => 'Str', default => '' );
has 'skipped' => ( 'is' => 'rw', isa => 'Str', default => '' );
has 'unconfirmed_counts' => ( 'is' => 'rw', isa => 'HashRef', default => sub { {} } );
has 'unconfirmed_notes' => ( 'is' => 'rw', isa => 'HashRef', default => sub { {} } );


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

    $self->bodies( [] );
    $self->body_config( {} );
    $self->to( [] );
}

sub add_body {
    my $self = shift;
    my $body = shift;
    my $config = shift;

    push @{$self->bodies}, $body;
    $self->body_config->{ $body->id } = $config;
}

1;
