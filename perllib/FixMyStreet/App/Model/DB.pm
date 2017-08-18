package FixMyStreet::App::Model::DB;
use base 'Catalyst::Model::DBIC::Schema';

use strict;
use warnings;

use FixMyStreet;
use Moose;

with 'Catalyst::Component::InstancePerContext';

__PACKAGE__->config(
    schema_class => 'FixMyStreet::DB::Schema',
    connect_info => sub { FixMyStreet::DB->schema->storage->dbh },
);

sub build_per_context_instance {
    my ( $self, $c ) = @_;
    $self->schema->cache({});
    return $self;
}

=head1 NAME

FixMyStreet::App::Model::DB - Catalyst DBIC Schema Model

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<FixMyStreet::DB::Schema>

=cut

1;
