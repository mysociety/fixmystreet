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

1;
