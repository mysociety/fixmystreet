(function(){

if (!fixmystreet.maps) {
    return;
}

fixmystreet.assets.add({
    http_options: {
        url: "https://davea.tilma.dev.mysociety.org/mapserv.fcgi?map=fixmystreet.map",
        // url: "https://confirmdev.eu.ngrok.io/tilma/mapserv.fcgi?map=fixmystreet.map",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857",
            TYPENAME: "bucksgritbins"
        }
    },
    asset_category: "Grit bins",
    asset_item: 'grit bin',
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'central_as',
    attributes: {
        column_id: 'n'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:3857"
});

fixmystreet.assets.add({
    http_options: {
        url: "https://davea.tilma.dev.mysociety.org/mapserv.fcgi?map=fixmystreet.map",
        // url: "https://confirmdev.eu.ngrok.io/tilma/mapserv.fcgi?map=fixmystreet.map",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857",
            TYPENAME: "bucksstreetlamps"
        }
    },
    asset_category: "Street lighting",
    asset_item: 'street light',
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'central_as',
    attributes: {
        column_id: 'n'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:3857"
});


})();
