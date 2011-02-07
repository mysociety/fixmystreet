#!/usr/bin/env perl

use strict;
use warnings;

=head1 DESCRIPTION

This script will take a FMS database with eastings and northings in and migrate
it to latitude and longitude. It touches the following tables and functions:

=cut

use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../commonlib/perllib";

use mySociety::Config;
use mySociety::DBHandle qw(dbh);
use mySociety::GeoUtil qw(national_grid_to_wgs84);

BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../conf/general");
    mySociety::DBHandle::configure(
        Name     => mySociety::Config::get('BCI_DB_NAME'),
        User     => mySociety::Config::get('BCI_DB_USER'),
        Password => mySociety::Config::get('BCI_DB_PASS'),
        Host     => mySociety::Config::get( 'BCI_DB_HOST', undef ),
        Port     => mySociety::Config::get( 'BCI_DB_PORT', undef )
    );
}

migrate_problem_table();

=head2 problem table

Add columns 'latitude' and 'longitude'.
Update all entries coverting from e,n to lon,lat.
Make the lat, lon columns not null.
Drop the 'problem_state_easting_northing_idx' index.
Create new index 'problem_state_latitude_longitude_idx'.
Drop the 'easting' and 'northing' columns.

=cut

sub migrate_problem_table {

    my $dbh = dbh();

    # add columns
    print "add latitude, longitude columns\n";
    $dbh->do("ALTER TABLE problem ADD $_ double precision")
      for qw(latitude longitude);
    $dbh->commit;

    # create a query for rows that need converting
    my $rows_to_convert_query = $dbh->prepare(    #
        "SELECT id, easting, northing FROM problem"
          . " WHERE latitude is NULL limit 1"     # FIXME
    );

    # update query
    my $update_lat_lon_query = $dbh->prepare(     #
        "UPDATE problem SET latitude = ?, longitude = ? WHERE id = ?"
    );

    # loop through the entries in batches updating rows that need it. Do this in
    # Perl rather than SQL for conveniance.
    while (1) {
        $rows_to_convert_query->execute;
        last unless $rows_to_convert_query->rows;
        while ( my $r = $rows_to_convert_query->fetchrow_hashref ) {
            my ( $latitude, $longitude ) =
              _e_n_to_lat_lon( $r->{easting}, $r->{northing} );
            print "update problem $r->{id}: ( $latitude, $longitude )\n";
            $update_lat_lon_query->execute( $latitude, $longitude, $r->{id} );
        }
        $dbh->commit;    # every batch of updates
    }

    # drop old index, create new one
    print "drop and create indexes\n";
    $dbh->do("DROP INDEX problem_state_easting_northing_idx");
    $dbh->do( "CREATE INDEX problem_state_latitude_longitude_idx "
          . "ON problem(state, latitude, longitude)" );
    $dbh->commit;

    # drop columns
    print "drop easting, northing columns\n";
    $dbh->do("ALTER TABLE problem DROP $_") for qw(easting northing);
    $dbh->commit;

}

=head2 problem_find_nearby function

Convert to use lat and long.
Also swap parameter order so that it is lat,lon rather than lon,lat to be consistent with pledgebank etc

=head2 alert table

NOTE: only for alert_types 'local_problems' or 'local_problems_state'

parameter:  convert easting to longitude
parameter2: convert nothing to latitude

=cut

=head2 HELPERS

=cut

sub _e_n_to_lat_lon {
    my ( $e, $n ) = @_;
    my ( $lat, $lon ) = national_grid_to_wgs84( $e, $n, 'G' );
    return ( $lat, $lon );
}
