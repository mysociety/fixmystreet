use Test::More;
use FixMyStreet::Cobrand;
use FixMyStreet::Map::FMS;
use FixMyStreet::Map::OS::API;

my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('fixmystreet');

subtest 'correct map tiles used' => sub {
    foreach (
        { zoom => 10, layer => 'Road_3857' },
        { zoom => 13, layer => 'Outdoor_3857' },
        { zoom => 16, layer => 'Light_3857' },
    ) {
        my $layer = $_->{layer};
        my $zoom = $_->{zoom};
        FixMyStreet::override_config {
            COBRAND_FEATURES => {
                os_maps_api_key => { default => "123" },
                os_maps_layer => { default => $layer },
            }
        }, sub {
            my $map = FixMyStreet::Map::OS::API->new({ cobrand => $cobrand });
            my $tiles = $map->map_tiles(x_tile => 123, y_tile => 456, zoom_act => $zoom);
            is_deeply $tiles, [
                "https://api.os.uk/maps/raster/v1/zxy/$layer/$zoom/122/455.png?key=123",
                "https://api.os.uk/maps/raster/v1/zxy/$layer/$zoom/123/455.png?key=123",
                "https://api.os.uk/maps/raster/v1/zxy/$layer/$zoom/122/456.png?key=123",
                "https://api.os.uk/maps/raster/v1/zxy/$layer/$zoom/123/456.png?key=123",
            ], "with $layer and $zoom";
        };
    }
};

subtest "Correct FMS tiles" => sub {
    foreach (
        { zoom => 10, expected => 'zxy/Road_3857/10/32420/21504.png\?key=456' },
        { zoom => 14, expected => 'zxy/Road_3857/14/32420/21504.png\?key=456' },
        { zoom => 16, layer => 'Light_3857', expected => 'zxy/Light_3857/16/32420/21504.png\?key=456' },
        { zoom => 18, layer => 'Road_3857', expected => 'zxy/Road_3857/18/32420/21504.png\?key=456' },
    ) {
        my $layer = $_->{layer};
        my $zoom = $_->{zoom};
        FixMyStreet::override_config {
            COBRAND_FEATURES => {
                os_maps_api_key => { default => "456" },
                os_maps_layer => { default => $layer },
                os_maps_premium => { default => 1 },
            }
        }, sub {
            my $map = FixMyStreet::Map::FMS->new({ cobrand => $cobrand });
            my $tiles = $map->map_tiles(x_tile => 32421, y_tile => 21505, zoom_act => $zoom);
            like $tiles->[0], qr/$_->{expected}/, "with zoom $zoom";
        };
    }
    foreach (
        { zoom => 10, expected => 'zxy/Road_3857/10/32420/21504.png\?key=456' },
        { zoom => 14, expected => 'zxy/Road_3857/14/32420/21504.png\?key=456' },
        { zoom => 16, layer => 'Light_3857', expected => 'zxy/Light_3857/16/32420/21504.png\?key=456' },
        { zoom => 18, expected => 'oml/18/32420/21504.png' },
    ) {
        my $layer = $_->{layer};
        my $zoom = $_->{zoom};
        FixMyStreet::override_config {
            COBRAND_FEATURES => {
                os_maps_api_key => { default => "456" },
                os_maps_layer => { default => $layer },
            }
        }, sub {
            my $map = FixMyStreet::Map::FMS->new({ cobrand => $cobrand });
            my $tiles = $map->map_tiles(x_tile => 32421, y_tile => 21505, zoom_act => $zoom);
            like $tiles->[0], qr/$_->{expected}/, "with zoom $zoom";
        };
    }
};

done_testing();
