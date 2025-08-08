use Test::More;
use FixMyStreet::Map::FMS;
use FixMyStreet::Cobrand;

my $cobrand = FixMyStreet::Cobrand::FixMyStreet->new;

#   Z   NI
my $expected = {
    10 => {
        0 => 'zxy/Road_3857/10/32420/21504',
        1 => '10/32420/21504.png',
    },
    13 => {
        0 => 'zxy/Road_3857/13/32420/21504',
        1 => '13/32420/21504.png',
    },
    16 => {
        0 => 'zxy/Road_3857/16/32420/21504',
        1 => '16/32420/21504.png',
    },
};

subtest "Correct tiles with various parameters" => sub {
    for my $ni (0, 1) {
        my $map = FixMyStreet::Map::FMS->new(
            cobrand => $cobrand,
            latitude => $ni ? 55 : 51,
            longitude => $ni ? -6 : -2,
        );
        for my $zoom (qw(10 13 16)) {
            my $tiles = $map->map_tiles(
                x_tile => 32421, y_tile => 21505, zoom_act => $zoom,
            );
            my $wanted = $expected->{$zoom}{$ni};
            like $tiles->[0], qr/$wanted/, "with zoom $zoom, NI $ni";
        }
    }
};

done_testing();
