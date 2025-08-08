# FixMyStreet:Map::Base
# Base map class

package FixMyStreet::Map::Base;

use Moo;
use FixMyStreet::Gaze;
use Utils;

has zoom_levels => ( is => 'ro', default => 7 );
has min_zoom_level => ( is => 'ro', default => 13 );
has min_zoom_level_any => ( is => 'ro', default => 0 );
has default_zoom => ( is => 'ro', default => 3 );

has cobrand => ( is => 'ro' );
has distance => ( is => 'ro' );
has zoom => (is => 'ro' );

has latitude => ( is => 'ro' );
has longitude => ( is => 'ro' );

# display_map C PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# CLICKABLE is set if the map is clickable
# PINS is array of pins to show, location and colour
sub display_map {
    my ($cls, $c, %params) = @_;

    # Map centre may be overridden in the query string
    $params{latitude} = Utils::truncate_coordinate($c->get_param('lat') + 0)
        if defined $c->get_param('lat');
    $params{longitude} = Utils::truncate_coordinate($c->get_param('lon') + 0)
        if defined $c->get_param('lon');
    $params{zoomToBounds} = $params{any_zoom} && !defined $c->get_param('zoom');

    $params{aerial} = $c->get_param("aerial") && $c->cobrand->call_hook('has_aerial_maps') ? 1 : 0;

    my $map = $cls->new({
        # Co-ordinates are in case the layer needs to decide things
        # based upon that, such as OSM in Northern Ireland
        latitude => $params{latitude},
        longitude => $params{longitude},
        cobrand => $c->cobrand,
        distance => $c->stash->{distance},
        defined $c->get_param('zoom') ? (zoom => $c->get_param('zoom') + 0) : (),
    });
    $c->stash->{map} = $map->generate_map_data(%params);
}

sub calculate_zoom {
    my ($self, %params) = @_;

    my $numZoomLevels = $self->zoom_levels;
    my $zoomOffset = $self->min_zoom_level;
    my $anyZoomOffset = $self->min_zoom_level_any;

    # Adjust zoom level dependent upon population density if cobrand hasn't
    # specified a default zoom.
    my $default_zoom;
    if (my $cobrand_default_zoom = $self->cobrand->default_map_zoom) {
        $default_zoom = $cobrand_default_zoom;
    } else {
        my $dist = $self->distance
            || FixMyStreet::Gaze::get_radius_containing_population( $self->latitude, $self->longitude );
        $default_zoom = $dist < 10 ? $self->default_zoom : $self->default_zoom - 1;
    }

    if ($params{any_zoom}) {
        $numZoomLevels += $zoomOffset - $anyZoomOffset;
        $default_zoom += $zoomOffset - $anyZoomOffset;
        $zoomOffset = $anyZoomOffset;
    }

    my $zoom = $self->zoom // $default_zoom;
    $zoom = $numZoomLevels - 1 if $zoom >= $numZoomLevels;
    $zoom = 0 if $zoom < 0;

    return {
        zoom => $zoom,
        zoom_act => $zoomOffset + $zoom,
        numZoomLevels => $numZoomLevels,
        zoomOffset => $zoomOffset,
    };
}

1;
