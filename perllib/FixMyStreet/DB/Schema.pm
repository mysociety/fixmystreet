use utf8;
package FixMyStreet::DB::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces(
    result_namespace => "+FixMyStreet::DB::Result",
    resultset_namespace => "+FixMyStreet::DB::ResultSet",
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2017-07-13 14:15:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:UpH30RXb6SbCqRv2FPmpkg

use Moo;
use FixMyStreet;

__PACKAGE__->storage_type('::DBI::PgServerCursor');
__PACKAGE__->connection(FixMyStreet->dbic_connect_info);

has lang => ( is => 'rw' );

has cobrand => ( is => 'rw' );

has cache => ( is => 'rw', lazy => 1, default => sub { {} } );

1;
