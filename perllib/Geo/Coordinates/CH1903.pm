# Geo::Coordinates::CH1903
# Conversion between WGS84 and Swiss CH1903.
#
# Copyright (c) 2012 UK Citizens Online Democracy. This module is free
# software; you can redistribute it and/or modify it under the same terms as
# Perl itself.
#
# WWW: http://www.mysociety.org/

package Geo::Coordinates::CH1903;

$Geo::Coordinates::CH1903::VERSION = '1.00';

use strict;

=head1 NAME

Geo::Coordinates::CH1903

=head1 VERSION

1.00

=head1 SYNOPSIS

    use Geo::Coordinates::CH1903;

    my ($lat, $lon) = ...;
    my ($e, $n) = Geo::Coordinates::CH1903::from_latlon($lat, $lon);
    my ($lat, $lon) = Geo::Coordinates::CH1903::to_latlon($e, $n);

=head1 FUNCTIONS

=over 4

=cut

sub from_latlon($$) {
    my ($lat, $lon) = @_;

    $lat *= 3600;
    $lon *= 3600;

    my $lat_aux = ($lat - 169028.66) / 10000;
    my $lon_aux = ($lon - 26782.5) / 10000;

    my $x = 600072.37
        + (211455.93 * $lon_aux)
        - (10938.51 * $lon_aux * $lat_aux)
        - (0.36 * $lon_aux * $lat_aux**2)
        - (44.54 * $lon_aux**3);

    my $y = 200147.07
        + (308807.95 * $lat_aux)
        + (3745.25 * $lon_aux**2)
        + (76.63 * $lat_aux**2)
        - (194.56 * $lon_aux**2 * $lat_aux)
        + (119.79 * $lat_aux**3);

    return ($x, $y);
}

sub to_latlon($$) {
    my ($x, $y) = @_;

    my $x_aux = ($x - 600000) / 1000000;
    my $y_aux = ($y - 200000) / 1000000;

    my $lat = 16.9023892
        + (3.238272 * $y_aux)
        - (0.270978 * $x_aux**2)
        - (0.002528 * $y_aux**2)
        - (0.0447 * $x_aux**2 * $y_aux)
        - (0.0140 * $y_aux**3);

    my $lon = 2.6779094
        + (4.728982 * $x_aux)
        + (0.791484 * $x_aux * $y_aux)
        + (0.1306 * $x_aux * $y_aux**2)
        - (0.0436 * $x_aux**3);

    $lat = $lat * 100 / 36;
    $lon = $lon * 100 / 36;

    return ($lat, $lon);
}

=head1 AUTHOR AND COPYRIGHT

Maths courtesy of the Swiss Federal Office of Topography:
http://www.swisstopo.admin.ch/internet/swisstopo/en/home/products/software/products/skripts.html

Written by Matthew Somerville

Copyright (c) UK Citizens Online Democracy.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

