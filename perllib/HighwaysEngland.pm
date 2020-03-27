package HighwaysEngland;

use strict;
use warnings;

use FixMyStreet;
use DBI;
use Utils;

sub database_file { FixMyStreet->path_to('../data/roads.sqlite') }

my $junction = '(junction|junc|jct|j)\.?\s*(?<junction>.*?)';
my $road = '(?<road>[AM][0-9MT]*)';
my $alt_road = '(?<altroad>[AMB][0-9MT]*)';
my $services = '(?<services>[\w ]+services)';
my $space = '[\s,.]*';

sub junction_lookup {
    my $s = shift;
    if ($s =~ /^\s*$road$space$junction\s*$/i
          || $s =~ /^\s*$junction$space$road\s*$/i
    ) {
        return _lookup_db($+{road}, 'junction', $+{junction}, 'name') || undef;
    } elsif ($s =~ /^\s*$services\s*$/i
          || $s =~ /^\s*$services$space$road\s*$/i
          || $s =~ /^\s*$road$space$services\s*$/i
    ) {
        return _lookup_db($+{road} || 'ANY', 'junction', $+{services}, 'name') || undef;
    } elsif ($s =~ /^\s*(?<road>[AM][^ ]*)$space(?<dist>[0-9.]+)\s*$/i
          || $s =~ /^\s*(?<dist>[0-9.]+)$space(?<road>[AM][^ ]*)\s*$/i
    ) {
        return _lookup_db($+{road}, 'sign', $+{dist}, 'distance') || undef;
    } elsif ($s =~ /^\s*$alt_road$space$road\s*$/i
          || $s =~ /^\s*$road$space$alt_road\s*$/i
    ) {
        return _lookup_db($+{road}, 'junction', $+{altroad}, 'roads') || undef;
    } elsif ($s =~ /^\s*$road$space(?<name>.+)\s*$/i
          || $s =~ /^\s*(?<name>.+?)$space$road\s*$/i
    ) {
        return _lookup_db($+{road}, 'junction', $+{name}, 'guess') || undef;
    }
}

sub _lookup_db {
    my ($road, $table, $thing, $thing_name) = @_;
    my $db = DBI->connect("dbi:SQLite:dbname=".database_file(), undef, undef) or return;
    $thing = "J$thing" if $table eq 'junction' && $thing =~ /^[1-9]/;
    my $results;
    if ( $thing_name eq 'guess' ) {
        $results = $db->selectall_arrayref(
            "SELECT * FROM $table where road=? and name like ?",
            { Slice => {} }, uc $road, '%' . uc $thing . '%');
    } elsif ( $thing_name eq 'roads' ) {
        $results = $db->selectall_arrayref(
            "SELECT * FROM $table where (road=? and name like ?) OR (road=? and name like ?)",
            { Slice => {} }, uc $road, '%' . uc $thing . '%', uc $thing, '%' . uc $road . '%');
    } elsif ( $road eq 'ANY' ) {
        $results = $db->selectall_arrayref(
            "SELECT * FROM $table where $thing_name=?",
            { Slice => {} }, uc $thing);
    } else {
        $results = $db->selectall_arrayref(
            "SELECT * FROM $table where road=? and $thing_name=?",
            { Slice => {} }, uc $road, uc $thing);
    }
    return unless $results;
    if (@$results) {
        my ($lat, $lon) = Utils::convert_en_to_latlon($results->[0]{easting}, $results->[0]{northing});
        return { latitude => $lat, longitude => $lon };
    }
}

1;
