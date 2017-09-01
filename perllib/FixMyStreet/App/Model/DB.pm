package FixMyStreet::App::Model::DB;
use base 'Catalyst::Model::DBIC::Schema';

use strict;
use warnings;

use FixMyStreet;
use Catalyst::Utils;
use Moose;

with 'Catalyst::Component::InstancePerContext';

__PACKAGE__->config(
    schema_class => 'FixMyStreet::DB::Schema',
    connect_info => sub { FixMyStreet::DB->schema->storage->dbh },
);
__PACKAGE__->config(
    traits => ['QueryLog::AdoptPlack'],
)
    if Catalyst::Utils::env_value( 'FixMyStreet::App', 'DEBUG' );

sub build_per_context_instance {
    my ( $self, $c ) = @_;
    # $self->schema->cobrand($c->cobrand);
    $self->schema->cache({});
    return $self;
}

=head1 NAME

FixMyStreet::App::Model::DB - Catalyst DBIC Schema Model

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<FixMyStreet::DB::Schema>

=cut

1;
