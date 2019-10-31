use utf8;
package FixMyStreet::DB::Result::Contact;

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
__PACKAGE__->table("contacts");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "contacts_id_seq",
  },
  "body_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "category",
  { data_type => "text", default_value => "Other", is_nullable => 0 },
  "email",
  { data_type => "text", is_nullable => 0 },
  "state",
  { data_type => "text", is_nullable => 0 },
  "editor",
  { data_type => "text", is_nullable => 0 },
  "whenedited",
  { data_type => "timestamp", is_nullable => 0 },
  "note",
  { data_type => "text", is_nullable => 0 },
  "extra",
  { data_type => "text", is_nullable => 1 },
  "non_public",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "endpoint",
  { data_type => "text", is_nullable => 1 },
  "jurisdiction",
  { data_type => "text", default_value => "", is_nullable => 1 },
  "api_key",
  { data_type => "text", default_value => "", is_nullable => 1 },
  "send_method",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("contacts_body_id_category_idx", ["body_id", "category"]);
__PACKAGE__->belongs_to(
  "body",
  "FixMyStreet::DB::Result::Body",
  { id => "body_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "contact_defect_types",
  "FixMyStreet::DB::Result::ContactDefectType",
  { "foreign.contact_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "contact_response_priorities",
  "FixMyStreet::DB::Result::ContactResponsePriority",
  { "foreign.contact_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "contact_response_templates",
  "FixMyStreet::DB::Result::ContactResponseTemplate",
  { "foreign.contact_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-04-25 12:06:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:f7XjQj4iABikbR4EZrjL3g

__PACKAGE__->load_components("+FixMyStreet::DB::RABXColumn");
__PACKAGE__->rabx_column('extra');

use Moo;
use namespace::clean -except => [ 'meta' ];

with 'FixMyStreet::Roles::Extra',
    'FixMyStreet::Roles::Translatable';

__PACKAGE__->many_to_many( response_templates => 'contact_response_templates', 'response_template' );
__PACKAGE__->many_to_many( response_priorities => 'contact_response_priorities', 'response_priority' );
__PACKAGE__->many_to_many( defect_types => 'contact_defect_types', 'defect_type' );

__PACKAGE__->might_have(
  "translations",
  "FixMyStreet::DB::Result::Translation",
  sub {
    my $args = shift;
    return {
        "$args->{foreign_alias}.object_id" => { -ident => "$args->{self_alias}.id" },
        "$args->{foreign_alias}.tbl" => { '=' => \"?" },
        "$args->{foreign_alias}.col" => { '=' => \"?" },
        "$args->{foreign_alias}.lang" => { '=' => \"?" },
    };
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

sub category_display {
    my $self = shift;
    $self->get_extra_metadata('display_name') || $self->translate_column('category');
}

sub groups {
    my $self = shift;
    my $groups = $self->get_extra_metadata('group') || [];
    $groups = [ $groups ] unless ref $groups eq 'ARRAY';
    return $groups;
}

sub get_all_metadata {
    my $self = shift;
    my @metadata = @{$self->get_extra_fields};

    # Just in case the extra data is in an old parsed format
    foreach (@metadata) {
        if (ref $_->{values} eq 'HASH') {
            $_->{values} = [ map { { name => $_->{name}[0], key => $_->{key}[0] } } @{$_->{values}->{value}} ];
        }
    }
    return \@metadata;
}

sub get_metadata_for_editing {
    my $self = shift;
    my $metadata = $self->get_all_metadata;

    # Ignore the special admin-form-created entry
    my @metadata = grep { $_->{code} ne '_fms_disable_' } @$metadata;

    return \@metadata;
}

sub get_metadata_for_input {
    my $self = shift;
    my $metadata = $self->get_all_metadata;

    # Also ignore any we have with a 'server_set' automated attribute
    my @metadata = grep { !$_->{automated} || $_->{automated} ne 'server_set' } @$metadata;

    return \@metadata;
}

sub get_metadata_for_storage {
    my $self = shift;
    my $metadata = $self->get_metadata_for_input;

    # Also ignore any that were only for textual display
    my @metadata = grep { ($_->{variable} || '') ne 'false' } @$metadata;

    return \@metadata;
}

sub id_field {
    my $self = shift;
    return $self->get_extra_metadata('id_field') || 'fixmystreet_id';
}

sub disable_form_field {
    my $self = shift;
    my $metadata = $self->get_all_metadata;
    my ($field) = grep { $_->{code} eq '_fms_disable_' } @$metadata;
    return $field;
}

1;
