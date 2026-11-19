use utf8;
package FixMyStreet::DB::Result::AdminLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components(
  "FilterColumn",
  "+FixMyStreet::DB::JSONBColumn",
  "FixMyStreet::InflateColumn::DateTime",
  "FixMyStreet::EncodedColumn",
);
__PACKAGE__->table("admin_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "admin_log_id_seq",
  },
  "admin_user",
  { data_type => "text", is_nullable => 0 },
  "object_type",
  { data_type => "text", is_nullable => 0 },
  "object_id",
  { data_type => "integer", is_nullable => 0 },
  "action",
  { data_type => "text", is_nullable => 0 },
  "whenedited",
  {
    data_type     => "timestamp",
    default_value => \"CURRENT_TIMESTAMP",
    is_nullable   => 0,
  },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "reason",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "time_spent",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "user",
  "FixMyStreet::DB::Result::User",
  { id => "user_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2020-10-14 22:49:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nJv8L2Ggpe1F11T59Bdg3A

my %JOINS = (
    problem => 'Problem',
    comment => 'Comment',
    user_object => 'User',
    moderation => 'ModerationOriginalData',
    template => 'ResponseTemplate',
    body => 'Body',
    category => 'Contact',
    role => 'Role',
    manifesttheme => 'ManifestTheme',
    # property => 'Property', TODO would need work as uprn primary key, and nothing to fetch anyway
);
foreach my $join (keys %JOINS) {
    my $type = $join;
    $type = 'user' if $join eq 'user_object';
    $type = 'update' if $join eq 'comment';
    __PACKAGE__->might_have(
      $join => "FixMyStreet::DB::Result::$JOINS{$join}",
      sub {
        my $args = shift;
        return
            \[ "($args->{self_alias}.object_type = '$type' AND $args->{self_alias}.object_id = $args->{foreign_alias}.id)" ];
      },
      {
        join_type => "LEFT",
        on_delete => "NO ACTION",
        on_update => "NO ACTION",
      },
    );
}

sub link {
    my $self = shift;

    my $type = $self->object_type;
    my $id = $self->object_id;
    return "/report/$id" if $type eq 'problem';
    return "/admin/users/$id" if $type eq 'user';
    return "/admin/body/$id" if $type eq 'body';
    return "/admin/roles/$id" if $type eq 'role';
    return "/property/$id" if $type eq 'property';
    my $object = $self->object;
    return "" unless $object;
    if ($type eq 'update') {
        return "/report/" . $object->problem_id . "#update_$id";
    }
    if ($type eq 'moderation') {
        if ($object->comment_id) {
            return "/report/" . $object->problem_id . "#update_" . $object->comment_id;
        } else {
            return "/report/" . $object->problem_id;
        }
    }
    if ($type eq 'template') {
        return "/admin/templates/" . $object->body_id . "/$id";
    }
    if ($type eq 'category') {
        return "/admin/body/" . $object->body_id . '/' . $object->category;
    }
    if ($type eq 'manifesttheme') {
        return "/admin/manifesttheme/" . $object->cobrand;
    }
    return '';
}

sub actual_object_type {
    my $self = shift;
    my $type = $self->object_type;
    return $type unless $type eq 'moderation' && $self->object;
    return $self->object->comment_id ? 'update' : 'report';
}

sub object_summary {
    my $self = shift;

    return $self->object_id if $self->object_type eq 'problem' || $self->object_type eq 'property' || $self->object_type eq 'update';

    my $object = $self->object;
    return unless $object;

    return $object->comment_id || $object->problem_id if $self->object_type eq 'moderation';
    return $object->email || $object->phone || $self->object_id if $self->object_type eq 'user';

    my $type_to_thing = {
        body => 'name',
        role => 'name',
        template => 'title',
        category => 'category',
        manifesttheme => 'cobrand',
    };
    my $thing = $type_to_thing->{$self->object_type} || 'id';

    return $object->$thing;
}

sub object {
    my $self = shift;

    my $type = $self->object_type;
    $type = 'user_object' if $type eq 'user';
    $type = 'comment' if $type eq 'update';

    my $object;
    if (exists $self->{_relationship_data}{$type}) {
        # Cached in relationship fetch
        $object = $self->$type;
    } else {
        # Otherwise, look it up
        my $id = $self->object_id;
        $object = $self->result_source->schema->resultset($JOINS{$type})->find($id);
    }
    return $object;
}

sub action_display {
    my $self = shift;
    my %action_map = (
        add => _('Added'),
        delete => _('Deleted'),
        edit => _('Edited'),
        merge => _('Merged'),
        moderation => _('Moderated'),
        resend => _('Resent'),
        category_change => _('Changed category'),
        state_change => _('Changed state'),
        discount_reset => 'Reset discount',
    );
    return $action_map{$self->action} || $self->action;
}

1;
