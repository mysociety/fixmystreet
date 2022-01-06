(function(){

if (!fixmystreet.maps) {
    return;
}

var wfs_host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';
var tilma_url = "https://" + wfs_host + "/mapserver/hampshire";

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
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    body: "Hampshire County Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Road_Sections"
        }
    },
    usrn: {
        attribute: 'SITE_CODE',
        field: 'site_code'
    },
    road: true,
    asset_item: 'road',
    asset_type: 'road',
    no_asset_msg_id: '#js-not-a-road',
    non_interactive: true,
    asset_group: "Roads/Highways",
    stylemap: fixmystreet.assets.stylemap_invisible,
    actions: {
        found: function(layer, asset) {
            fixmystreet.message_controller.road_found(layer);
        },
        not_found: function(layer) {
              fixmystreet.message_controller.road_not_found(layer);
        }
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "salt_bins"
        }
    },
    asset_id_field: 'Asset_ID',
    asset_type: 'spot',
    asset_category: ["Salt Bin"],
    asset_item: 'salt bin'
});

})();
