package FixMyStreet::DB::Result::Alert;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("alert");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "alert_id_seq",
  },
  "alert_type",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "parameter",
  { data_type => "text", is_nullable => 1 },
  "parameter2",
  { data_type => "text", is_nullable => 1 },
  "confirmed",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "lang",
  { data_type => "text", default_value => "en-gb", is_nullable => 0 },
  "cobrand",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "cobrand_data",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "whensubscribed",
  {
    data_type     => "timestamp",
    default_value => \"ms_current_timestamp()",
    is_nullable   => 0,
  },
  "whendisabled",
  { data_type => "timestamp", is_nullable => 1 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "alert_type",
  "FixMyStreet::DB::Result::AlertType",
  { ref => "alert_type" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);
__PACKAGE__->belongs_to(
  "user",
  "FixMyStreet::DB::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);
__PACKAGE__->has_many(
  "alert_sents",
  "FixMyStreet::DB::Result::AlertSent",
  { "foreign.alert_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-06-23 15:49:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:d2TrE9UIZdXu3eXYJH0Zmw

# You can replace this text with custom code or comments, and it will be preserved on regeneration

use DateTime::TimeZone;
use Moose;
use namespace::clean -except => [ 'meta' ];

with 'FixMyStreet::Roles::Abuser';

my $tz = DateTime::TimeZone->new( name => "local" );


sub whensubscribed_local {
    my $self = shift;

    return $self->whensubscribed
      ? $self->whensubscribed->set_time_zone($tz)
      : $self->whensubscribed;
}

sub whendisabled_local {
    my $self = shift;

    return $self->whendisabled
      ? $self->whendisabled->set_time_zone($tz)
      : $self->whendisabled;
}

=head2 confirm

    $alert->confirm();

Sets the state of the alert to confirmed.

=cut

sub confirm {
    my $self = shift;

    $self->confirmed(1);
    $self->whendisabled(undef);
    $self->update;

    return 1;
}

sub disable {
    my $self = shift;

    $self->whendisabled( \'ms_current_timestamp()' );
    $self->update;

    return 1;
}

# need the inline_constuctor bit as we don't inherit from Moose
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
