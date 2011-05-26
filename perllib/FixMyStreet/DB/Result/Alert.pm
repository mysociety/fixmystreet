package FixMyStreet::DB::Result::Alert;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime");
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
  "user",
  "FixMyStreet::DB::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-05-24 15:32:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MV8kPZiQVJH7coYT4FmXLg

# You can replace this text with custom code or comments, and it will be preserved on regeneration

use Moose;
use namespace::clean -except => [ 'meta' ];

with 'FixMyStreet::Roles::Abuser';

=head2 confirm

    $alert->confirm();

Sets the state of the alert to confirmed.

=cut

sub confirm {
    my $self = shift;

    return if $self->confirmed and $self->confirmed == 1 and $self->whendisabled ne 'null';

    $self->confirmed(1);
    $self->whendisabled(undef);

    return 1;
}

# need the inline_constuctor bit as we don't inherit from Moose
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
