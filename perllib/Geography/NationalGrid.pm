package Geography::NationalGrid;
use strict;
use vars qw($VERSION);
($VERSION) = ('$Revision: 1.6 $' =~ m/([\d\.]+)/);

use constant MAX_ITERS => 1000;
use constant PI => 3.141592653897543238452643383279;

sub new {
	my $class = shift;
	my $country = shift || die "You must supply a country code";
	my %options = @_;

	if ($country =~ m/\W/) { die "Country code must only contain alphanumeric and underscore characters"; }

	# try to create a new object straight away, in case the package is loaded
	my $self = eval "return Geography::NationalGrid::$country->new( \%options );";
	if ($@) {
		# that didn't work, so let's try loading the module
		eval "use Geography::NationalGrid::$country;";
		if ($@) { die "A fatal arror occurred while trying to load Geography::NationalGrid::$country - $@"; }
		$self = eval "return Geography::NationalGrid::$country->new( \%options );";
		if ($@) { die "A fatal arror occurred while trying to build the Geography::NationalGrid::$country object - $@"; }
	}
	
	# $self should now be defined, but let's check
	unless (ref $self) { die "The NationalGrid object for $country was not defined - cannot continue"; }
	return $self;
}

# Object methods - you may inherit these to make life easier

sub data {
	my $obj = shift;
	my $param = shift;
	return $obj->{'Userdata'}->{$param};
}

sub latitude {
	my $self = shift;
	return $self->rad2deg( $self->{'Latitude'} );
}

sub longitude {
	my $self = shift;
	return $self->rad2deg( $self->{'Longitude'} );
}

sub easting {
	my $self = shift;
	return int( $self->{'Easting'} );
}
	
sub northing {
	my $self = shift;
	return int( $self->{'Northing'} );
}

# Utility methods, may be inherited or called as class methods
# The first argument is ignored, because that's your object which is of no use here, or it's the class name

sub rad2deg { return (180 * $_[1] / PI); }

sub deg2rad {
	my $degrees = $_[1];
	
	my ($d, $m, $s) = ($degrees, 0, 0);
	
	if (ref $degrees) {
		($d, $m, $s) = @$degrees;
	} elsif ($degrees =~ m/^\s*(-?\d+)\s*d\s*(\d+)\s*m\s*([\d\.]+)\s*s\s*$/) {
		($d, $m, $s) = ($1, $2, $3);
	} elsif ($degrees !~ m/^-?[\d\.]+$/) {
		die "deg2rad given an argument of '$degrees' which didn't look like a) a number or b) a string like 52d 5m 32s";
	}
	
	my $sense = 1;
	if ($d =~ m/^-/) {
		$sense = -1;
		$d = abs($d);
	}
	$degrees = ($d + ($m/60) + ($s/3600)) * $sense;
	return (PI * $degrees / 180);
}

sub deg2string {
	my $degrees = $_[1];
	
	# make positive
	my $isneg = 0;
	if ($degrees < 0) {
		$isneg = 1;
		$degrees = abs( $degrees );
	} elsif ($degrees == 0) {
		return '0d 0m 0s';
	}
	
	my $d = int( $degrees );
	$degrees -= $d;
	$degrees *= 60;
	my $m = int( $degrees );
	$degrees -= $m;
	my $s = $degrees * 60;
	
	return sprintf("%s%dd %um %.2fs", ($isneg?'-':''), $d, $m, $s);
}

### GENERAL ROUTINES TO CONVERT ELLIPSOIDAL LATITUDE AND LONGITUDE TO/FROM A TRANSVERSE MERCATOR PROJECTION
### Many National Grids can be converted using these routines, so these are coded as object methods
### It is assumed that the object contains the necessary ellipsoid and mercator constants

sub tan { return (sin($_[0]) / cos($_[0])); }	# watch out for tan(90 degrees)
sub sec { return (1/cos($_[0])); }	# watch out for sec(90 degrees)

