# FixMyStreet::Geocode
# The geocoding functions for FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode;

use strict;
use Digest::MD5 qw(md5_hex);
use Encode;
use File::Slurp;
use File::Path ();
use LWP::Simple qw($ua);
use URI::Escape;
use FixMyStreet::Geocode::Bing;
use FixMyStreet::Geocode::Google;
use FixMyStreet::Geocode::OSM;
use FixMyStreet::Geocode::Zurich;
use Utils;

# lookup STRING CONTEXT
# Given a user-inputted string, try and convert it into co-ordinates using either
# MaPit if it's a postcode, or some web API otherwise. Returns an array of
# data, including an error if there is one. The information in the query may be
# used by cobranded versions of the site to diambiguate locations.
sub lookup {
    my ($s, $c) = @_;
    my $data = $c->cobrand->geocode_postcode($s);
    if (defined $data->{latitude}) {
        ( $data->{latitude}, $data->{longitude} ) =
            map { Utils::truncate_coordinate($_) }
            ( $data->{latitude}, $data->{longitude} );
    }
    $data = string($s, $c)
        unless $data->{error} || defined $data->{latitude};
    $data->{error} = _('Sorry, we could not find that location.')
        unless $data->{error} || defined $data->{latitude};
    return ( $data->{latitude}, $data->{longitude}, $data->{error} );
}

# string STRING CONTEXT
# Passes the string to some external API to look stuff up.
sub string {
    my ($s, $c) = @_;

    my $service = $c->cobrand->get_geocoder($c);
    $service = $service->{type} if ref $service;
    $service = 'OSM' unless $service =~ /^(Bing|Google|OSM|Zurich)$/;
    $service = 'OSM' if $service eq 'Bing' && !FixMyStreet->config('BING_MAPS_API_KEY');
    $service = "FixMyStreet::Geocode::${service}::string";

    no strict 'refs';
    return &$service($s, $c);
}

# escape STRING CONTEXT
# Escapes string for putting in URL geocoding call
sub escape {
    my ($s, $c) = @_;
    $s = lc($s);
    $s =~ s/[^-&\w ']/ /g;
    $s =~ s/\s+/ /g;
    $s = URI::Escape::uri_escape_utf8($s);
    $s =~ s/%20/+/g;
    return $s;
}

sub cache {
    my ($type, $url, $args, $re) = @_;
    my $cache_dir = FixMyStreet->config('GEO_CACHE') . $type . '/';
    my $cache_file = $cache_dir . md5_hex($url);
    my $js;
    if (-s $cache_file && -M $cache_file <= 7) {
        $js = File::Slurp::read_file($cache_file);
    } else {
        $url .= '&' . $args if $args;
        $ua->timeout(15);
        $js = LWP::Simple::get($url);
        $js = encode_utf8($js) if utf8::is_utf8($js);
        File::Path::mkpath($cache_dir);
        if ($js && (!$re || $js !~ $re)) {
            File::Slurp::write_file($cache_file, $js);
        }
    }
    $js = JSON->new->utf8->allow_nonref->decode($js) if $js;
    return $js;
}

1;
