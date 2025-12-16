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

sub link {
    my $self = shift;

    my $type = $self->object_type;
    my $id = $self->object_id;
    return "/report/$id" if $type eq 'problem';
    return "/admin/users/$id" if $type eq 'user';
    return "/admin/body/$id" if $type eq 'body';
    return "/admin/roles/$id" if $type eq 'role';
    if ($type eq 'update') {
        my $update = $self->object;
        return "/report/" . $update->problem_id . "#update_$id";
    }
    if ($type eq 'moderation') {
        my $mod = $self->object;
        if ($mod->comment_id) {
            my $update = $self->result_source->schema->resultset('Comment')->find($mod->comment_id);
            return "/report/" . $update->problem_id . "#update_" . $mod->comment_id;
        } else {
            return "/report/" . $mod->problem_id;
        }
    }
    if ($type eq 'template') {
        my $template = $self->object;
        return "/admin/templates/" . $template->body_id . "/$id";
    }
    if ($type eq 'category') {
        my $category = $self->object;
        return "/admin/body/" . $category->body_id . '/' . $category->category;
    }
    if ($type eq 'manifesttheme') {
        my $theme = $self->object;
        return "/admin/manifesttheme/" . $theme->cobrand;
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
    my $object = $self->object;
    return unless $object;

    return $object->comment_id || $object->problem_id if $self->object_type eq 'moderation';
    return $object->email || $object->phone || $object->id if $self->object_type eq 'user';

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
    my $id = $self->object_id;
    my $type_to_object = {
        moderation => 'ModerationOriginalData',
        template => 'ResponseTemplate',
        category => 'Contact',
        update => 'Comment',
        manifesttheme => 'ManifestTheme',
    };
    $type = $type_to_object->{$type} || ucfirst $type;
    my $object = $self->result_source->schema->resultset($type)->find($id);
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
        group_change => _('Changed group'),
        state_change => _('Changed state'),
    );
    return $action_map{$self->action} || $self->action;
}

1;