# NEEDS Easting, Northing
# SETS radians north, radians east (Latitude, Longitude)
sub _mercator2latlong {
	my $self = shift;
	
	my $E = $self->{'Easting'};
	my $N = $self->{'Northing'};

	# ellipsoid constants
	my $axisa = $self->{'EllipsoidData'}{'a'} || die "Missing data for axis a";
	my $axisb = $self->{'EllipsoidData'}{'b'} || die "Missing data for axis b";
	my $e2 = ($axisa**2 - $axisb**2)/($axisa**2);
	# projection constants
	my $No = $self->{'MercatorData'}{'No'}; # northing of true origin
	my $Eo = $self->{'MercatorData'}{'Eo'}; # easting of true origin
	my $Fo = $self->{'MercatorData'}{'scalefactor'} || die "Missing or zero scale factor - maybe Mercator data is incomplete?"; # scale factor on central meridian
	my $phio = $self->{'MercatorData'}{'phio'}; # latitude of true origin
	my $lambdao = $self->{'MercatorData'}{'lambdao'}; # longitude of true origin & central meridian

	
	my $phi = (($N - $No) / ($axisa * $Fo)) + $phio;	#A14 - phi-prime in the docs
	
	my $n = ($axisa-$axisb)/($axisa+$axisb); # A9
	my $M = $axisb * $Fo * (
		  (1 + $n + (1.25 * $n**2) + (1.25 * $n**3)) * ($phi - $phio)
		- ((3 * $n) + (3 * $n**2) + (2.625 * $n**3)) * sin($phi - $phio) * cos($phi + $phio)
		+ ((1.875 * $n**2) + (1.875 * $n**3)) * sin(2 * ($phi - $phio)) * cos(2 * ($phi + $phio))
		- (35/24) * ($n**3) * sin(3 * ($phi - $phio)) * cos(3 * ($phi + $phio))
	); # A11

	my $guard = 0;
	while (($N - $No - $M) >= 0.001) {
		$phi = (($N - $No - $M) / ($axisa * $Fo)) + $phi;	#A15

		$M = $axisb * $Fo * (
			  (1 + $n + (1.25 * $n**2) + (1.25 * $n**3)) * ($phi - $phio)
			- ((3 * $n) + (3 * $n**2) + (2.625 * $n**3)) * sin($phi - $phio) * cos($phi + $phio)
			+ ((1.875 * $n**2) + (1.875 * $n**3)) * sin(2 * ($phi - $phio)) * cos(2 * ($phi + $phio))
			- (35/24) * ($n**3) * sin(3 * ($phi - $phio)) * cos(3 * ($phi + $phio))
		); # A11

		if ($guard++ > MAX_ITERS) {
			my $diff = $N - $No - $M;
			die "Equation A15 is not converging upon a solution: difference is $diff metres after $guard iterations";
		}
	}

	my $nu = $axisa * $Fo * ((1-($e2)*((sin($phi)**2))) ** -0.5);
	my $rho = $axisa * $Fo * (1-($e2)) *((1-($e2)*((sin($phi)**2))) ** -1.5);
	my $eta2 = ($nu/$rho - 1); # A10
	
	my $VII = tan($phi) / (2 * $rho * $nu);
	my $VIII = (tan($phi) / (24 * $rho * ($nu ** 3))) * (5 + (3 * (tan($phi) ** 2)) + $eta2 - 9 * $eta2 * (tan($phi) ** 2) );
	my $IX = (tan($phi) / (720 * $rho * ($nu ** 5))) * (61 + (90 * (tan($phi) ** 2)) + (45 * (tan($phi) ** 4)) );
	my $X = sec($phi) / $nu;
	my $XI = (sec($phi) / (6 * $nu ** 3)) * (($nu/$rho) + 2 * (tan($phi) ** 2));
	my $XII = (sec($phi) / (120 * $nu ** 5)) * (5 + (28 * (tan($phi) ** 2)) + (24 * (tan($phi) ** 4)));
	my $XIIA = (sec($phi) / (5040 * $nu ** 7)) * (61 + (662 * (tan($phi) ** 2)) + (1320 * (tan($phi) ** 4)) + (720 * (tan($phi) ** 6)));

	# finally we can compute the answer
	my $realphi = $phi
		- $VII  * ($E - $Eo)**2
		+ $VIII * ($E - $Eo)**4
		- $IX   * ($E - $Eo)**6
	;
	my $lambda = $lambdao
		+ $X    * ($E - $Eo)
		- $XI   * ($E - $Eo)**3
		+ $XII  * ($E - $Eo)**5
		- $XIIA * ($E - $Eo)**7
	;
	
	($self->{'Latitude'}, $self->{'Longitude'}) = ($realphi, $lambda);
}

