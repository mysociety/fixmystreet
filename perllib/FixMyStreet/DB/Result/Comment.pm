package FixMyStreet::DB::Result::Comment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime");
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


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-05-24 15:32:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:71bSUgPf3uW607g2EGl/Vw

use DateTime::TimeZone;
my $tz = DateTime::TimeZone->new( name => "local" );

sub created_local {
    return shift->created->set_time_zone($tz);
}

sub confirmed_local {
    return shift->confirmed->set_time_zone($tz);
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration

sub check_for_errors {
    my $self = shift;

    my %errors = ();

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
Hashref contains height, width and url keys.

=cut

sub get_photo_params {
    my $self = shift;

    return {} unless $self->photo;

    my $photo = {};
    ( $photo->{width}, $photo->{height} ) =
      Image::Size::imgsize( \$self->photo );
    $photo->{url} = '/photo/?c=' . $self->id;

    return $photo;
}

=head2 is_from_abuser

    $bool = $update->is_from_abuser(  );

Returns true if the user's email or its domain is listed in the 'abuse' table.

=cut

sub is_from_abuser {
    my $self = shift;

    # get the domain
    my $email = $self->user->email;
    my ($domain) = $email =~ m{ @ (.*) \z }x;

    # search for an entry in the abuse table
    my $abuse_rs = $self->result_source->schema->resultset('Abuse');

    return
         $abuse_rs->find( { email => $email } )
      || $abuse_rs->find( { email => $domain } )
      || undef;
}

1;
