package FixMyStreet::DB::Result::Comment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("comment");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "comment_id_seq",
  },
  "problem_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "website",
  { data_type => "text", is_nullable => 1 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"ms_current_timestamp()",
    is_nullable   => 0,
  },
  "confirmed",
  { data_type => "timestamp", is_nullable => 1 },
  "text",
  { data_type => "text", is_nullable => 0 },
  "photo",
  { data_type => "bytea", is_nullable => 1 },
  "state",
  { data_type => "text", is_nullable => 0 },
  "cobrand",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "lang",
  { data_type => "text", default_value => "en-gb", is_nullable => 0 },
  "cobrand_data",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "mark_fixed",
  { data_type => "boolean", is_nullable => 0 },
  "mark_open",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "anonymous",
  { data_type => "boolean", is_nullable => 0 },
  "problem_state",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "user",
  "FixMyStreet::DB::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);
__PACKAGE__->belongs_to(
  "problem",
  "FixMyStreet::DB::Result::Problem",
  { id => "problem_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-06-27 10:07:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ilLn3dlagg5COdpZDmzrVQ

use DateTime::TimeZone;
use Image::Size;
use Moose;
use namespace::clean -except => [ 'meta' ];

with 'FixMyStreet::Roles::Abuser';

my $tz = DateTime::TimeZone->new( name => "local" );

sub created_local {
    my $self = shift;

    return $self->created
      ? $self->created->set_time_zone($tz)
      : $self->created;
}

sub confirmed_local {
    my $self = shift;

    # if confirmed is null then it doesn't get inflated so don't
    # try and set the timezone
    return $self->confirmed
      ? $self->confirmed->set_time_zone($tz)
      : $self->confirmed;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration

sub check_for_errors {
    my $self = shift;

    my %errors = ();

    $errors{name} = _('Please enter your name')
        if !$self->name || $self->name !~ m/\S/;

    $errors{update} = _('Please enter a message')
      unless $self->text =~ m/\S/;

    return \%errors;
}

=head2 confirm

Set state of comment to confirmed

=cut

sub confirm {
    my $self = shift;

    $self->state( 'confirmed' );
    $self->confirmed( \'ms_current_timestamp()' );
}

=head2 get_photo_params

Returns a hashref of details of any attached photo for use in templates.

=cut

sub get_photo_params {
    my $self = shift;
    return FixMyStreet::App::get_photo_params($self, 'c');
}

=head2 meta_problem_state

Returns a string suitable for display in the update meta section. 
Mostly removes the '- council/user' bit from fixed states

=cut

sub meta_problem_state {
    my $self = shift;

    my $state = $self->problem_state;
    $state =~ s/ -.*$//;

    return $state;
}

# we need the inline_constructor bit as we don't inherit from Moose
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
