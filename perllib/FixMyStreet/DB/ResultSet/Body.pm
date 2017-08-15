package FixMyStreet::DB::ResultSet::Body;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub for_areas {
    my ( $rs, @areas ) = @_;

    my $result = $rs->search(
        { 'body_areas.area_id' => \@areas },
        { join => 'body_areas' }
    );
    return $result;
}

sub all_translated {
    my $rs = shift;
    my $schema = $rs->result_source->schema;
    my @bodies = $rs->search(undef, {
        '+columns' => { 'msgstr' => 'translations.msgstr' },
        join => 'translations',
        bind => [ 'name', $schema->lang, 'body' ],
    })->all;
    return @bodies;
}

1;
