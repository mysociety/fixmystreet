package FixMyStreet::Cobrand::FixaMinGata;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

use Carp;
use mySociety::MaPit;
use FixMyStreet::Geocode::FixaMinGata;
use DateTime;

sub country {
    return 'SE';
}

sub languages { [ 'sv,Swedish,sv_SE' ] }
sub language_override { 'sv' }

sub enter_postcode_text {
    my ( $self ) = @_;
    return _('Enter a nearby postcode, or street name and area');
}

# Is also adding language parameter
sub disambiguate_location {
    return {
        lang => 'sv',
        country => 'se', # Is this the right format? /Rikard
    };
}

sub area_types {
    [ 'KOM' ];
}

sub admin_base_url {
    return 'http://www.fixamingata.se/admin/';
}

# If lat/lon are present in the URL, OpenLayers will use that to centre the map.
# Need to specify a zoom to stop it defaulting to null/0.
sub uri {
    my ( $self, $uri ) = @_;

    $uri->query_param( zoom => 3 )
      if $uri->query_param('lat') && !$uri->query_param('zoom');

    return $uri;
}

sub geocode_postcode {
    my ( $self, $s ) = @_;
    #    Most people write Swedish postcodes like this:
    #+   XXX XX, so let's remove the space
    #    Is this the right place to do this? //Rikard
    #	 This is the right place! // Jonas
    $s =~ s/\ //g; # Rikard, remove space in postcode
    if ($s =~ /^\d{5}$/) {
        my $location = mySociety::MaPit::call('postcode', $s);
        if ($location->{error}) {
            return {
                error => $location->{code} =~ /^4/
                    ? _('That postcode was not recognised, sorry.')
                    : $location->{error}
            };
        }
        return {
            latitude  => $location->{wgs84_lat},
            longitude => $location->{wgs84_lon},
        };
    }
    return {};
}

# Vad gör den här funktionen? Är "Sverige" rätt här?
sub geocoded_string_check {
    my ( $self, $s ) = @_;
    return 1 if $s =~ /, Sverige/;
    return 0;
}

sub find_closest {
    my ( $self, $latitude, $longitude ) = @_;
    return FixMyStreet::Geocode::OSM::closest_road_text( $self, $latitude, $longitude );
}

# Used by send-reports, calling find_closest, calling OSM geocoding
sub guess_road_operator {
    my ( $self, $inforef ) = @_;

    my $highway = $inforef->{highway} || "unknown";
    my $refs    = $inforef->{ref}     || "unknown";
    return "Trafikverket"
        if $highway eq "trunk" || $highway eq "primary";

    for my $ref (split(/;/, $refs)) {
        return "Trafikverket"
            if $ref =~ m/E ?\d+/ || $ref =~ m/Fv\d+/i;
    }
    return '';
}

sub remove_redundant_councils {
    my $self = shift;
    my $all_councils = shift;

    # Oslo is both a kommune and a fylke, we only want to show it once
    # Jag tror inte detta är applicerbart på Sverige ;-) //Rikard
    #delete $all_councils->{301}     #
    #    if $all_councils->{3};
}

sub filter_all_council_ids_list {
    my $self = shift;
    my @all_councils_ids = @_;

    # as above we only want to show Oslo once
    # Rikard kommenterar ut detta.
    # return grep { $_ != 301 } @all_councils_ids;
    # Rikard:
    return  @all_councils_ids; # Är detta rätt? //Rikard
}

# The pin is green is it's fixed, yellow if it's closed (but not fixed), and
# red otherwise.
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'green' if $p->is_fixed;
    return 'yellow' if $p->is_closed;
    return 'red';
}

1;
