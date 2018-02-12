(function(){

if (!fixmystreet.maps) {
    return;
}

fixmystreet.assets.add({
    http_options: {
        url: "https://davea.tilma.dev.mysociety.org/mapserver/bucks",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857",
            TYPENAME: "Grit_Bins"
        }
    },
    asset_category: "Grit bins",
    asset_item: 'grit bin',
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'central_as',
    attributes: {
        asset_details: 'central_as'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.FixMyStreet
});

fixmystreet.assets.add({
    http_options: {
        url: "https://davea.tilma.dev.mysociety.org/mapserver/bucks",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857",
            TYPENAME: "SL_Merged"
        }
    },
    asset_category: "Street lighting",
    asset_item: 'street light',
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'central_as',
    attributes: {
        asset_details: 'central_as'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.FixMyStreet
});


})();
