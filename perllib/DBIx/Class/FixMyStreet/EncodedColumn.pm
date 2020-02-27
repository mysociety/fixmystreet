package DBIx::Class::FixMyStreet::EncodedColumn;

use strict;
use warnings;

use base qw/DBIx::Class::EncodedColumn/;

# mySociety override to allow direct setting without double encryption
sub set_column {
  my $self = shift;
  if ($_[0] eq 'password') {
    my $cobrand = $self->result_source->schema->cobrand;
    if ($cobrand && $cobrand->moniker eq 'tfl') {
      if (defined $_[1]) {
        if (defined $_[2]) {
          $self->set_extra_metadata(tfl_password => $_[1]);
        } else {
          my $encoder = $self->_column_encoders->{password};
          $self->set_extra_metadata(tfl_password => $encoder->($_[1]));
        }
      }
      return $self->get_extra_metadata('tfl_password');
    }
  }
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
