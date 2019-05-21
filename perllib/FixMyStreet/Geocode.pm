# FixMyStreet::Geocode
# The geocoding functions for FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode;

use strict;
use Digest::MD5 qw(md5_hex);
use Encode;
use JSON::MaybeXS;
use LWP::Simple qw($ua);
use Path::Tiny;
use URI::Escape;
use Utils;

use Module::Pluggable
  sub_name    => 'geocoders',
  search_path => __PACKAGE__,
  require => 1,
  except => qr/Address/;

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

    my $service = $c->cobrand->get_geocoder();
    $service = $service->{type} if ref $service;

    $service = __PACKAGE__ . '::' . $service;
    my %avail = map { $_ => 1 } __PACKAGE__->geocoders;

    if (!$avail{$service} || ($service->can('setup') && !$service->setup)) {
        $service = __PACKAGE__ . '::OSM';
    }

    return $service->string($s, $c);
}

# escape STRING CONTEXT
# Escapes string for putting in URL geocoding call
sub escape {
    my ($s, $c) = @_;
    $s = lc($s);
    $s =~ s/[^-&\w ',]/ /g;
    $s =~ s/\s+/ /g;
    $s = URI::Escape::uri_escape_utf8($s);
    $s =~ s/%20/+/g;
    return $s;
}

sub cache {
    my ($type, $url, $args, $re) = @_;

    my $cache_dir = path(FixMyStreet->config('GEO_CACHE'), $type)->absolute(FixMyStreet->path_to());
    my $cache_file = $cache_dir->child(md5_hex($url));
    my $js;
    if (-s $cache_file && -M $cache_file <= 7 && !FixMyStreet->config('STAGING_SITE')) {
        # uncoverable statement
        $js = $cache_file->slurp_utf8;
    } else {
        $url .= '&' . $args if $args;
        $ua->timeout(15);
        $js = LWP::Simple::get($url);
        # The returned data is not correctly decoded if the content type is
        # e.g. application/json. Which all of our geocoders return.
        # uncoverable branch false
        $js = decode_utf8($js) if !utf8::is_utf8($js);
        if ($js && (!$re || $js !~ $re) && !FixMyStreet->config('STAGING_SITE')) {
            $cache_dir->mkpath; # uncoverable statement
            # uncoverable statement
            $cache_file->spew_utf8($js);
        }
    }
    $js = JSON->new->allow_nonref->decode($js) if $js;
    return $js;
}

1;
