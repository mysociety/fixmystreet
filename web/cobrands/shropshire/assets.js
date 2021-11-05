(function(){

if (!fixmystreet.maps) {
    return;
}

var wfs_host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';
var tilma_url = "https://" + wfs_host + "/mapserver/shropshire";

var defaults = {
    http_options: {
        url: tilma_url,
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    asset_type: 'spot',
    asset_id_field: 'CentralAssetId',
    attributes: {
        central_asset_id: 'CentralAssetId',
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    body: "Shropshire Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var highways_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#5555FF",
    strokeOpacity: 0.1,
    strokeWidth: 7
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Street_Gazetteer"
        }
    },
    stylemap: new OpenLayers.StyleMap({
         'default': highways_style
     }),
    usrn: {
        attribute: 'USRN',
        field: 'site_code'
    },
    road: true,
    asset_item: 'road',
    asset_type: 'road',
    no_asset_msg_id: '#js-not-a-road',
    no_asset_msgs_class: '.js-roads-shropshire',
    always_visible: true,
    non_interactive: true,
    all_categories: true,
    actions: {
        found: function(layer, asset) {
            fixmystreet.message_controller.road_found(layer, asset.attributes.SITE_CLASS, function(name) {
                if (name == 'PUB' || name === 'PUPI') { return 1; }
                else { return 0; }
            }, "#js-not-council-road");
        },
        not_found: function(layer) {
              fixmystreet.message_controller.road_not_found(layer);
        }
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Lights_Union"
        }
    },
    asset_group: "Streetlights",
    asset_item: 'streetlight',
    asset_id_field: 'ASSET_ID',
    attributes: {
        central_asset_id: 'ASSET_ID',
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Traffic_Signal_Areas"
        }
    },
    asset_id_field: 'ASSET_ID',
    attributes: {
        central_asset_id: 'ASSET_ID',
    },
    asset_group: 'Traffic Signals & Crossings',
    asset_item: 'traffic signal'
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Illuminated_Bollards"
        }
    },
    asset_group: 'Illuminated signs',
    asset_item: 'bollard',
    asset_id_field: 'ASSET_ID',
    attributes: {
        central_asset_id: 'ASSET_ID',
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Grit_Bins"
        }
    },
    asset_category: ["Salt bins replenish"],
    asset_item: 'salt bin'
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Cattle_Grids"
        }
    },
    asset_category: ["Cattle Grid"],
    asset_item: 'cattle grid'
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Bridges"
        }
    },
    asset_category: ["Bridge"],
    asset_item: 'bridge'
});

})();
