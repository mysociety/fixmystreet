use Test::More;
use FixMyStreet::Map::Bing;

my $map = FixMyStreet::Map::Bing->new;

my $tiles = $map->map_tiles(x_tile => 8105, y_tile => 5375, zoom_act => 14);
$tiles = [ map { m{ch/([^?]*)}; $1; } @$tiles ];
is_deeply $tiles, [ '03131132323220', '03131132323221', '03131132323222', '03131132323223' ];

$tiles = $map->map_tiles(x_tile => 8105, y_tile => 5375, zoom_act => 14, aerial => 1);
$tiles = [ map { m{ch/([^?]*)\?.*A,G,L}; $1; } @$tiles ];
is_deeply $tiles, [ '03131132323220', '03131132323221', '03131132323222', '03131132323223' ];

done_testing();
