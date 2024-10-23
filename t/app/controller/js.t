use JSON::MaybeXS;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

subtest "check translation endpoint" => sub {
    $mech->get_ok('/js/translation_strings.en-gb.js');
    $mech->content_contains('translation_strings');
};

subtest "check asset layer endpoint" => sub {
    $mech->get_ok('/js/asset_layers.js');
    $mech->content_is('var fixmystreet = fixmystreet || {}; (function(){ if (!fixmystreet.maps) { return; } var defaults; })();' . "\n");

    my $default = { wfs_url => 'http://example.org', geometryName => 'msGeometry', srsName => 'EPSG:3857' };
    my $default2 = { name => 'osgb', srsName => 'EPSG:27700' };
    my $defaults = [ $default, { %$default2, template => 'default' } ];
    my $bridges = { wfs_feature => 'Bridges', asset_item => 'bridge', asset_category => 'Bridges',
        attributes => { asset_details => "helló" },
    };

    foreach ('fixmystreet', 'lincolnshire', 'greenwich') {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => $_,
            COBRAND_FEATURES => { asset_layers => { lincolnshire => [ $defaults, $bridges ] } },
        }, sub {
            $mech->get_ok('/js/asset_layers.js');
            my $content = $mech->content;
            $content =~ /defaults = (\{.*?\}\})/;
            return unless $1;
            my $json = decode_json($1);
            is_deeply $json, { default => $default, osgb => { %$default, %$default2 } };
            $content =~ /fixmystreet\.assets\.add\(defaults\.default, (\{.*?\})\);/;
            $json = decode_json($1);
            is_deeply $json, $bridges;
        };
    }
};

done_testing();
