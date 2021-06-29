# FixMyStreet::Map::OS::Base
#
# Provides configuration for using the OS Maps API classes.
# In your COBRAND_FEATURES configuration, you can supply:
# * os_maps_url: Optional proxy URL, defaults to direct access
# * os_maps_api_key: Your API key
# * os_maps_layer: Which layer to use (Road_3857, Outdoor_3857, Light_3857)
# * os_maps_premium: Boolean for if you have a Premium account and can access more zoom levels

package FixMyStreet::Map::OS::Base;

use Moo::Role;

has '+min_zoom_level_any' => ( is => 'ro', default => 7 );

has '+zoom_levels' => ( is => 'lazy', default => sub {
    $_[0]->cobrand->feature('os_maps_premium') ? 8 : 4
} );

has '+base_tile_url' => ( is => 'lazy', default => sub {
    $_[0]->cobrand->feature('os_maps_url') || 'https://api.os.uk/maps/raster/v1/zxy/%s'
} );

has key => ( is => 'lazy', default => sub {
    $_[0]->cobrand->feature('os_maps_api_key') || ''
} );

has layer => ( is => 'lazy', default => sub {
    $_[0]->cobrand->feature('os_maps_layer') || 'Road_3857'
} );

has licence => ( is => 'lazy', default => sub {
    $_[0]->cobrand->feature('os_maps_licence') || ''
} );

around generate_map_data => sub {
    my ($orig, $self) = (shift, shift);
    my $data = $self->$orig(@_);
    $data->{os_maps} = {
        key => $self->key,
        layer => $self->layer,
        url => $self->base_tile_url,
        licence => $self->licence,
    };
    return $data;
};

1;
