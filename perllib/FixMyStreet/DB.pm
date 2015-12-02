use utf8;
package FixMyStreet::DB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07017 @ 2012-03-08 17:19:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CjFpUvon7KggFM7OF7VK/w

use FixMyStreet;

__PACKAGE__->connection(FixMyStreet->dbic_connect_info);

1;
