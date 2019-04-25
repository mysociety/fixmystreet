use utf8;
package FixMyStreet::DB::Result::Session;

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
__PACKAGE__->table("sessions");
__PACKAGE__->add_columns(
  "id",
  { data_type => "char", is_nullable => 0, size => 72 },
  "session_data",
  { data_type => "text", is_nullable => 1 },
  "expires",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-04-25 12:06:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HoYrCwULpxJVJ1m9ASMk3A

use Storable;
use MIME::Base64;

sub id_code {
    my $self = shift;
    my $id = $self->id;
    $id =~ s/^session://;
    $id =~ s/\s+$//;
    return $id;
}

sub user {
    my $self = shift;
    return unless $self->session_data;
    my $data = Storable::thaw(MIME::Base64::decode($self->session_data));
    return unless $data->{__user};
    my $user = $self->result_source->schema->resultset("User")->find($data->{__user}{id});
    return $user;
}

1;
