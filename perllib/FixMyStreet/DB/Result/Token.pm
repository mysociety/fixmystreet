use utf8;
package FixMyStreet::DB::Result::Token;

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
__PACKAGE__->table("token");
__PACKAGE__->add_columns(
  "scope",
  { data_type => "text", is_nullable => 0 },
  "token",
  { data_type => "text", is_nullable => 0 },
  "data",
  { data_type => "bytea", is_nullable => 0 },
  "data_json",
  { data_type => "jsonb", is_nullable => 1 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"CURRENT_TIMESTAMP",
    is_nullable   => 0,
  },
);
__PACKAGE__->set_primary_key("scope", "token");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2020-10-14 22:49:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:UE9FC+y+u1zEce97jnjhvg

use mySociety::AuthToken;

=head1 NAME

FixMyStreet::DB::Result::Token

=head2 DESCRIPTION

Representation of mySociety::AuthToken in the DBIx::Class world.

The 'data' value is automatically inflated and deflated in the same way that the
AuthToken would do it. 'token' is set to a new random value by default and the
'created' timestamp is achieved using the database function current_timestamp.

=cut

__PACKAGE__->load_components("+FixMyStreet::DB::RABXColumn");
__PACKAGE__->rabx_column('data');

# XXX Temporary for RABX migration
use Moo;
around set_filtered_column => sub {
    my ($orig, $self, $col, $filtered) = @_;
    if ($col eq 'data') {
        $self->$orig(data_json => $filtered);
    }
    return $self->$orig($col, $filtered);
};
# XXX Temporary for RABX migration

sub new {
    my ( $class, $attrs ) = @_;

    $attrs->{token}   ||= mySociety::AuthToken::random_token();
    $attrs->{created} ||= \'current_timestamp';

    my $new = $class->next::method($attrs);
    return $new;
}

1;
