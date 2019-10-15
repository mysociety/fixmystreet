(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.mysociety.org/mapserver/tfl",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    body: "TfL"
};

var asset_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    no_asset_msg_id: '#js-not-an-asset',
    actions: {
        asset_found: fixmystreet.message_controller.asset_found,
        asset_not_found: fixmystreet.message_controller.asset_not_found
    }
});

fixmystreet.assets.add(asset_defaults, {
    http_options: {
        params: {
            TYPENAME: "trafficsignals"
        }
    },
    asset_id_field: 'Site',
    attributes: {
        site: 'Site',
    },
    asset_group: "Traffic Lights",
    asset_item: 'traffic signal'
});

fixmystreet.assets.add(asset_defaults, {
    http_options: {
        params: {
            TYPENAME: "busstops"
        }
    },
    asset_id_field: 'STOP_CODE',
    attributes: {
        stop_code: 'STOP_CODE',
    },
    asset_group: "Bus Stops and Shelters",
    asset_item: 'bus stop'
});

})();
