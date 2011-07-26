package DBIx::Class::EncodedColumn;

use strict;
use warnings;

use base qw/DBIx::Class/;
use Sub::Name;

__PACKAGE__->mk_classdata( '_column_encoders' );

our $VERSION = '0.00011';
$VERSION = eval $VERSION;

sub register_column {
  my $self = shift;
  my ($column, $info) = @_;
  $self->next::method(@_);

  return unless exists $info->{encode_column} && $info->{encode_column} == 1;
  $self->throw_exception("'encode_class' is a required argument.")
    unless exists $info->{encode_class} && defined $info->{encode_class};
  my $class = $info->{encode_class};

  my $args = exists $info->{encode_args} ? $info->{encode_args} : {};
  $self->throw_exception("'encode_args' must be a hashref")
    unless ref $args eq 'HASH';

  $class = join("::", 'DBIx::Class::EncodedColumn', $class);
  eval "require ${class};";
  $self->throw_exception("Failed to use encode_class '${class}': $@") if $@;

  defined( my $encode_sub = eval{ $class->make_encode_sub($column, $args) }) ||
    $self->throw_exception("Failed to create encoder with class '$class': $@");
  $self->_column_encoders({$column => $encode_sub, %{$self->_column_encoders || {}}});

  if ( exists $info->{encode_check_method} && $info->{encode_check_method} ){
    no strict 'refs';
    defined( my $check_sub = eval{ $class->make_check_sub($column, $args) }) ||
      $self->throw_exception("Failed to create checker with class '$class': $@");
    my $name = join '::', $self->result_class, $info->{encode_check_method};
    *$name = subname $name, $check_sub;
  }
}

# mySociety override to allow direct setting without double encryption
sub set_column {
  my $self = shift;
  return $self->next::method(@_) unless defined $_[1] and not defined $_[2];
  my $encs = $self->_column_encoders;
  if(exists $encs->{$_[0]} && defined(my $encoder = $encs->{$_[0]})){
    return $self->next::method($_[0], $encoder->($_[1]));
  }
  $self->next::method(@_);
}

sub new {
  my($self, $attr, @rest) = @_;
  my $encoders = $self->_column_encoders;
  for my $col (grep { defined $encoders->{$_} } keys %$encoders ) {
    next unless exists $attr->{$col} && defined $attr->{$col};
    $attr->{$col} = $encoders->{$col}->( $attr->{$col} );
  }
  return $self->next::method($attr, @rest);
}

1;

__END__;

=head1 NAME

DBIx::Class::EncodedColumn - Automatically encode columns

=head1 SYNOPSIS

