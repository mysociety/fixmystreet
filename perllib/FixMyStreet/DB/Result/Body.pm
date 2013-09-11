use utf8;
package FixMyStreet::DB::Result::Body;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("body");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "body_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "parent",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "endpoint",
  { data_type => "text", is_nullable => 1 },
  "jurisdiction",
  { data_type => "text", is_nullable => 1 },
  "api_key",
  { data_type => "text", is_nullable => 1 },
  "send_method",
  { data_type => "text", is_nullable => 1 },
  "send_comments",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "comment_user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "suppress_alerts",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "can_be_devolved",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "send_extended_statuses",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "deleted",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "bodies",
  "FixMyStreet::DB::Result::Body",
  { "foreign.parent" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "body_areas",
  "FixMyStreet::DB::Result::BodyArea",
  { "foreign.body_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "comment_user",
  "FixMyStreet::DB::Result::User",
  { id => "comment_user_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "contacts",
  "FixMyStreet::DB::Result::Contact",
  { "foreign.body_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "parent",
  "FixMyStreet::DB::Result::Body",
  { id => "parent" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "users",
  "FixMyStreet::DB::Result::User",
  { "foreign.from_body" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-09-10 18:11:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hTOxxiiHmC8nmQK/p8dXhQ

sub url {
    my ( $self, $c ) = @_;
    # XXX $areas_info was used here for Norway parent - needs body parents, I guess
    return $c->uri_for( '/reports/' . $c->cobrand->short_name( $self ) );
}

sub areas {
    my $self = shift;
    my %ids = map { $_->area_id => 1 } $self->body_areas->all;
    return \%ids;
}

1;
