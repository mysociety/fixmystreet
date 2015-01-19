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

sub languages { [ 'en-gb,English,en_GB', 'sv,Swedish,sv_SE' ] }
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

# Vad ska vi göra för svenska förhållanden här??? //Rikard
sub council_rss_alert_options {
    my $self         = shift;
    my $all_councils = shift;
    my $c            = shift;

    my ( @options, @reported_to_options, $fylke, $kommune );

    foreach ( values %$all_councils ) {
        if ( $_->{type} eq 'NKO' ) {
            $kommune = $_;
        }
        else {
            $fylke = $_;
        }
    }

    if ( $fylke->{id} == 3 ) {    # Oslo
        my $short_name = $self->short_name($fylke, $all_councils);
        ( my $id_name = $short_name ) =~ tr/+/_/;

        push @options,
          {
            type => 'council',
            id   => sprintf( 'council:%s:%s', $fylke->{id}, $id_name ),
            rss_text =>
              sprintf( _('RSS feed of problems within %s'), $fylke->{name} ),
            text => sprintf( _('Problems within %s'), $fylke->{name} ),
            uri => $c->uri_for( '/rss/reports', $short_name ),
          };
    }
    else {
        my $short_kommune_name = $self->short_name($kommune, $all_councils);
        ( my $id_kommune_name = $short_kommune_name ) =~ tr/+/_/;

        my $short_fylke_name = $self->short_name($fylke, $all_councils);
        ( my $id_fylke_name = $short_fylke_name ) =~ tr/+/_/;

        push @options,
          {
            type => 'area',
            id   => sprintf( 'area:%s:%s', $kommune->{id}, $id_kommune_name ),
            rss_text =>
              sprintf( _('RSS feed of %s'), $kommune->{name} ),
            text => $kommune->{name},
            uri => $c->uri_for( '/rss/area', $short_kommune_name ),
          },
          {
            type => 'area',
            id   => sprintf( 'area:%s:%s', $fylke->{id}, $id_fylke_name ),
            rss_text =>
              sprintf( _('RSS feed of %s'), $fylke->{name} ),
            text => $fylke->{name},
            uri => $c->uri_for( '/rss/area', $short_fylke_name ),
          };

        push @reported_to_options,
          {
            type => 'council',
            id => sprintf( 'council:%s:%s', $kommune->{id}, $id_kommune_name ),
            rss_text =>
              sprintf( _('RSS feed of %s'), $kommune->{name} ),
            text => $kommune->{name},
            uri => $c->uri_for( '/rss/reports', $short_kommune_name ),
          },
          {
            type => 'council',
            id   => sprintf( 'council:%s:%s', $fylke->{id}, $id_fylke_name ),
            rss_text =>
              sprintf( _('RSS feed of %s'), $fylke->{name} ),
            text => $fylke->{name},
            uri => $c->uri_for( '/rss/reports/', $short_fylke_name ),
          };
    }

    return (
          \@options, @reported_to_options
        ? \@reported_to_options
        : undef
    );

}

# Vad ska vi göra för svenska förhållanden här??? //Rikard
sub reports_council_check {
    my ( $self, $c, $council ) = @_;

    if ($council eq 'Oslo') {

        # There are two Oslos (kommune and fylke), we only want one of them.
        $c->stash->{council} = mySociety::MaPit::call('area', 3);
        return 1;

    } elsif ($council =~ /,/) {

        # Some kommunes have the same name, use the fylke name to work out which.
        my ($kommune, $fylke) = split /\s*,\s*/, $council;
        my $area_types = $c->cobrand->area_types;
        my $areas_k = mySociety::MaPit::call('areas', $kommune, type => $area_types);
        my $areas_f = mySociety::MaPit::call('areas', $fylke, type => $area_types);
        if (keys %$areas_f == 1) {
            ($fylke) = values %$areas_f;
            foreach (values %$areas_k) {
                if ($_->{name} eq $kommune && $_->{parent_area} == $fylke->{id}) {
                    $c->stash->{council} = $_;
                    return 1;
                }
            }
        }
        # If we're here, we've been given a bad name.
        $c->detach( 'redirect_index' );

    }
}

1;
