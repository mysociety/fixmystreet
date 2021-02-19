use Test::More;
use FixMyStreet::Map::FMS;

#   Z   NI  Aerial
my $expected = {
    10 => {
        0 => {
            0 => 'ch/1010100100.*?=G,L',
            1 => 'ch/1010100100.*?A,G,L',
        },
        1 => {
            0 => 'ch/1010100100.*?=G,L',
            1 => 'ch/1010100100.*?A,G,L',
       },
    },
    13 => {
        0 => {
            0 => 'r3131010100100.*?mmOS',
            1 => 'ch/3131010100100.*?A,G,L',
        },
        1 => {
            0 => 'ch/3131010100100.*?=G,L',
            1 => 'ch/3131010100100.*?A,G,L',
        },
    },
    16 => {
        0 => {
            0 => 'oml/16/32420/21504',
            1 => 'ch/0313131010100100.*?A,G,L',
        },
        1 => {
            0 => 'ch/0313131010100100.*?=G,L',
            1 => 'ch/0313131010100100.*?A,G,L',
        },
    },
};

subtest "Correct tiles with various parameters" => sub {
    my $map = FixMyStreet::Map::FMS->new;
    for my $aerial (0, 1) {
        for my $ni (0, 1) {
            for my $zoom (qw(10 13 16)) {
                my $tiles = $map->map_tiles(
                    x_tile => 32421, y_tile => 21505, zoom_act => $zoom,
                    aerial => $aerial,
                    latitude => $ni ? 55 : 51,
                    longitude => $ni ? -6 : -2,
                );
                my $wanted = $expected->{$zoom}{$ni}{$aerial};
                like $tiles->[0], qr/$wanted/, "with zoom $zoom, NI $ni, aerial $aerial";
            }
        }
    }
};

done_testing();
