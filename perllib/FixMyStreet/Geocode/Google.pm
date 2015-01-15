# FixMyStreet::Geocode::Google
# The geocoding functions for FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode::Google;

use strict;
use Encode;
use File::Slurp;
use File::Path ();
use LWP::Simple;
use Digest::MD5 qw(md5_hex);
use mySociety::Locale;

# string STRING CONTEXT
# Looks up on Google Maps API, and caches, a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one. The information in the query
# may be used to disambiguate the location in cobranded versions of the site.
sub string {
    my ( $s, $c ) = @_;

    my $params = $c->cobrand->disambiguate_location($s);

    $s = FixMyStreet::Geocode::escape($s);

    my $url = 'http://maps.google.com/maps/geo?q=' . $s;
    $url .=  '&ll=' . $params->{centre}  if $params->{centre};
    $url .= '&spn=' . $params->{span}    if $params->{span};
    if ($params->{google_country}) {
        $url .=  '&gl=' . $params->{google_country};
    } elsif ($params->{country}) {
        $url .=  '&gl=' . $params->{country};
    }
    $url .=  '&hl=' . $params->{lang}    if $params->{lang};

    my $cache_dir = FixMyStreet->config('GEO_CACHE') . 'google/';
    my $cache_file = $cache_dir . md5_hex($url);
    my $js;
    if (-s $cache_file) {
        $js = File::Slurp::read_file($cache_file);
    } else {
        # For some reason adding gl=uk is no longer sufficient to make google
        # think we are in the UK for some locations so we explictly add UK to
        # the address. We do it here so as not to invalidate existing cache
        # entries
        if (   $c->cobrand->country eq 'GB'
            && $url !~ /,\+UK/
            && $url !~ /united\++kingdom$/ )
        {
            if ( $url =~ /&/ ) {
                $url =~ s/&/,+UK&/;
            } else {
                $url .= ',+UK';
            }
        }
        $url .= '&sensor=false&key=' . FixMyStreet->config('GOOGLE_MAPS_API_KEY');
        $js = LWP::Simple::get($url);
        $js = encode_utf8($js) if utf8::is_utf8($js);
        File::Path::mkpath($cache_dir);
        File::Slurp::write_file($cache_file, $js) if $js && $js !~ /"code":6[12]0/;
    }

    if (!$js) {
        return { error => _('Sorry, we could not parse that location. Please try again.') };
    }

    $js = JSON->new->utf8->allow_nonref->decode($js);
    if ($js->{Status}->{code} ne '200') {
        return { error => _('Sorry, we could not find that location.') };
    }

    my $results = $js->{Placemark};
    my ( $error, @valid_locations, $latitude, $longitude );
    foreach (@$results) {
        next unless $_->{AddressDetails}->{Accuracy} >= 4;
        my $address = $_->{address};
        next unless $c->cobrand->geocoded_string_check( $address );
        ( $longitude, $latitude ) = @{ $_->{Point}->{coordinates} };
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

1;
