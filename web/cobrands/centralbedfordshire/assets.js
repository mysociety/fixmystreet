(function(){

if (!fixmystreet.maps) {
    return;
}

var domain = fixmystreet.staging ? "https://tilma.staging.mysociety.org" : "https://tilma.mysociety.org";
var defaults = {
    http_options: {
        url: domain + "/mapserver/centralbeds",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    asset_type: 'spot',
    max_resolution: 9.554628534317017,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "Central Bedfordshire Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};
var proxy_defaults = $.extend(true, {}, defaults, {
    http_options: {
        url: domain + "/proxy/cbc/wfs",
        params: {
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    srsName: "EPSG:27700"
});

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
    no_asset_msgs_class: '.js-roads-centralbeds',
    name: "Highways"
});

var streetlight_stylemap = new OpenLayers.StyleMap({
    'default': fixmystreet.assets.style_default,
    'hover': fixmystreet.assets.style_default_hover,
    'select': fixmystreet.assets.construct_named_select_style("${lighting_c}")
});

var labeled_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    stylemap: streetlight_stylemap,
    feature_code: 'lighting_c',
    asset_id_field: 'asset',
    attributes: {
        UnitID: 'asset'
    },
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "StreetLighting"
        }
    },
    max_resolution: 2.388657133579254,
    asset_category: ["Street Lights"],
    asset_item: 'street light'
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Gullies"
        }
    },
    max_resolution: 1.194328566789627,
    asset_category: ["Surface cover", "Drains/Ditches Blocked"],
    asset_item: 'drain or manhole'
});

fixmystreet.assets.add(proxy_defaults, {
    http_options: {
        params: {
            propertyName: 'id,msGeometry',
            TYPENAME: "trees"
        }
    },
    asset_id_field: 'id',
    attributes: {
        UnitID: 'id'
    },
    max_resolution: 1.194328566789627,
    asset_category: ["Trees"],
    asset_item: 'tree'
});


})();
