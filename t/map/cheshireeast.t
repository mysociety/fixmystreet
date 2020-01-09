use Test::More;
use FixMyStreet::Map::CheshireEast;

# https://maps-cache.cheshiresharedservices.gov.uk/maps/?wmts/CE_OS_AllBasemaps_COLOUR/oscce_grid/10/10187/8134.jpeg&KEY=3a3f5c60eca1404ea114e6941c9d3895
my $tiles = FixMyStreet::Map::CheshireEast->map_tiles(x_tile => 10187, y_tile => 8134, zoom_act => 10);
$tiles = [ map { m{(\d+/\d+/\d+)}; $1; } @$tiles ];
is_deeply $tiles, [ '10/10186/8133', '10/10187/8133', '10/10186/8134', '10/10187/8134' ];

use Data::Dumper;
my ($x, $y) = FixMyStreet::Map::CheshireEast->latlon_to_tile_with_adjust(53.150624, -2.386809, 10);
is $x, 10187;
is $y, 8134;

my ($lat, $lon) = FixMyStreet::Map::CheshireEast->tile_to_latlon(10187, 8134, 10);
is sprintf("%.6f", $lat), 53.150624;
is sprintf("%.6f", $lon), -2.386809;

done_testing();