In your L<DBIx::Class> Result class
(sometimes erroneously referred to as the 'table' class):

  __PACKAGE__->load_components(qw/EncodedColumn ... Core/);

  #Digest encoder with hex format and SHA-1 algorithm
  __PACKAGE__->add_columns(
    'password' => {
      data_type     => 'CHAR',
      size          => 40,
      encode_column => 1,
      encode_class  => 'Digest',
      encode_args   => {algorithm => 'SHA-1', format => 'hex'},
  }

  #SHA-1 / hex encoding / generate check method
  __PACKAGE__->add_columns(
    'password' => {
      data_type   => 'CHAR',
      size        => 40 + 10,
      encode_column => 1,
      encode_class  => 'Digest',
      encode_args   => {algorithm => 'SHA-1', format => 'hex', salt_length => 10},
      encode_check_method => 'check_password',
  }

  #MD5 /  base64 encoding / generate check method
  __PACKAGE__->add_columns(
    'password' => {
      data_type => 'CHAR',
      size      => 22,
      encode_column => 1,
      encode_class  => 'Digest',
      encode_args   => {algorithm => 'MD5', format => 'base64'},
      encode_check_method => 'check_password',
  }

  #Eksblowfish bcrypt / cost of 8/ no key_nul / generate check method
  __PACKAGE__->add_columns(
    'password' => {
      data_type => 'CHAR',
      size      => 59,
      encode_column => 1,
      encode_class  => 'Crypt::Eksblowfish::Bcrypt',
      encode_args   => { key_nul => 0, cost => 8 },
      encode_check_method => 'check_password',
  }

In your application code:

   #updating the value.
   $row->password('plaintext');
   my $digest = $row->password;

   #checking against an existing value with a check_method
   $row->check_password('old_password'); #true
   $row->password('new_password');
   $row->check_password('new_password'); #returns true
   $row->check_password('old_password'); #returns false


B<Note:> The component needs to be loaded I<before> Core.

=head1 DESCRIPTION

This L<DBIx::Class> component can be used to automatically encode a column's
contents whenever the value of that column is set.

This module is similar to the existing L<DBIx::Class::DigestColumns>, but there
is some key differences:

=over 4

=item C<DigestColumns> performs the encode operation on C<insert> and C<update>,
and C<EncodedColumn> performs the operation when the value is set, or on C<new>.

=item C<DigestColumns> supports only algorithms of the L<Digest> family.
C<EncodedColumn> employs a set of thin wrappers around different cipher modules
to provide support for any cipher you wish to use and wrappers are very simple
to write (typically less than 30 lines).

=item C<EncodedColumn> supports having more than one encoded column per table
and each column can use a different cipher.

=item C<Encode> adds only one item to the namespace of the object utilizing
it (C<_column_encoders>).

=back

There is, unfortunately, some features that C<EncodedColumn> doesn't support.
C<DigestColumns> supports changing certain options at runtime, as well as
the option to not automatically encode values on set. The author of this module
found these options to be non-essential and omitted them by design.

=head1 Options added to add_column

If any one of these options is present the column will be treated as a digest
column and all of the defaults will be applied to the rest of the options.

=head2 encode_enable => 1

Enable automatic encoding of column values. If this option is not set to true
any other options will become no-ops.

=head2 encode_check_method => $method_name

By using the encode_check_method attribute when you declare a column you
can create a check method for that column. The check method accepts a plain
text string, and returns a boolean that indicates whether the digest of the
provided value matches the current value.

=head2 encode_class

The class to use for encoding. Available classes are:

=over 4

=item C<Crypt::Eksblowfish::Bcrypt> - uses
L<DBIx::Class::EncodedColumn::Crypt::Eksblowfish::Bcrypt> and 
requires L<Crypt::Eksblowfish::Bcrypt> to be installed

=item C<Digest> - uses L<DBIx::Class::EncodedColumn::Digest>
requires L<Digest> to be installed as well as the algorithm required
(L<Digest::SHA>, L<Digest::Whirlpool>, etc)

=item C<Crypt::OpenPGP> - L<DBIx::Class::EncodedColumn::Crypt::OpenPGP>
and requires L<Crypt::OpenPGP> to be installed

=back

Please see the relevant class's documentation for information about the
specific arguments accepted by each and make sure you include the encoding
algorithm (e.g. L<Crypt::OpenPGP>) in your application's requirements.

=head1 EXTENDED METHODS

The following L<DBIx::Class::ResultSource> method is extended:

=over 4

=item B<register_column> - Handle the options described above.

=back

The following L<DBIx::Class::Row> methods are extended by this module:

=over 4

=item B<new> - Encode the columns on new() so that copy and create DWIM.

=item B<set_column> - Encode values whenever column is set.

=back

=head1 SEE ALSO

L<DBIx::Class::DigestColumns>, L<DBIx::Class>, L<Digest>

=head1 AUTHOR

Guillermo Roditi (groditi) <groditi@cpan.org>

Inspired by the original module written by Tom Kirkpatrick (tkp) <tkp@cpan.org>
featuring contributions from Guillermo Roditi (groditi) <groditi@cpan.org>
and Marc Mims <marc@questright.com>

=head1 CONTRIBUTORS

jshirley - J. Shirley <cpan@coldhardcode.com>

kentnl - Kent Fredric <kentnl@cpan.org>

mst - Matt S Trout <mst@shadowcat.co.uk>

wreis - Wallace reis <wreis@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2008 - 2009 the DBIx::Class::EncodedColumn L</AUTHOR> and
L</CONTRIBUTORS> as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut
