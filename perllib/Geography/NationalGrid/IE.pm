package Geography::NationalGrid::IE;
use strict;
use vars qw(@ISA $VERSION %ellipsoids %mercators %lettermap @revlettermap %squaresize %res2digits);
($VERSION) = ('$Revision: 1.2 $' =~ m/([\d\.]+)/);

use constant DEFAULT_PROJECTION => 'IRNATGRID';
use constant MIN_LONG => Geography::NationalGrid->deg2rad('-11d 12m 0s');
use constant MAX_LONG => Geography::NationalGrid->deg2rad('-4d 48m 0s');
use constant MIN_LATI => Geography::NationalGrid->deg2rad('51d 12m 0s');
use constant MAX_LATI => Geography::NationalGrid->deg2rad('55d 43m 0s');

@ISA = 'Geography::NationalGrid';

%ellipsoids = (
	'airy1830' => {
		'a' => 6377563.396,
		'b' => 6356256.910,
		'info' => 'OSGB36, National Grid',
	},
	'airy1830mod' => {
		'a' => 6377340.189,
		'b' => 6356034.447,
		'info' => 'Ireland 65, Irish National Grid',
	},
	'int1924' => {
		'a' => 6378388.000,
		'b' => 6356911.946,
		'info' => 'ED50, UTM',
	}, # same as hayford1909
	'wgs84' => {
		'a' => 6378137.000,
		'b' => 6356752.3141,
		'info' => 'WGS84, ITRS, ETRS89',
	}, # same as grs80
);
$ellipsoids{'grs80'}  = $ellipsoids{'wgs84'};
$ellipsoids{'hayford1909'}  = $ellipsoids{'int1924'};

%mercators = (
	NATGRID => {
		'scalefactor' => 0.9996012717,
		'phio' => Geography::NationalGrid->deg2rad(49),
		'lambdao' => Geography::NationalGrid->deg2rad(-2),
		'Eo' => 400000,
		'No' => -100000,
		'ellipsoid' => 'airy1830',
	},
	IRNATGRID => {
		'scalefactor' => 1.000035,
		'phio' => Geography::NationalGrid->deg2rad(53.5),
		'lambdao' => Geography::NationalGrid->deg2rad(-8),
		'Eo' => 200000,
		'No' => 250000,
		'ellipsoid' => 'airy1830mod',
	},
	UTM29 => {
		'scalefactor' => 0.9996,
		'phio' => 0,
		'lambdao' => Geography::NationalGrid->deg2rad(-9),
		'Eo' => 500000,
		'No' => 0,
		'ellipsoid' => 'int1924',
	},
	UTM30 => {
		'scalefactor' => 0.9996,
		'phio' => 0,
		'lambdao' => Geography::NationalGrid->deg2rad(-3),
		'Eo' => 500000,
		'No' => 0,
		'ellipsoid' => 'int1924',
	},
	UTM31 => {
		'scalefactor' => 0.9996,
		'phio' => 0,
		'lambdao' => Geography::NationalGrid->deg2rad(3),
		'Eo' => 500000,
		'No' => 0,
		'ellipsoid' => 'int1924',
	},
);

%lettermap = (
	A => [0,4], B => [1,4], C => [2,4], D => [3,4],
	F => [0,3], G => [1,3], H => [2,3], J => [3,3],
	L => [0,2], M => [1,2], N => [2,2], O => [3,2],
	Q => [0,1], R => [1,1], S => [2,1], T => [3,1],
	V => [0,0], W => [1,0], X => [2,0], Y => [3,0],
);

@revlettermap = (
	[ qw(V W X Y) ],	
	[ qw(Q R S T) ],	
	[ qw(L M N O) ],	
	[ qw(F G H J) ],	
	[ qw(A B C D) ],	
);

%squaresize = (
	 '2' => 10000,
	 '4' => 1000,
	 '6' => 100,
	 '8' => 10,
	'10' => 1,
);

%res2digits = ( # digits per half of the reference
	'10000' => 1,
	'1000'  => 2,
	'100'   => 3,
	'10'    => 4,
	'1'     => 5,
);

### PUBLIC INTERFACE

# new() does most of the work - we regularize the input to create a fully-populated object
sub new {
	my $class = shift;
	my %options = @_;
	
	unless ($options{'GridReference'} ||
		(exists $options{'Latitude'} && exists $options{'Longitude'}) ||
		(exists $options{'Easting'} && exists $options{'Northing'})
	) {
		die __PACKAGE__ . ": You must supply a grid reference, or lat/long, or easting/northing";
	}
	
	my $self = bless({
		Userdata => $options{'Userdata'},
	}, $class);
	
	# keep constructor options
	delete $options{'Userdata'};
	while (my ($k, $v) = each %options) { $self->{'_constructor_'.$k} = $v; }
	
	$self->{'Projection'} = $options{'Projection'} || DEFAULT_PROJECTION;
	
	# gather information that will be needed in lat/long <-> east/north method
	my $mercatordata = $mercators{ $self->{'Projection'} } || die "Couldn't find Mercator projection data for $self->{'Projection'}";
	my $ellipsoiddata = $ellipsoids{ $mercatordata->{'ellipsoid'} } || die "Couldn't find ellipsoid data for $self->{'Projection'}";
	$self->{'MercatorData'} = $mercatordata;
	$self->{'EllipsoidData'} = $ellipsoiddata;
	
	$self->{'DefaultResolution'} = $options{'DefaultResolution'} || 100;
	
	my $flagTodo = 1;
	
	# if given lat/long, first make that into easting/northing
	if (exists $options{'Latitude'} && exists $options{'Longitude'}) {
		$self->{'Latitude'} = $self->deg2rad( $options{'Latitude'} );
		$self->{'Longitude'} = $self->deg2rad( $options{'Longitude'} );
		$self->_latlong2mercator;
		$flagTodo = 0;
	}
	
	# if got absolute northing and easting, convert that into a lat/long
	if ($flagTodo && exists $options{'Easting'} && exists $options{'Northing'}) {
		($self->{'Easting'}, $self->{'Northing'}) = ($options{'Easting'}, $options{'Northing'});
		$self->_mercator2latlong;
		$flagTodo = 0;
	}

	# else we must have been given a grid reference
	if ($flagTodo && $options{'GridReference'}) {
		$options{'GridReference'} =~ s/\s//g;
		$options{'GridReference'} = uc( $options{'GridReference'} );
		if (($options{'GridReference'} =~ m/^([A-Z])(\d+)$/) && ((length($2) % 2) == 0) && (length($2) <= 10) ) {
			$self->{'_square'} = $1;
			$self->{'_digits'} = $2;
			$self->{'_quadrant'} = $3 || '';
			$self->{'DefaultResolution'} = $squaresize{ length($self->{'_digits'}) };
			
			($self->{'_eastingo'}, $self->{'_northingo'}) = _oneletter2offset($self->{'_square'});
			
			$self->{'_eastinga'} = substr($self->{'_digits'}, 0, length($self->{'_digits'})/2 );
			$self->{'_northinga'} = substr($self->{'_digits'}, length($self->{'_digits'})/2, length($self->{'_digits'})/2 );
			
			$self->{'Easting'} = $self->{'_eastingo'} + $self->{'_eastinga'} * $self->{'DefaultResolution'};
			$self->{'Northing'} = $self->{'_northingo'} + $self->{'_northinga'} * $self->{'DefaultResolution'};
			
			$self->_mercator2latlong;
		} else {
			die "The grid reference $options{'GridReference'} does not look valid";
		}
	}

	$self->_boundscheck;
	$self->{'ComputedGridReference'} = $self->_offset2gridref;
	
	return $self;
}

sub gridReference {
	my $self = shift;
	
	if ($self->{'Projection'} ne DEFAULT_PROJECTION) {
		return undef;
	}
	
	my $resolution = shift || return $self->{'ComputedGridReference'};
	return $self->_offset2gridref( $resolution );
}

### Main conversion methods (to transform lat/long to/from a transverse mercator projection) are inherited from the NationaGrid module

### PRIVATE ROUTINES

# given a 1 letter square code, returns the offset, in metres of the south-west corner
sub _oneletter2offset {
	my $code = shift();
	unless ($code =~ m/^[ABCDFGHJLMNOQRSTVWXY]$/) {
		die "Code supplied '$code' is not a valid 1-letter square code";
	}
	
	my $minor = $lettermap{$code};

	my $offsete = (100000 * $minor->[0]);
	my $offsetn = (100000 * $minor->[1]);

	return ($offsete, $offsetn);
}

# given an easting and northing, a resolution, return a grid reference string
sub _offset2gridref {
	my $self = shift;

	my $resolution = shift || $self->{'DefaultResolution'};
	my ($e, $n) = ( $self->{'Easting'}, $self->{'Northing'} );
	
	# find out how many 500km and 100km units make up each distance
	my ($e100s, $n100s) = (0,0);
	while ($e >= 100000) { $e -= 100000; $e100s++; }
	while ($n >= 100000) { $n -= 100000; $n100s++; }
	
	# now reduce the remaining digits to the appropriate resolution
	$e /= $resolution;
	$n /= $resolution;
	
	my $numdigits = $res2digits{$resolution} || die "Resolution was $resolution metres, but must be a power of 10 from 1 to 10,000";
	
	return sprintf("%s %0${numdigits}u%0${numdigits}u", $revlettermap[$n100s][$e100s], $e, $n);
}

sub _boundscheck {
	my $self = shift;

	if ($self->{'Easting'} < 0) { die "Point is out of the area covered by this module - too far west"; }
	if ($self->{'Easting'} >= 400000) { die "Point is out of the area covered by this module - too far east"; }
	if ($self->{'Northing'} < 0) { die "Point is out of the area covered by this module - too far south"; }
	if ($self->{'Northing'} >= 500000) { die "Point is out of the area covered by this module - too far north"; }

	# these tests need to be a bit more lax because grid north != true north
	if ($self->{'Longitude'} < MIN_LONG) { die "Point is out of the area covered by this module - too far east"; }
	if ($self->{'Longitude'} > MAX_LONG) { die "Point is out of the area covered by this module - too far west"; }
	if ($self->{'Latitude'} < MIN_LATI) { die "Point is out of the area covered by this module - too far south"; }
	if ($self->{'Latitude'} > MAX_LATI) { die "Point is out of the area covered by this module - too far north"; }
}

1;

__END__

=pod

=head1 NAME

Geography::NationalGrid::IE - Module to convert Irish National Grid references to/from Latitude and Longitude

=head1 SYNOPSIS

You should _create_ the object using the Geography::NationalGrid factory class, but you still need to
know the object interface, given below.

	my $point1 = new Geography::NationalGrid::IE(
		GridReference => 'M 345132',
	);
	my $point2 = new Geography::NationalGrid::IE(
		Latitude => 53.8,
		Longitude => -7.5
	);
	print "Point 1 is " . $point->latitude . " degrees north\n";

=head1 DESCRIPTION

Once created, the object allows you to retrieve information about the point that the object represents.
For example you can create an object using a grid reference and the retrieve the latitude and longitude.

=head1 OPTIONS

These are the options accepted in the constructor. You MUST provide either a GridReference or Latitude and Longitude,
or Easting and Northing (the origin for these is the usual location of V 000000).

=over

=item Projection

Default is 'IRNATGRID', the Irish National Grid.
Other projections recognized are 'NATGRID', 'UTM29', 'UTM30', and 'UTM31', which stand for the National Grid (British),
and the UTM29 to 31 zones. This argument is a string.

NOTE: if you use a projection other than the default then the results for the gridReference() method will be wrong,
so the method will return undef.
However, you can use the northing() and easting() results instead to find the location in the desired projection.

=item GridReference

A grid reference string composed of the following: a 1-letter 100km square identifier; an even number of digits, from 2 to 10, 
depending on required accuracy. A standard 6-figure
reference such as 'M 345132' gives 100m accuracy. Case and whitespace is ignored here.

=item Latitude

The latitude of the point. Actually should be the latitude using the spheroid related to the grid projection but for most
purposes the difference is not too great. Specify the amount in any of these ways: as a decimal number of degrees, a reference
to an array of three values (i.e. [ $degrees, $minutes, $seconds ]), or as a string of the form '52d 13m 12s'. North is positive
degrees, south is negative degrees.

=item Longitude

As for latitude, except that east is positive degrees, west is negative degrees.

=item Easting

The number of metres east of the grid origin, using grid east.

=item Northing

The number of metres north of the grid origin, using grid north.

=item Userdata

The value of this option is a hash-reference, which you can fill with whatever you want - typical usage might be to specify
C<Userdata => { Name =E<gt> 'Dublin Observatory' }> but add whatever you want. Access using the data() method.

=back

=head1 METHODS

Most of these methods take no arguments. Some are inherited from Geography::NationalGrid

=over 4

=item latitude

Returns the latitude of the point in a floating point number of degrees, north being positive.

=item longitude

As latitude, but east is positive degrees.

=item gridReference( [ RESOLUTION ] )

Returns the grid reference of the point in standard format. The default resolution is 100m, or if you used a grid
reference in the constructor then the default resolution is the resolution of that reference.
You can explicitly set the resolution to 1, 10, 100, 1000, or 10000 metres.

=item easting

How many metres east of the origin the point is. The precision of this value depends on how it was derived, but is truncated
to an integer number of metres. For example if the object was created from a 6 figure grid reference the easting only has precision
to 100m.

=item northing

How many metres north of the origin the point is. The precision of this value depends on how it was derived, but is truncated
to an integer number of metres.

=item deg2string( DEGREES )

Given a floating point number of degrees, returns a string of the form '51d 38m 34.34s'. Intended for formatting, like:
$self->deg2string( $self->latitude );

=item data( PARAMETER_NAME )

Returns the item from the Userdata hash whose key is the PARAMETER_NAME.

=back

=head1 ACCURACY AND PRECISION

The routines used in this code may not give you completely accurate results for various mathematical and theoretical reasons.
In tests the results appeared to be correct, but it may be that under certain conditions the output
could be highly inaccurate. It is likely that output accuracy decreases further from the datum, and behaviour is probably divergent
outside the intended area of the grid.

This module has been coded in good faith but it may still get things wrong.
Hence, it is recommended that this module is used for preliminary calculations only, and that it is NOT used under any
circumstance where its lack of accuracy could cause any harm, loss or other problems of any kind. Beware!

=head1 REFERENCES

Equations for converting co-ordinate systems appear in the guide at http://www.gps.gov.uk/guidecontents.asp - entitled
"A guide to coordinate systems in Great Britain: A primer on coordinate system concepts, including full information on GPS and Ordnance Survey coordinate systems."

Irish National Grid letter-pairs checked at http://www.evoxfacilities.co.uk/evoxig.htm

Constants also checked at http://www.ddl.org/figtree/pub/proceedings/korea/full-papers/session8/cory-morgan-bray-greenway.htm

ISO 3166 Country codes checked against http://www.din.de/gremien/nas/nabd/iso3166ma/codlstp1/en_listp1.html

Conversions compared with software from ftp://ftp.kv.geo.uu.se/pub/ and online services

=head1 AUTHOR AND COPYRIGHT

Copyright (c) 2002 P Kent. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

$Revision: 1.2 $

=cut
