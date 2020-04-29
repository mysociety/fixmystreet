package DBIx::Class::SQLMaker::Pg::ServerCursor;
use strict;
use warnings;
use base 'DBIx::Class::SQLMaker';
use mro 'c3';

# SQLMaker to return the SQL which creates a server-side cursor on Postgres if
# _as_cursor is passed with the name of the cursor to create.
sub select {
    my $self = shift;
    my ($table, $fields, $where, $rs_attrs, $limit, $offset) = @_;
    my ($sql, @all_bind) = $self->next::method(@_);

    if( my $cursor_name = $rs_attrs->{_as_cursor} ) {
        $sql = "DECLARE $cursor_name CURSOR WITH HOLD FOR $sql";
    }

    return wantarray ? ($sql, @all_bind) : $sql;
}

1
