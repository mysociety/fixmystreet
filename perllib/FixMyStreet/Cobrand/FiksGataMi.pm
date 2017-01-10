package FixMyStreet::Cobrand::FiksGataMi;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

use Carp;
use mySociety::MaPit;
use FixMyStreet::Geocode::OSM;

sub country {
    return 'NO';
}

sub languages { [ 'nb,Norwegian,nb_NO' ] }
sub language_override { 'nb' }

sub enter_postcode_text {
    my ( $self ) = @_;
    return _('Enter a nearby postcode, or street name and area');
}

# Is also adding language parameter
sub disambiguate_location {
    return {
        lang => 'no',
        country => 'no',
    };
}

sub area_types {
    my $self = shift;
    return $self->next::method() if FixMyStreet->staging_flag('skip_checks');
    [ 'NKO', 'NFY', 'NRA' ];
}

sub geocode_postcode {
    my ( $self, $s ) = @_;

    if ($s =~ /^\d{4}$/) {
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

sub geocoded_string_check {
    my ( $self, $s ) = @_;
    return 1 if $s =~ /, Norge/;
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

    return "Statens vegvesen"
        if $highway eq "trunk" || $highway eq "primary";

    for my $ref (split(/;/, $refs)) {
        return "Statens vegvesen"
            if $ref =~ m/E ?\d+/ || $ref =~ m/Fv\d+/i;
    }
    return '';
}

sub remove_redundant_areas {
    my $self = shift;
    my $all_areas = shift;

    # Oslo is both a kommune and a fylke, we only want to show it once
    delete $all_areas->{301}
        if $all_areas->{3};
}

sub short_name {
    my $self = shift;
    my ($area, $info) = @_;

    my $name = $area->{name} || $area->name;

    if ($name =~ /^(Os|Nes|V\xe5ler|Sande|B\xf8|Her\xf8y)$/) {
        my $parent = $info->{$area->{parent_area}}->{name};
        return URI::Escape::uri_escape_utf8("$name, $parent");
    }

    $name =~ s/ & / and /;
    $name = URI::Escape::uri_escape_utf8($name);
    $name =~ s/%20/+/g;
    return $name;
}

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

sub reports_body_check {
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

sub jurisdiction_id_example {
    'fiksgatami.no';
}

1;
