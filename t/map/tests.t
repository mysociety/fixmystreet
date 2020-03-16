use FixMyStreet::Map;
use Test::More;

my $requires = {
    'Bing' => 'map-bing-ol.js',
    'Bristol' => 'map-wmts-bristol.js',
    'Bromley' => 'map-fms.js',
    'Buckinghamshire' => 'map-wmts-buckinghamshire.js',
    'Lincolnshire' => 'lincolnshire/assets.js',
    'CheshireEast' => 'map-cheshireeast.js',
    'FMS' => 'map-fms.js',
    'Google' => 'map-google.js',
    'GoogleOL' => 'map-google-ol.js',
    'HighwaysEngland' => 'map-fms.js',
    'Hounslow' => 'map-wmts-hounslow.js',
    'IsleOfWight' => 'map-wmts-isleofwight.js',
    'OSM' => 'OpenStreetMap.js',
    'MasterMap' => 'map-mastermap.js',
    'Northamptonshire' => 'map-wms-northamptonshire.js',
    'CycleMap' => 'OpenStreetMap.js',
    'MapQuest' => 'OpenStreetMap.js',
    'StreetView' => 'map-streetview.js',
    'TonerLite' => 'map-toner-lite.js',
    'Zurich' => 'map-wmts-zurich.js',
};

foreach (FixMyStreet::Map->maps) {
    next if /WMTSBase|UKCouncilWMTS|WMSBase|WMXBase/; # Only its subclasses have JS
    my $js = $_->map_javascript;
    my $test_file = $js->[-1];
    s/.*:://;
    isnt $requires->{$_}, undef, "$_ requires present";
    like $test_file, qr/$requires->{$_}/, "$_ JS okay";
}

done_testing();
