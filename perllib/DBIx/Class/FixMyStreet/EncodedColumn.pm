package DBIx::Class::FixMyStreet::EncodedColumn;

use strict;
use warnings;

use base qw/DBIx::Class::EncodedColumn/;

# mySociety override to allow direct setting without double encryption
sub set_column {
  my $self = shift;
  return DBIx::Class::Row::set_column($self, @_) unless defined $_[1] and not defined $_[2];
  $self->next::method(@_);
}

1;

__END__;

=head1 NAME

DBIx::Class::FixMyStreet::EncodedColumn - Automatically encode columns

=head1 SYNOPSIS

The same as DBIx::Class::EncodedColumn, but adding an extra optional second
argument to set_column to allow skipping encryption (so if we hold an
already-hashed password, we can set it directly).

In your application code:

   $row->password('plaintext');
   $row->password('hashed-password', 1);

=head1 EXTENDED METHODS

The following L<DBIx::Class::Row> methods are extended by this module:

=over 4

=item B<set_column> - Encode values whenever column is set.

=back

=head1 SEE ALSO

L<DBIx::Class::EncodedColumn>, L<DBIx::Class>

=cut
