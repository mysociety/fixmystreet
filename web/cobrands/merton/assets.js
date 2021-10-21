(function(){

if (!fixmystreet.maps) {
    return;
}

var format = new OpenLayers.Format.QueryStringFilter();
OpenLayers.Protocol.Merton = OpenLayers.Class(OpenLayers.Protocol.HTTP, {
    filterToParams: function(filter, params) {
        params = format.write(filter, params);
        params.geometry = params.bbox;
        delete params.bbox;
        return params;
    },
    CLASS_NAME: "OpenLayers.Protocol.Merton"
});

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
    nearest_radius: 2,
    stylemap: fixmystreet.assets.stylemap_invisible,
    non_interactive: true,
    always_visible: true,
    usrn: {
        attribute: 'Usrn',
        field: 'site_code'
    },
    name: "usrn"
});

// This is required so that the found/not found actions are fired on category
// select and pin move rather than just on asset select/not select.
OpenLayers.Layer.MertonVectorAsset = OpenLayers.Class(OpenLayers.Layer.VectorAsset, {
    initialize: function(name, options) {
        OpenLayers.Layer.VectorAsset.prototype.initialize.apply(this, arguments);
        $(fixmystreet).on('maps:update_pin', this.checkSelected.bind(this));
        $(fixmystreet).on('report_new:category_change', this.checkSelected.bind(this));
    },

    CLASS_NAME: 'OpenLayers.Layer.MertonVectorAsset'
});

var url_base = 'https://tilma.mysociety.org/resource-proxy/proxy.php?https://merton.assets/';

})();
