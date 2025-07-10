package FixMyStreet::Geocode::Buckinghamshire;
use parent 'FixMyStreet::Geocode::OSM';

use warnings;
use strict;

use Try::Tiny;
use URI::Escape;
use XML::Simple;

my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
my $base = 'https://' . $host . '/proxy/bucks_prow/wfs/?SERVICE=WFS&VERSION=1.1.0&REQUEST=GetFeature&TYPENAME=RouteWFS&filter=%3CFilter%3E%3CPropertyIsLike%20wildcard="*"%20singleChar="."%20escape="!"%3E%3CPropertyName%3ERouteCode%3C/PropertyName%3E%3CLiteral%3E{{str}}%3C/Literal%3E%3C/PropertyIsLike%3E%3C/Filter%3E';

sub string {
    my ($cls, $s, $cobrand) = @_;

    my $osm = $cls->SUPER::string($s, $cobrand);
    my $data = query_layer($s);

    return $osm unless $data && @$data;

    my $out = { geocoder_url => $s };

    my ( $error, @valid_locations, $latitude, $longitude, $desc );
    # Data looks like this:
    # <gml:featureMember>
    #   <ms:RouteWFS>
    #     <ms:msGeometry>
    #       <gml:LineString srsName="EPSG:27700">
    #         <gml:posList srsDimension="2">X Y X Y X Y </gml:posList>
    #       </gml:LineString>
    #     </ms:msGeometry>
    #     <ms:DataType>Route</ms:DataType>
    #     <ms:RouteCode>XXX/MM/N</ms:RouteCode>
    #     <ms:StatusDescr>Footpath</ms:StatusDescr>
    #     <ms:AdminAreaDescr>Aylesbury</ms:AdminAreaDescr>
    #   </ms:RouteWFS>
    # </gml:featureMember>
    foreach (sort { $a->{'ms:RouteWFS'}{'ms:RouteCode'} cmp $b->{'ms:RouteWFS'}{'ms:RouteCode'} } @$data) {
        $_ = $_->{'ms:RouteWFS'};

        # Work out the 'middle' point along the line
        # Might be a "MultiCurve", might be a single "LineString"
        my $line = $_->{'ms:msGeometry'};
        $line = $line->{'gml:MultiCurve'}{'gml:curveMembers'}{'gml:LineString'}[0] || $line->{'gml:LineString'};
        $line = $line->{'gml:posList'}{'content'};
        my @coords = split / /, $line;
        my ($e, $n);
        if (@coords % 4) { # Odd number of points
            $e = $coords[@coords/2-1];
            $n = $coords[@coords/2];
        } else {
            $e = ($coords[@coords/2-2] + $coords[@coords/2]) / 2;
            $n = ($coords[@coords/2-1] + $coords[@coords/2+1]) / 2;
        }

        next unless $e && $n;
        ( $latitude, $longitude ) = Utils::convert_en_to_latlon_truncated( $e, $n );
        $desc = $_->{'ms:RouteCode'} . ', ' . $_->{'ms:StatusDescr'} . ', ' . $_->{'ms:AdminAreaDescr'};
        push @$error, {
            address => $desc,
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
        return { %$out, error => $error };
    }

    if (ref $osm->{error} eq 'ARRAY') {
        push @$error, @{$osm->{error}};
        return { %$out, error => $error };
    }

    return { %$out, latitude => $latitude, longitude => $longitude, address => $desc }
        if scalar @valid_locations == 1;
    return { %$out, error => $error };
}

sub query_layer {
    my $s = uc shift;
    $s = URI::Escape::uri_escape_utf8("*$s*");
    (my $url = $base) =~ s/\{\{str\}\}/$s/;
    my $response = FixMyStreet::Geocode::cache('bucks', $url, '', '', 1);
    my $x = XML::Simple->new(
        ForceArray => [ 'gml:featureMember' ],
        KeyAttr => {},
        SuppressEmpty => undef,
    );
    try {
        $x = $x->parse_string($response);
    };
    return $x->{'gml:featureMember'};
}
