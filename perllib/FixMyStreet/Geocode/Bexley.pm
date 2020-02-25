package FixMyStreet::Geocode::Bexley;
use parent 'FixMyStreet::Geocode::OSM';

use warnings;
use strict;

use URI::Escape;

my $base = 'http://tilma.mysociety.org/mapserver/bexley?SERVICE=WFS&VERSION=1.1.0&REQUEST=GetFeature&TYPENAME=Streets&outputFormat=geojson&Filter=%3CFilter%3E%3CPropertyIsLike%20wildcard=%27*%27%20singleChar=%27.%27%20escape=%27!%27%3E%3CPropertyName%3EADDRESS%3C/PropertyName%3E%3CLiteral%3E{{str}}%3C/Literal%3E%3C/PropertyIsLike%3E%3C/Filter%3E';

# Data is ALL CAPS
sub recase {
    my $word = shift;
    return $word if $word =~ /FP/;
    return lc $word if $word =~ /^(AND|TO)$/;
    return ucfirst lc $word;
}

sub string {
    my ($cls, $s, $c) = @_;

    my $osm = $cls->SUPER::string($s, $c);
    my $js = query_layer($s);
    return $osm unless $js && @{$js->{features}};

    $c->stash->{geocoder_url} = $s;

    my ( $error, @valid_locations, $latitude, $longitude, $address );
    foreach (sort { $a->{properties}{ADDRESS} cmp $b->{properties}{ADDRESS} } @{$js->{features}}) {
        my @lines = @{$_->{geometry}{coordinates}};
        @lines = ([ @lines ]) if $_->{geometry}{type} eq 'LineString';
        my @points = map { @$_ } @lines;
        my $mid = int @points/2;
        my $e = $points[$mid][0];
        my $n = $points[$mid][1];
        ( $latitude, $longitude ) = Utils::convert_en_to_latlon_truncated( $e, $n );
        $address = sprintf("%s, %s", $_->{properties}{ADDRESS}, $_->{properties}{TOWN});
        $address =~ s/([\w']+)/recase($1)/ge;
        push @$error, {
            address => $address,
            latitude => $latitude,
            longitude => $longitude
        };
        push (@valid_locations, $_);
    }

    if ($osm->{latitude}) { # one result from OSM
        push @$error, {
            address => $osm->{address},
            latitude => $osm->{latitude},
            longitude => $osm->{longitude},
        };
        return { error => $error };
    }

    if (ref $osm->{error} eq 'ARRAY') {
        push @$error, @{$osm->{error}};
        return { error => $error };
    }

    return { latitude => $latitude, longitude => $longitude, address => $address }
        if scalar @valid_locations == 1;
    return { error => $error };
}

sub query_layer {
    my $s = uc shift;
    $s = URI::Escape::uri_escape_utf8("*$s*");
    (my $url = $base) =~ s/\{\{str\}\}/$s/;
    return FixMyStreet::Geocode::cache('bexley', $url);
}
