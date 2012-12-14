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
  "name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
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
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);
__PACKAGE__->has_many(
  "contacts",
  "FixMyStreet::DB::Result::Contact",
  { "foreign.body_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "users",
  "FixMyStreet::DB::Result::User",
  { "foreign.from_body" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07017 @ 2012-12-14 17:54:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2Z3gCosNomCTcjrwWy/RNA

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
