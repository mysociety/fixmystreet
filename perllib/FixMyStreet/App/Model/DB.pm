package FixMyStreet::App::Model::DB;
use base 'Catalyst::Model::DBIC::Schema';

use strict;
use warnings;

use FixMyStreet;

__PACKAGE__->config(
    schema_class => 'FixMyStreet::DB',
    connect_info => sub { FixMyStreet::DB->storage->dbh },
);

=head1 NAME

FixMyStreet::App::Model::DB - Catalyst DBIC Schema Model

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<FixMyStreet::DB>

=cut

1;
