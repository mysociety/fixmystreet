use utf8;
package FixMyStreet::DB::Result::State;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components(
  "FilterColumn",
  "FixMyStreet::InflateColumn::DateTime",
  "FixMyStreet::EncodedColumn",
);
__PACKAGE__->table("state");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "state_id_seq",
  },
  "label",
  { data_type => "text", is_nullable => 0 },
  "type",
  { data_type => "text", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("state_label_key", ["label"]);
__PACKAGE__->add_unique_constraint("state_name_key", ["name"]);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-04-25 12:06:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:f/QeR3FYL/4wIGRu3c/C/A

use Moo;
use namespace::clean;

with 'FixMyStreet::Roles::Translatable';

sub msgstr {
    my $self = shift;
    my $lang = $self->result_source->schema->lang;
    return $self->name unless $lang && $self->translated->{name}{$lang};
    return $self->translated->{name}{$lang}{msgstr};
}

1;
