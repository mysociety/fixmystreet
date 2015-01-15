# FixMyStreet::Geocode::Bing
# Geocoding with Bing for FixMyStreet.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode::Bing;

use strict;
use Encode;
use File::Slurp;
use File::Path ();
use LWP::Simple;
use Digest::MD5 qw(md5_hex);

use mySociety::Locale;

# string STRING CONTEXT
# Looks up on Bing Maps API, and caches, a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one. The information in the query
# may be used to disambiguate the location in cobranded versions of the site.
sub string {
    my ( $s, $c ) = @_;

    my $params = $c->cobrand->disambiguate_location($s);

    $s = FixMyStreet::Geocode::escape($s);
    $s .= '+' . $params->{town} if $params->{town} and $s !~ /$params->{town}/i;

    my $url = "http://dev.virtualearth.net/REST/v1/Locations?q=$s";
    $url .= '&userMapView=' . join(',', @{$params->{bounds}})
        if $params->{bounds};
    $url .= '&userLocation=' . $params->{centre} if $params->{centre};
    $url .= '&c=' . $params->{bing_culture} if $params->{bing_culture};

    my $cache_dir = FixMyStreet->config('GEO_CACHE') . 'bing/';
    my $cache_file = $cache_dir . md5_hex($url);
    my $js;
    if (-s $cache_file) {
        $js = File::Slurp::read_file($cache_file);
    } else {
        $url .= '&key=' . FixMyStreet->config('BING_MAPS_API_KEY');
        $js = LWP::Simple::get($url);
        $js = encode_utf8($js) if utf8::is_utf8($js);
        File::Path::mkpath($cache_dir);
        File::Slurp::write_file($cache_file, $js) if $js;
    }

    if (!$js) {
        return { error => _('Sorry, we could not parse that location. Please try again.') };
    }

    $js = JSON->new->utf8->allow_nonref->decode($js);
    if ($js->{statusCode} ne '200') {
        return { error => _('Sorry, we could not find that location.') };
    }

    my $results = $js->{resourceSets}->[0]->{resources};
    my ( $error, @valid_locations, $latitude, $longitude );

    foreach (@$results) {
        my $address = $_->{name};
        next if $params->{bing_country} && $_->{address}->{countryRegion} ne $params->{bing_country};

        # Getting duplicate, yet different, results from Bing sometimes
        next if @valid_locations
            && $_->{address}{postalCode} && $valid_locations[-1]{address}{postalCode} eq $_->{address}{postalCode}
            && ( $valid_locations[-1]{address}{locality} eq $_->{address}{adminDistrict2}
                || $valid_locations[-1]{address}{adminDistrict2} eq $_->{address}{locality}
                || $valid_locations[-1]{address}{locality} eq $_->{address}{locality}
               );

        ( $latitude, $longitude ) = @{ $_->{point}->{coordinates} };
        # These co-ordinates are output as query parameters in a URL, make sure they have a "."
        mySociety::Locale::in_gb_locale {
            push (@$error, {
                address => $address,
                latitude => sprintf('%0.6f', $latitude),
                longitude => sprintf('%0.6f', $longitude)
            });
        };
        push (@valid_locations, $_);
    }

    return { latitude => $latitude, longitude => $longitude } if scalar @valid_locations == 1;
    return { error => $error };
}

sub reverse {
    my ( $latitude, $longitude, $bing_culture, $cache ) = @_;

    # Get nearest road-type thing from Bing
    my $key = mySociety::Config::get('BING_MAPS_API_KEY', '');
    if ($key) {
        my $url = "http://dev.virtualearth.net/REST/v1/Locations/$latitude,$longitude?key=$key";
        $url .= '&c=' . $bing_culture if $bing_culture;
        my $j;
        if ( $cache ) {
            my $cache_dir = FixMyStreet->config('GEO_CACHE') . 'bing/';
            my $cache_file = $cache_dir . md5_hex($url);

            if (-s $cache_file) {
                $j = File::Slurp::read_file($cache_file);
            } else {
                $j = LWP::Simple::get($url);
                File::Path::mkpath($cache_dir);
                File::Slurp::write_file($cache_file, $j) if $j;
            }
        } else {
            $j = LWP::Simple::get($url);
        }

        if ($j) {
            $j = JSON->new->utf8->allow_nonref->decode($j);
            return $j;
        }
    }

    return undef;
}

1;