# NEEDS radians north, radians east, mercator projection (Latitude, Longitude, Projection)
# SETS Easting, Northing
sub _latlong2mercator {
	my $self = shift;

	my $phi = $self->{'Latitude'};
	my $lambda = $self->{'Longitude'};

	# ellipsoid constants
	my $axisa = $self->{'EllipsoidData'}{'a'} || die "Missing data for axis a";
	my $axisb = $self->{'EllipsoidData'}{'b'} || die "Missing data for axis b";
	my $e2 = ($axisa**2 - $axisb**2)/($axisa**2);
	# projection constants
	my $No = $self->{'MercatorData'}{'No'}; # northing of true origin
	my $Eo = $self->{'MercatorData'}{'Eo'}; # easting of true origin
	my $Fo = $self->{'MercatorData'}{'scalefactor'} || die "Missing or zero scale factor - maybe Mercator data is incomplete?"; # scale factor on central meridian
	my $phio = $self->{'MercatorData'}{'phio'}; # latitude of true origin
	my $lambdao = $self->{'MercatorData'}{'lambdao'}; # longitude of true origin & central meridian


	my $n = ($axisa-$axisb)/($axisa+$axisb); # A9

	my $nu = $axisa * $Fo * ((1-($e2)*((sin($phi)**2))) ** -0.5);
	my $rho = $axisa * $Fo * (1-($e2)) *((1-($e2)*((sin($phi)**2))) ** -1.5);
	my $eta2 = ($nu/$rho - 1); # A10

	my $M = $axisb * $Fo * (
		  (1 + $n + (1.25 * $n**2) + (1.25 * $n**3)) * ($phi - $phio)
		- ((3 * $n) + (3 * $n**2) + (2.625 * $n**3)) * sin($phi - $phio) * cos($phi + $phio)
		+ ((1.875 * $n**2) + (1.875 * $n**3)) * sin(2 * ($phi - $phio)) * cos(2 * ($phi + $phio))
		- (35/24) * ($n**3) * sin(3 * ($phi - $phio)) * cos(3 * ($phi + $phio))
	); # A11

	my $I = $M + $No;
	my $II = ($nu/2) * sin($phi) * cos($phi);
	my $III = ($nu/24) * sin($phi) * (cos($phi) ** 3) * (5 - (tan($phi) ** 2) + 9 * $eta2);
	my $IIIA = ($nu/720) * sin($phi) * (cos($phi) ** 5) * (61 - 58*(tan($phi) ** 2) + (tan($phi) ** 4));
	my $IV = $nu * cos($phi);
	my $V = ($nu/6) * (cos($phi) ** 3) * ($nu/$rho - (tan($phi) ** 2));
	my $VI = ($nu/120) * (cos($phi) ** 5) * (5 - 18 * (tan($phi) ** 2) + (tan($phi) ** 4) + 14 * $eta2 - 58 * (tan($phi) ** 2) * $eta2);

	# After all those intermediate equations we can now calculate the easting and northing
	my $N = $I
		+ ($II   * (($lambda - $lambdao) ** 2))
		+ ($III  * (($lambda - $lambdao) ** 4))
		+ ($IIIA * (($lambda - $lambdao) ** 6))
	;	# A12

	my $E = $Eo
		+ ($IV * ($lambda - $lambdao))
		+ ($V * (($lambda - $lambdao) ** 3))
		+ ($VI * (($lambda - $lambdao) ** 5))
	; # A13

	my $fudge = $self->{'DefaultResolution'} / 2;	# because the point is within the _square_ based at the E,N coordinate
	($self->{'Easting'}, $self->{'Northing'}) = ($E + $fudge, $N + $fudge);
}

1;

__END__

=pod

=head1 NAME

Geography::NationalGrid - Base class to create an object for a point and to transform coordinate systems

=head1 SYNOPSIS

Geography::NationalGrid is a factory class whose sole purpose is to give you an object for the right country.
Geography::NationalGrid::GB and Geography::NationalGrid::IE are included with this distribution - other countries'
national grids are converted by other packages.

