package FixMyStreet::Roles::SQLite;

use DBI;

sub db_connect_readonly {
    my $file = shift;
    return unless -e $file;
    my $db = DBI->connect("dbi:SQLite:uri=file:" . $file . '?mode=ro&immutable=1', undef, undef);
    return $db;
}

1;
