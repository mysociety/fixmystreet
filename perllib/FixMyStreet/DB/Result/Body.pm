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
  "send_extended_statuses",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "parent",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "deleted",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "external_url",
  { data_type => "text", is_nullable => 1 },
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
__PACKAGE__->has_many(
  "defect_types",
  "FixMyStreet::DB::Result::DefectType",
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
  "response_priorities",
  "FixMyStreet::DB::Result::ResponsePriority",
  { "foreign.body_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "response_templates",
  "FixMyStreet::DB::Result::ResponseTemplate",
  { "foreign.body_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "user_body_permissions",
  "FixMyStreet::DB::Result::UserBodyPermission",
  { "foreign.body_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "users",
  "FixMyStreet::DB::Result::User",
  { "foreign.from_body" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2017-02-13 15:11:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BOJANVwg3kR/1VjDq0LykA

sub url {
    my ( $self, $c, $args ) = @_;
    # XXX $areas_info was used here for Norway parent - needs body parents, I guess
    return $c->uri_for( '/reports/' . $c->cobrand->short_name( $self ), $args || {} );
}

sub areas {
    my $self = shift;
    my %ids = map { $_->area_id => 1 } $self->body_areas->all;
    return \%ids;
}

=head2 get_cobrand_handler

Get a cobrand object for this body, if there is one.

e.g.
    * if the problem was sent to Bromley it will return ::Bromley
    * if the problem was sent to Camden it will return nothing

=cut

sub get_cobrand_handler {
    my $self = shift;
    return FixMyStreet::Cobrand->body_handler($self->areas);
}

1;
