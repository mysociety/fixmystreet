(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    max_resolution: 4.777314267158508,
    srsName: "EPSG:27700",
    body: "Merton Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var tilma_defaults = $.extend(true, {}, defaults, {
    http_options: {
        url: fixmystreet.staging ? "https://tilma.staging.mysociety.org/mapserver/openusrn" : "https://tilma.mysociety.org/mapserver/openusrn",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    geometryName: 'msGeometry'
});

fixmystreet.assets.add(tilma_defaults, {
    http_options: {
        params: {
            TYPENAME: "usrn"
        }
    },
    nearest_radius: 50,
    stylemap: fixmystreet.assets.stylemap_invisible,
    non_interactive: true,
    always_visible: true,
    usrn: {
        attribute: 'usrn',
        field: 'usrn'
    },
    name: "usrn"
});

})();
