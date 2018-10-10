use FixMyStreet::Map;
use Test::More;

my $requires = {
    'BathNES' => 'bathnes/assets.js',
    'Bing' => 'map-bing-ol.js',
    'Bristol' => 'bristol/assets.js',
    'Bromley' => 'bromley/assets.js',
    'Buckinghamshire' => 'buckinghamshire/assets.js',
    'Lincolnshire' => 'lincolnshire/assets.js',
    'FMS' => 'map-fms.js',
    'Google' => 'map-google.js',
    'GoogleOL' => 'map-google-ol.js',
    'OSM' => 'OpenStreetMap.js',
    'CycleMap' => 'OpenStreetMap.js',
    'MapQuest' => 'OpenStreetMap.js',
    'StreetView' => 'map-streetview.js',
    'TonerLite' => 'map-toner-lite.js',
    'Zurich' => 'map-wmts-zurich.js',
};

foreach (FixMyStreet::Map->maps) {
    next if /WMTSBase/; # Only its subclasses have JS
    my $js = $_->map_javascript;
    my $test_file = $js->[-1];
    s/.*:://;
    isnt $requires->{$_}, undef, "$_ requires present";
    like $test_file, qr/$requires->{$_}/, "$_ JS okay";
}

done_testing();
