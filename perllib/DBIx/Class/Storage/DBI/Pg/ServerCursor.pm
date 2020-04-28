package DBIx::Class::Storage::DBI::Pg::ServerCursor;
use strict;
use warnings;
use base 'DBIx::Class::Storage::DBI::Cursor';
use mro 'c3';
use Try::Tiny;

__PACKAGE__->mk_group_accessors('simple' =>
    qw/cursor_name cursor_sth/
);

# Track cursor numbers through the lifetime of the program. Only really needs to be tracked for each dbh connection though.
my $cursor_counter = 1;
sub _generate_cursor_name { 'dbic_cursor_' . $cursor_counter++ }

sub cursor_page_size { shift->{args}[3]{cursor_page_size} || 0 }

sub fetch_next_page {
    my $self = shift;

    $self->cursor_sth->finish if $self->cursor_sth;
    (undef, my $cursor_sth, undef) = $self->storage->_dbh_execute( $self->sth->{Database}, 'FETCH ' . $self->cursor_page_size . ' FROM ' . $self->cursor_name, [] );

    $self->cursor_sth($cursor_sth);
}

# Modification of the standard next function so that if C<cursor_page_size> is
# specified in the ResultSet search attrs it will declare a server-side cursor
# and fetch that number of rows at a time.  Support for software offset/limit
# is removed as postgres has great server-side offset/limit support. If
# C<cursor_page_size> is not specified then it behaves exactly as a normal DBIC
# software cursor including support for software offset/limit

# Note: We use $self->sth->{Database} for the FETCH/CLOSE access so that its
# fate is tied to that of the connection that started the cursor
sub next {
  my $self = shift;
  return if $self->{_done};

  # Short-circuit to main method if we are not using server-side cursor
  return $self->next::method( @_ ) if $self->sth && !$self->cursor_name;

  unless ($self->sth) {
    return $self->next::method( @_ ) unless $self->cursor_page_size;

    # Create the main server-side cursor if we didn't get it already
    $self->cursor_name($self->_generate_cursor_name);

    # Issue the server-side declare cursor query
    $self->{args}[3]{_as_cursor} = $self->cursor_name;
    (undef, my $sth, undef) = $self->storage->_select( @{$self->{args}} );

    $self->sth($sth);
    $self->fetch_next_page;

    $self->{_results} = [ (undef) x $self->cursor_sth->FETCH('NUM_OF_FIELDS') ];
    $self->cursor_sth->bind_columns( \( @{$self->{_results}} ) );
  }

  for my $refetched (0, 1) {
      if ($self->cursor_sth->fetch) {
        $self->{_pos}++;
        return @{$self->{_results}};
      }

      $self->fetch_next_page if !$refetched;
  }

  $self->{_done} = 1;
  return ();
}

sub __finish_sth {
  # It is (sadly) extremely important to finish() handles we are about
  # to lose (due to reset() or a DESTROY() ). $rs->reset is the closest
  # thing the user has to getting to the underlying finish() API and some
  # DBDs mandate this (e.g. DBD::InterBase will segfault, DBD::Sybase
  # won't start a transaction sanely, etc)
  # We also can't use the accessor here, as it will trigger a fork/thread
  # check, and resetting a cursor in a child is perfectly valid

  my $self = shift;
  return $self->next::method( @_ ) unless $self->cursor_name;

  # No need to care about failures here
  try { local $SIG{__WARN__} = sub {}; $self->{cursor_sth}->finish } if (
    $self->{cursor_sth} and ! try { ! $self->{cursor_sth}->FETCH('Active') }
  );

  # Close the server-side cursor nicely
  if ( $self->{sth} ) {
    try {
      local $SIG{__WARN__} = sub {};
      $self->storage->_dbh_execute( $self->{sth}{Database}, 'CLOSE ' . $self->cursor_name, [] );
      $self->{sth}->finish;
      $self->{sth} = undef;
    };
  }
}

1
