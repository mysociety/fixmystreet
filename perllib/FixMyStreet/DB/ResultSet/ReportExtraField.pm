package FixMyStreet::DB::ResultSet::ReportExtraField;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub for_cobrand {
    my ( $rs, $cobrand ) = @_;

    my $result = $rs->search(
        { cobrand => [ undef, $cobrand->moniker, '' ] }
    );
    return $result;
}

sub for_language {
    my ( $rs, $language ) = @_;

    my $result = $rs->search(
        { language => [ undef, $language, '' ] }
    );
    return $result;
}

1;
