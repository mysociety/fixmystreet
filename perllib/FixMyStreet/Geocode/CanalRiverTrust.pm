package FixMyStreet::Geocode::CanalRiverTrust;
use parent 'FixMyStreet::Geocode::OSM';

use warnings;
use strict;

use JSON::MaybeXS;
use Try::Tiny;

my $base = "https://services.arcgis.com/DknzyjEEie5tEW0u/arcgis/rest/services/{{LAYER}}/FeatureServer/0/query?outFields=waterway_name,sap_description&f=geojson&outSR=4326&inSR=3857&where=sap_description+like+'%25{{ASSET_SEARCH}}[^0-9]%25'{{CANAL_SEARCH}}";

sub string {
    my ($cls, $s, $cobrand) = @_;

    my $data = query_layer($s);
    if (!($data && @$data)) {
        return $cls->SUPER::string($s, $cobrand);
    };

    my $out = { geocoder_url => $s };
    my $error = [];

    my ( $latitude, $longitude );
    @$data = sort { $a->{properties}->{waterway_name} cmp $b->{properties}->{waterway_name} || $a->{properties}->{sap_description} cmp $b->{properties}->{sap_description} } @$data;
    for my $location (@$data) {
        push @$error, {
            address => $location->{properties}->{sap_description} . ", " . $location->{properties}->{waterway_name},
            longitude => $location->{geometry}->{coordinates}->[0],
            latitude => $location->{geometry}->{coordinates}->[1],
            zoom => 5,
        };
    };

    return { %$out, latitude => $data->[0]->{geometry}->{coordinates}->[1], longitude => $data->[0]->{geometry}->{coordinates}->[0], address => $data->[0]->{properties}->{sap_description} } if scalar @$data == 1;
    return { %$out, error => $error };
}

sub query_layer {
    my $s = uc shift;

    my ($canal, $asset_item, $number);
    if ($s =~ /(\w+)[\s\:]+(\d+)/) {
        $asset_item = $1; $number = $2;
        if ($s =~ /(\w+) (canal|navigation)/i) {
            $canal = $1;
        };
        my $url = _generate_url($asset_item, $number, $canal);
        return [] unless $url;

        try {
            my $response = decode_json(FixMyStreet::Geocode::cache('canalandrivertrust', $url, '', '', 1));
            return $response->{features} || [];
        } catch {
            return [];
        };
    } else {
        return [];
    }
}

sub _generate_url {
    my ($asset_item, $number, $canal) = @_;

    my $layer = _set_layer($asset_item);
    return '' unless $layer;

    (my $url = $base) =~ s/\{\{ASSET_SEARCH\}\}/$asset_item $number/;
    ($url = $url) =~ s/\{\{LAYER\}\}/$layer/;
    if ($canal) {
        ($url = $url) =~ s/\{\{CANAL_SEARCH\}\}/+and+waterway_name+like+%27%25$canal%25%27/;
    } else {
        ($url = $url) =~ s/\{\{CANAL_SEARCH\}\}//;
    }

    URI::Escape::uri_escape_utf8($url);
    return $url;
}

sub _set_layer {
    my $layer = shift;

    my %layers = (
          BRIDGE => 'Canal_And_River_Trust_Bridges_View',
          LOCK => 'Canal_And_River_Trust_Locks_View',
    );
    return %layers{$layer}
}
