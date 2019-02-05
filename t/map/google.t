use FixMyStreet::Map::Google;
use FixMyStreet::Test;

use Catalyst::Test 'FixMyStreet::App';

my $c = ctx_request('/');

FixMyStreet::Map::Google->display_map($c, any_zoom => 1);

is_deeply $c->stash->{map}, {
    any_zoom => 1,
    zoomToBounds => 1,
    type => 'google',
    zoom => 15,
    zoomOffset => 0,
    numZoomLevels => 19,
    zoom_act => 15,
};

done_testing();

