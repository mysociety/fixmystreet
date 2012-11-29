use utf8;
package FixMyStreet::DB::Result::FmgMunicipality;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

FixMyStreet::DB::Result::FmgMunicipality

=cut

__PACKAGE__->table("fmg_municipalities");

=head1 ACCESSORS

=head2 mapit_id

  data_type: 'integer'
  is_nullable: 0

=head2 mapit_name

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 url

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=cut

__PACKAGE__->add_columns(
  "mapit_id",
  { data_type => "integer", is_nullable => 0 },
  "mapit_name",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "url",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("mapit_id");


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2012-11-29 13:11:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DurC6BAuTuXZaZVAVHi+Kg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
