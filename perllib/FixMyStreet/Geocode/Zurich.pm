# FixMyStreet::Geocode::Zurich
# Geocoding with Zurich web service.
#
# Thanks to http://msdn.microsoft.com/en-us/library/ms995764.aspx
# and http://noisemore.wordpress.com/2009/03/19/perl-soaplite-wsse-web-services-security-soapheader/
# for SOAP::Lite pointers
#
# Copyright (c) 2012 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode::Zurich;

use strict;
use Digest::MD5 qw(md5_hex);
use Geo::Coordinates::CH1903Plus;
use Path::Tiny;
use Storable;
use Utils;

my ($soap, $method, $security);

sub setup_soap {
    return if $soap;

    # Variables for the SOAP web service
    my $geocoder = FixMyStreet->config('GEOCODER');
    return unless ref $geocoder eq 'HASH';

    my $url = $geocoder->{url};
    my $username = $geocoder->{username};
    my $password = $geocoder->{password};
    my $attr = 'http://ch/geoz/fixmyzuerich/service';
    my $action = "$attr/IFixMyZuerich/";

    require SOAP::Lite;
    # SOAP::Lite->import( +trace => [transport => \&log_message ] );

    # Set up the SOAP handler
    $security = SOAP::Header->name("Security")->attr({
        'mustUnderstand' => 'true',
        'xmlns' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
    })->value(
        \SOAP::Header->name(
            "UsernameToken" => \SOAP::Header->value(
                SOAP::Header->name('Username', $username),
                SOAP::Header->name('Password', $password)
            )
        )
    );
    $soap = SOAP::Lite->on_action( sub { $action . $_[1]; } )->proxy($url);
    $method = SOAP::Data->name('getLocation95')->attr({ xmlns => $attr });
}

sub admin_district {
    my ($e, $n) = @_;

    setup_soap();
    return unless $soap;

    my $attr = 'http://ch/geoz/fixmyzuerich/service';
    my $bo = 'http://ch/geoz/fixmyzuerich/bo';
    my $method = SOAP::Data->name('getInfoByLocation')->attr({ xmlns => $attr });
    my $location = SOAP::Data->name(
        'location' => \SOAP::Data->value(
            SOAP::Data->name('bo:easting', $e),
            SOAP::Data->name('bo:northing', $n),
        )
    )->attr({ 'xmlns:bo' => $bo });
    my $search = SOAP::Data->value($location);
    my $result;
    eval {
        $result = $soap->call($method, $security, $search);
    };
    if ($@) {
        warn $@ if FixMyStreet->config('STAGING_SITE');
        return 'The geocoder appears to be down.';
    }
    $result = $result->result;
    return $result;
}

# string STRING CONTEXT
# Looks up on Zurich web service a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one.
# If there is no ambiguity, returns only a {lat,long} hash, unless allow_single_match_string is true
# (because the auto-complete use of this (in /around) should send the matched name even though it's not ambiguous).
#
# The information in the query may be used to disambiguate the location in cobranded 
# versions of the site.

sub string {
    my ( $cls, $s, $c ) = @_;

    setup_soap();

    my $cache_dir = path(FixMyStreet->config('GEO_CACHE'), 'zurich')->absolute(FixMyStreet->path_to());
    my $cache_file = $cache_dir->child(md5_hex($s));
    my $result;
    $c->stash->{geocoder_url} = $s;
    if (-s $cache_file && -M $cache_file <= 7 && !FixMyStreet->config('STAGING_SITE')) {
        $result = retrieve($cache_file);
    } else {
        my $search = SOAP::Data->name('search' => $s)->type('');
        my $count = SOAP::Data->name('count' => 10)->type('');
        eval {
            $result = $soap->call($method, $security, $search, $count);
        };
        if ($@) {
            warn $@ if FixMyStreet->config('STAGING_SITE');
            return { error => 'The geocoder appears to be down.' };
        }
        $result = $result->result;
        $cache_dir->mkpath;
        store $result, $cache_file if $result && !FixMyStreet->config('STAGING_SITE');
    }

    if (!$result || !$result->{Location}) {
        return { error => _('Sorry, we could not parse that location. Please try again.') };
    }

    my $results = $result->{Location};
    $results = [ $results ] unless ref $results eq 'ARRAY';

    my ( $error, @valid_locations, $latitude, $longitude );
    foreach (@$results) {
        ($latitude, $longitude) =
            map { Utils::truncate_coordinate($_) }
            Geo::Coordinates::CH1903Plus::to_latlon($_->{easting}, $_->{northing});
        push (@$error, {
            address => $_->{text},
            latitude => $latitude,
            longitude => $longitude
        });
        push (@valid_locations, $_);
        last if lc($_->{text}) eq lc($s);
    }
    if (scalar @valid_locations == 1 && ! $c->stash->{allow_single_geocode_match_strings} ) {
        return { latitude => $latitude, longitude => $longitude };
    }
    return { error => $error };
}

sub log_message {
    my ($in) = @_;
    eval {
        printf "log_message [$in]: %s\n\n", $in->content; # ...for example
    };
    if ($@) {
        print "log_message [$in]: ???? \n\n";
    }
}

1;

