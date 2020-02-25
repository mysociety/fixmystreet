use FixMyStreet::TestMech;

use FixMyStreet::Map::MasterMap;

subtest 'correct map tiles used' => sub {
    my %test = (
        16 => [ '-', 'oml' ],
        20 => [ '.', 'mastermap-staging' ]
    );
    foreach my $zoom (qw(16 20)) {
        my $tiles = FixMyStreet::Map::MasterMap->map_tiles(x_tile => 123, y_tile => 456, zoom_act => $zoom);
        my ($sep, $lyr) = @{$test{$zoom}};
        is_deeply $tiles, [
            "//a${sep}tilma.mysociety.org/$lyr/$zoom/122/455.png",
            "//b${sep}tilma.mysociety.org/$lyr/$zoom/123/455.png",
            "//c${sep}tilma.mysociety.org/$lyr/$zoom/122/456.png",
            "//tilma.mysociety.org/$lyr/$zoom/123/456.png",
        ];
    }
};

done_testing();
