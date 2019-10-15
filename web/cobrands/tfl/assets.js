(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.staging.mysociety.org/mapserver/tfl",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    format_class: OpenLayers.Format.GML.v3.MultiCurveFix,
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'Site',
    attributes: {
        site: 'Site',
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    body: "TfL"
};

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "trafficsignals"
        }
    },
    asset_category: [
        "Traffic Lights",
        "Traffic lights"
    ],
    asset_item: 'traffic signal'
}));

})();
