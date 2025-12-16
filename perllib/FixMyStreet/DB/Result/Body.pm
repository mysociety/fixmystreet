use utf8;
package FixMyStreet::DB::Result::Body;

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
  "external_url",
  { data_type => "text", is_nullable => 1 },
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
  "fetch_problems",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "blank_updates_permitted",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "convert_latlong",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "deleted",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "extra",
  { data_type => "jsonb", is_nullable => 1 },
  "cobrand",
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
  "roles",
  "FixMyStreet::DB::Result::Role",
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


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2024-10-21 23:30:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Lrn1t6/ardCJxCpxH1U2Eg

use Moo;
use namespace::clean;
use FixMyStreet::MapIt;

with 'FixMyStreet::Roles::DB::Translatable',
     'FixMyStreet::Roles::DB::Extra';

sub _url {
    my ( $obj, $cobrand, $args ) = @_;
    my $uri = URI->new('/reports/' . $cobrand->short_name($obj));
    $uri->query_form($args) if $args;
    return $uri;
}

sub url {
    my ( $self, $c, $args ) = @_;
    my $cobrand = $self->result_source->schema->cobrand;
    return _url($self, $cobrand, $args);
}

__PACKAGE__->might_have(
  "translation_name",
  "FixMyStreet::DB::Result::Translation",
  sub {
    my $args = shift;
    my $lang = $args->{self_resultsource}->schema->lang;
    return {
        "$args->{foreign_alias}.object_id" => { -ident => "$args->{self_alias}.id" },
        "$args->{foreign_alias}.tbl" => 'body',
        "$args->{foreign_alias}.col" => 'name',
        "$args->{foreign_alias}.lang" => $lang,
    };
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

around name => \&translate_around;

sub areas {
    my $self = shift;
    my %ids = map { $_->area_id => 1 } $self->body_areas->all;
    return \%ids;
}

=head2 areas_practical

Certain bodies will have associated areas for reasons such as out-of-area
handling (edge cases, parks); whilst areas will return all areas in the
database for a body, areas_practical should only return the areas you'd
expect for the body.

=cut

sub areas_practical {
    my $self = shift;
    my @area_ids = sort keys %{$self->areas};

    my $cobrand = $self->get_cobrand_handler;
    $cobrand ||= $self->result_source->schema->cobrand;
    $cobrand->call_hook(munge_body_areas_practical => $self, \@area_ids);

    return @area_ids;
}

sub area_children {
    my ( $self, $all_generations ) = @_;

    my @body_area_ids = $self->areas_practical;
    return unless @body_area_ids;

    my $cobrand = $self->get_cobrand_handler;
    $cobrand ||= $self->result_source->schema->cobrand;

    return $cobrand->fetch_area_children(\@body_area_ids, $self, $all_generations);
}

=head2 get_cobrand_handler

Get a cobrand object for this body, if there is one.

e.g.
    * if the problem was sent to Bromley it will return ::Bromley
    * if the problem was sent to Camden it will return nothing

=cut

sub get_cobrand_handler {
    my $self = shift;
    my $moniker = $self->cobrand;

    # Need the exists() check because get_class_for_moniker falls back to
    # returning ::Default which isn't what we want here.
    return unless $moniker && FixMyStreet::Cobrand->exists($moniker);

    return FixMyStreet::Cobrand->get_class_for_moniker($moniker)->new;
}

=item

If get_cobrand_handler returns a cobrand, and that cobrand
has a council_name, use it in preference to the body name.

=cut

sub cobrand_name {
    my $self = shift;

    # Because TfL covers all the boroughs in London, get_cobrand_handler
    # may return another London cobrand if it is listed before tfl in
    # ALLOWED_COBRANDS, because one of this body's area_ids will also
    # match that cobrand's council_area_id. This leads to odd things like
    # councils_text_all.html showing a message like "These will be sent to
    # Bromley Council" when making a report within Westminster on the TfL
    # cobrand.
    # If the current body is TfL then we always want to show TfL as the cobrand name.
    return $self->name if $self->name eq 'TfL' || $self->name eq 'National Highways' || $self->name eq 'Environment Agency';


    # Some cobrands, e.g. Hounslow, set a display name which is different to the
    # body name in the DB, so ensure that we respect that here.
    my $handler = $self->get_cobrand_handler;
    if ($handler && $handler->can('council_name')) {
        return $handler->council_name;
    }
    return $self->name;
}

sub calculate_average {
    my ($self, $threshold) = @_;
    $threshold ||= 0;

    # respect the cobrand's cut-off date for displaying problems, if it exists
    my %cutoff;
    my $handler = $self->get_cobrand_handler;
    if ($handler && $handler->can('cut_off_date')) {
      $cutoff{'problem.confirmed'} = { '>=', $handler->cut_off_date } if $handler->cut_off_date;
    }

    my $substmt = "select min(id) from comment where me.problem_id=comment.problem_id and (problem_state in ('fixed', 'fixed - council', 'fixed - user') or mark_fixed)";
    my $subquery = FixMyStreet::DB->resultset('Comment')->to_body($self)->search({
        -or => [
            problem_state => [ FixMyStreet::DB::Result::Problem->fixed_states() ],
            mark_fixed => 1,
        ],
        'me.id' => \"= ($substmt)",
        'me.state' => 'confirmed',
        'problem.state' => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        'problem.cobrand_data' => { -not_in => ["waste", "noise", "claim"] },
        %cutoff,
    }, {
        select   => [
            { extract => \"epoch from me.confirmed-problem.confirmed", -as => 'time' },
        ],
        as => [ qw/time/ ],
        rows => 100,
        order_by => { -desc => 'me.confirmed' },
        join => 'problem'
    })->as_subselect_rs;

    my $result = $subquery->search({
    }, {
        select => [ { avg => "time" }, { count => "time" } ],
        as => [ qw/avg count/ ],
    })->first;
    my $avg = $result->get_column('avg');
    my $count = $result->get_column('count');

    return $count >= $threshold ? $avg : undef;
}

=head2 staff_with_permission

Returns a resultset of all staff users for the body who have been
granted a specific permission.

=cut

sub staff_with_permission {
    my ( $self, $permission ) = @_;
    return $self->users->search([
        { 'user_body_permissions.permission_type' => $permission },
        { permissions => \"@> ARRAY['$permission']" }
    ], {
        join => [ 'user_body_permissions', { "user_roles" => "role" } ],
        distinct => 1,
        order_by => { '-asc' => ['name'] },
    });
}

=head2 site_message

Returns the relevant site message.

=cut

sub site_message {
    my ($self, $type, $ooh) = @_;

    my $suffix = '';
    $suffix .= "_$type" if $type;
    $suffix .= "_ooh" if $ooh;

    my $msg = $self->get_extra_metadata("site_message$suffix") || $self->get_extra_metadata("emergency_message$suffix");
    return $msg;
}

1;
