package DBIx::Class::Storage::DBI::PgServerCursor;
use strict;
use warnings;
use base 'DBIx::Class::Storage::DBI::Pg';
use mro 'c3';

__PACKAGE__->sql_maker_class('DBIx::Class::SQLMaker::Pg::ServerCursor');
__PACKAGE__->cursor_class('DBIx::Class::Storage::DBI::Pg::ServerCursor');

1
