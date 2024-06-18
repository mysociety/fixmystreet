use utf8;
package FixMyStreet::DB::Result::Session;

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


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2020-10-14 22:49:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2xkfKJVR+NPQhHqMai/MXQ

use Storable;
use MIME::Base64;
use Moo;

has data => (
    is => 'rw',
    lazy => 1,
    default => sub {
        Storable::thaw(MIME::Base64::decode($_[0]->session_data));
    },
    trigger => sub {
        $_[0]->session_data(MIME::Base64::encode(Storable::nfreeze($_[1] || '')));
    },
);

has id_code => (
    is => 'lazy',
    default => sub {
        my $id = $_[0]->id;
        $id =~ s/^session://;
        $id =~ s/\s+$//;
        return $id;
    }
);

has user => (
    is => 'lazy',
    default => sub {
        my $data = $_[0]->data or return;
        return unless $data->{__user};
        my $user = $_[0]->result_source->schema->resultset("User")->find($data->{__user}{id});
        return $user;
    }
);

1;
