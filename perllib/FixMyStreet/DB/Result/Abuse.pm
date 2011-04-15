package FixMyStreet::DB::Result::Abuse;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn");
__PACKAGE__->table("abuse");
__PACKAGE__->add_columns( "email", { data_type => "text", is_nullable => 0 } );
__PACKAGE__->set_primary_key("email");

# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-04-15 12:11:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:J3vO9UpeoxI19WPRmEaI0w

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
