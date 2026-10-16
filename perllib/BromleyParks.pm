package BromleyParks;

use strict;
use warnings;

use FixMyStreet;
use FixMyStreet::Roles::SQLite;
use Utils;

sub database_file { FixMyStreet->path_to('../data/bromley_parks.sqlite') }

sub lookup {
    my $search = shift;

    my $results = _db_results($search);
    return unless $results;

    if (@$results) {
        my ($lat, $lon) = Utils::convert_en_to_latlon($results->[0]{easting}, $results->[0]{northing});
        return { latitude => $lat, longitude => $lon };
    }
}

sub _db_results {
    my $search = shift;

    my $db = FixMyStreet::Roles::SQLite::db_connect_readonly(database_file()) or return;

    return $db->selectall_arrayref(
        "SELECT * FROM parks where name match ?",
        { Slice => {} },
        $search
    );
}

1;