The first argument to new() is the ISO 2 letter country code, and it is followed by name-value pairs that are passed to 
the country-specific constructor. See the reference for the country-specific module - a country code of 'GB'
corresponds to the module called Geography::NationalGrid::GB.

	use Geography::NationalGrid;
	my $point1 = new Geography::NationalGrid( 'GB',
		GridReference => 'TQ 289816',
	);
	print "Latitude is " . $point1->latitude . " degrees north\n";

=head1 DESCRIPTION

You ask for an object for the correct country, described using the ISO 2-letter country code. You will need to
supply information to the constructor. You may then call methods on that object to do whatever operations you need.
Conceptually each object represents a point on the ground, although you some grid systems may take that point to 
be a corner of a defined area. E.g. a 6-figure OS National Grid reference B<may> be thought of as the point at the south-west
of a 100m by 100m square.

=head1 METHODS

See the documentation for the country-specific module. This modules provides these generic methods which may or may not be used
by the country-specific objects:

=over 4

=item latitude() / longitude()

Returns the appropriate value in floating point degrees

=item easting() / northing()

Returns the appropriate value in metres, truncated to integer metres

=item data(PARAMETER)

Access the Userdata hash in the object, and retrieve whatever is keyed against PARAMETER. Typical use might be to store
some long information about the point, such as the site name.

=item deg2string(DEGREES)

Returns a string of the form '52d 28m 34s' when given a number of degrees. You can also call this as a class method.

=item deg2rad(DEGREES)

The input number of degrees may be in one of 3 formats: a floating point number, such as 52.34543; a reference to an array of
3 values representing degrees, minutes and seconds, such as [52, 28, 34]; a string of the form '52d 28m 34s'. Returns
the number of radians as a floating point number.  You can also call this as a class method.

=item rad2deg(RADIANS)

Converts a floating point number of radians into a flaoting point number of degrees.  You can also call this as a class method.

=back

=head1 OTHER COUNTRIES

The core distribution includes the GB and IE modules, allowing you to work with the National Grids of Britain and Ireland.
Adding support for another country would require the module for that country to be installed - the naming convention is
'Geography::NationalGrid::' followed by the ISO 2-letter country code, in capitals.

If you would like to provide support for another country please see the DEVELOPERS section below.

=head1 ACCURACY

The routines used in this code may not give you completely accurate results for various mathematical and theoretical reasons.
In tests the results appeared to be correct, but it may be that under certain conditions the output
could be highly inaccurate. It is likely that output accuracy decreases further from the datum, and behaviour is probably divergent
outside the intended area of the grid, but in any case accuracy is not guaranteed.

This module has been coded in good faith but it may still get things wrong.
Hence, it is recommended that this module is used for preliminary calculations only, and that it is NOT used under any
circumstance where its lack of accuracy could cause any harm, loss or other problems of any kind. Beware!

=head1 DEVELOPERS

This module was originally written for the OS National Grid of Great Britain, but built in a way to
allow other countries to be easily plugged in. This module is the base class; it contains a lot of the functions
that you'll need - most notably the transformations between transverse Mercator projections and Latitude/Longitude positions.
Modules can use this class and override methods as needed.

If you do write a module then why not keep the basic object interface similar to the 'GB' and 'IE' modules - for example,
why not simply inherit the latitude() accessor method from here. There will probably be country-specific methods that you
wish to add aswell, and features of the GB module may not apply to your grid.

This module contains some object methods which you can inherit, and these are data(PARAMETER), northing(), easting(),
latitude() and longitude(), and the _mercator2latlong() and _latlong2mercator() internal methods. All of these assume that your object
has certain pieces of data in certain places. See the METHODS section above.

In short, to write a module for a new country you simply need to write the new() routine to create a fully populated object. You
may need to write a gridReference() accessor routine, and probably need to write the routines to convert raw eastings & northings
to/from a grid reference. You'll also need the parameters of the ellipsoid used and the projection parameters. Most national grids are
transverse Mercator projections, which means you can inherit the internal conversion
routines from this class and you'll have an easy job. Otherwise
you may need to implement your own conversion.

=head1 AUTHOR AND COPYRIGHT

Copyright (c) 2002 P Kent. All rights reserved.
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

Equations for transforming latitude and longitude to, and from, rectangular grid coordinates
appear on an Ordnance Survey webpage, although they are
standard coordinate conversion equations - thanks to the OS for clarifying.

$Revision: 1.6 $

=cut
