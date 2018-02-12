(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://davea.tilma.dev.mysociety.org/mapserver/bucks",
        // url: "https://confirmdev.eu.ngrok.io/tilma/mapserver/bucks",
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
    asset_id_field: 'central_as',
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'Site_code'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Grit_Bins"
        }
    },
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'site_code' // different capitalisation, sigh
    },
    asset_category: "Grit bins",
    asset_item: 'grit bin'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "StreetLights_Merged"
        }
    },
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'Site_code'
    },
    asset_category: "Street lighting",
    asset_item: 'street light'
}));

})();
