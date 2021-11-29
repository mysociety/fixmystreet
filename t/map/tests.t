use FixMyStreet::Map;
use Test::More;

my $requires = {
    'Bing' => 'map-bing-ol.js',
    'Bristol' => 'map-wmts-bristol.js',
    'Bromley' => 'map-fms.js',
    'CheshireEast' => 'map-cheshireeast.js',
    'FMS' => 'map-fms.js',
    'Google' => 'map-google.js',
    'GoogleOL' => 'map-google-ol.js',
    'HighwaysEngland' => 'map-fms.js',
    'Hounslow' => 'map-wmts-hounslow.js',
    'Lincolnshire' => 'lincolnshire/assets.js',
    'MasterMap' => 'map-mastermap.js',
    'Northamptonshire' => 'map-wms-northamptonshire.js',
    'OS::FMS' => 'map-fms-os.js',
    'OS::API' => 'map-os.js',
    'OS::Premium' => 'map-os.js',
    'OSM' => 'OpenStreetMap.js',
    'OSM::CycleMap' => 'OpenStreetMap.js',
    'OSM::StreetView' => 'map-streetview.js',
    'OSM::TonerLite' => 'map-toner-lite.js',
    'Zurich' => 'map-wmts-zurich.js',
};

foreach (FixMyStreet::Map->maps) {
    next if /Base|UKCouncilWMTS/; # Only its subclasses have JS
    my $js = $_->map_javascript;
    my $test_file = $js->[-1];
    s/^FixMyStreet::Map:://;
    isnt $requires->{$_}, undef, "$_ requires present";
    like $test_file, qr/$requires->{$_}/, "$_ JS okay";
}

done_testing();
