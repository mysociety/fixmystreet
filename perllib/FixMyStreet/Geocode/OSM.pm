# FixMyStreet:Geocode::OSM
# OpenStreetmap forward and reverse geocoding for FixMyStreet.
#
# Copyright (c) 2011 Petter Reinholdtsen. Some rights reserved.
# Email: pere@hungry.com

package FixMyStreet::Geocode::OSM;

use warnings;
use strict;

use LWP::Simple;
use Memcached;
use XML::Simple;
use Utils;

my $osmapibase    = "https://api.openstreetmap.org/api/";
my $nominatimbase = "https://nominatim.openstreetmap.org/";

# string STRING CONTEXT
# Looks up on Nominatim, and caches, a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one. The information in the query
# may be used to disambiguate the location in cobranded versions of the site.
sub string {
    my ( $cls, $s, $c ) = @_;

    my $params = $c->cobrand->disambiguate_location($s);
    return $params->{result} if $params->{result};

    # Allow cobrand to fixup the user input
    $s = $params->{string} if $params->{string};

    $s = FixMyStreet::Geocode::escape($s);
    $s .= '%2C+' . $params->{town} if $params->{town} and $s !~ /$params->{town}/i;

    my $url = "${nominatimbase}search?";
    my %query_params = (
        q => $s,
        format => 'json',
        #'accept-language' => '',
        email => 'support' . chr(64) . 'fixmystreet.com',
    );
    $query_params{viewbox} = $params->{bounds}[1] . ',' . $params->{bounds}[2] . ',' . $params->{bounds}[3] . ',' . $params->{bounds}[0]
        if $params->{bounds};
    $query_params{bounded} = 1
        if $params->{bounds};
    $query_params{countrycodes} = $params->{country}
        if $params->{country};
    $c->cobrand->call_hook(geocoder_munge_query_params => \%query_params);
    $url .= join('&', map { "$_=$query_params{$_}" } sort keys %query_params);

    $c->stash->{geocoder_url} = $url;
    my $js = FixMyStreet::Geocode::cache('osm', $url);
    if (!$js) {
        return { error => _('Sorry, we could not find that location.') };
    }

    my ( $error, @valid_locations, $latitude, $longitude, $address );
    foreach (@$js) {
        next if $params->{result_only_if} && $_->{display_name} !~ /$params->{result_only_if}/;
        $_->{display_name} =~ s/$params->{result_strip}//g if $params->{result_strip};

        $c->cobrand->call_hook(geocoder_munge_results => $_);
        next unless $_->{display_name};
        ( $latitude, $longitude ) =
            map { Utils::truncate_coordinate($_) }
            ( $_->{lat}, $_->{lon} );
        $address = $_->{display_name};
        push (@$error, {
            address => $address,
            icon => $_->{icon},
            latitude => $latitude,
            longitude => $longitude
        });
        push (@valid_locations, $_);
    }

    return { latitude => $latitude, longitude => $longitude, address => $address } if scalar @valid_locations == 1;
    return { error => $error };
}

sub reverse_geocode {
    my ($cls, $cobrand, $latitude, $longitude, $zoom) = @_;
    $zoom ||= 18; # zoom level 18 for building results
    return if FixMyStreet->test_mode;
    my $url = "${nominatimbase}reverse?format=jsonv2&zoom=$zoom&lat=$latitude&lon=$longitude";
    my $j = FixMyStreet::Geocode::cache('osm', $url);
    return $j ? $j : undef;
}

sub _osmxml_to_hash {
    my ($xml, $type) = @_;
    my $ref = XMLin($xml);
    my %tags;
    if ('ARRAY' eq ref $ref->{$type}->{tag}) {
        map { $tags{$_->{'k'}} = $_->{'v'} } @{$ref->{$type}->{tag}};
        return \%tags;
    } else {
        return undef;
    }
}

sub get_object_tags {
    my ($type, $id) = @_;
    my $url = "${osmapibase}0.6/$type/$id";
    my $key = "OSM:get_object_tags:$url";
    my $result = Memcached::get($key);
    unless ($result) {
        my $j = LWP::Simple::get($url);
        if ($j) {
            Memcached::set($key, $j, 3600);
            return _osmxml_to_hash($j, $type);
        } else {
            print STDERR "No reply from $url\n";
        }
        return undef;
    }
    return _osmxml_to_hash($result, $type);
}

# A better alternative might be
# http://www.geonames.org/maps/osm-reverse-geocoder.html#findNearbyStreetsOSM
sub get_nearest_road_tags {
    my ( $cls, $cobrand, $latitude, $longitude ) = @_;
    my $inforef = $cls->reverse_geocode($cobrand, $latitude, $longitude, 16);
    if (exists $inforef->{result}->{osm_type}
        && 'way' eq $inforef->{result}->{osm_type}) {
        my $osmtags = get_object_tags('way',
                                      $inforef->{result}->{osm_id});
        unless ( exists $osmtags->{operator} ) {
            $osmtags->{operatorguess} = $cobrand->guess_road_operator( $osmtags );
        }
        return $osmtags;
    }
    return undef;
}

sub closest_road_text {
    my ( $cls, $cobrand, $latitude, $longitude ) = @_;
    my $str = '';
    my $osmtags = $cls->get_nearest_road_tags( $cobrand, $latitude, $longitude );
    if ($osmtags) {
        my ($name, $ref) = ('','');
        $name =  $osmtags->{name} if exists $osmtags->{name};
        $ref = " ($osmtags->{ref})" if exists $osmtags->{ref};
        if ($name || $ref) {
            $str .= _('The following information about the nearest road might be inaccurate or irrelevant, if the problem is close to several roads or close to a road without a name registered in OpenStreetMap.') . "\n\n";
            $str .= sprintf(_("Nearest named road to the pin placed on the map (automatically generated using OpenStreetMap): %s%s"),
                            $name, $ref) . "\n\n";

            if (my $operator = $osmtags->{operator}) {
                $str .= sprintf(_("Road operator for this named road (from OpenStreetMap): %s"),
                                $operator) . "\n\n";
            } elsif ($operator = $osmtags->{operatorguess}) {
                $str .= sprintf(_("Road operator for this named road (derived from road reference number and type): %s"),
                                $operator) . "\n\n";
            }
        }
    }
    return $str;
}

1;

