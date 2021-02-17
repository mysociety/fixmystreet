fixmystreet.maps.config = function() {
    fixmystreet.controls = [
        new OpenLayers.Control.ArgParserFMS(),
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.PermalinkFMS('map'),
        new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' })
    ];

    if (OpenLayers.Layer.BingAerial) {
        fixmystreet.layer_options = [
          { map_type: OpenLayers.Layer.OSMaps },
          { map_type: OpenLayers.Layer.BingAerial }
        ];
    }
};

OpenLayers.Layer.OSMaps = OpenLayers.Class(OpenLayers.Layer.OSM, {
    initialize: function(name, options) {
        var url = fixmystreet.os_url.replace('%s', fixmystreet.os_layer) + "/${z}/${x}/${y}.png";
        if (fixmystreet.os_key) {
            url += "?key=" + fixmystreet.os_key;
        }
        options = OpenLayers.Util.extend({
            /* Below line added to OSM's file in order to allow minimum zoom level */
            maxResolution: 156543.03390625/Math.pow(2, options.zoomOffset || 0),
            numZoomLevels: 20,
            buffer: 0
        }, options);
        var newArguments = [name, url, options];
        OpenLayers.Layer.OSM.prototype.initialize.apply(this, newArguments);
    },

    CLASS_NAME: "OpenLayers.Layer.OSMaps"
});
