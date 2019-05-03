use utf8;
package FixMyStreet::DB::Result::Token;

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
__PACKAGE__->table("token");
__PACKAGE__->add_columns(
  "scope",
  { data_type => "text", is_nullable => 0 },
  "token",
  { data_type => "text", is_nullable => 0 },
  "data",
  { data_type => "bytea", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("scope", "token");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-04-25 12:06:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:km/1K3PurX8bbgnYPWgLIA

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


sub new {
    my ( $class, $attrs ) = @_;

    $attrs->{token}   ||= mySociety::AuthToken::random_token();
    $attrs->{created} ||= \'current_timestamp';

    my $new = $class->next::method($attrs);
    return $new;
}

1;
