(function(){

if (!fixmystreet.maps) {
    return;
}


var defaults = {
    http_options: {
        url: fixmystreet.staging ? "https://tilma.staging.mysociety.org/mapserver/centralbeds" : "https://tilma.mysociety.org/mapserver/centralbeds",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    max_resolution: 9.554628534317017,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "Central Bedfordshire Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var centralbeds_types = [
    "CBC",
    "Fw",
];

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Highways"
        }
    },
    stylemap: fixmystreet.assets.stylemap_invisible,
    non_interactive: true,
    always_visible: true,
    road: true,
    all_categories: true,
    usrn: {
        attribute: 'streetref1',
        field: 'NSGRef'
    },
    actions: {
        found: function(layer, feature) {
            fixmystreet.message_controller.road_found(layer, feature, function(feature) {
                if (OpenLayers.Util.indexOf(centralbeds_types, feature.attributes.adoption) != -1) {
                    return true;
                }
                return false;
            }, "#js-not-council-road");
        },
        not_found: fixmystreet.message_controller.road_not_found,
    },
    asset_item: "road",
    asset_type: 'road',
    no_asset_msg_id: '#js-not-a-road',
    name: "Highways"
});

})();
