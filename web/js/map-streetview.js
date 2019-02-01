fixmystreet.maps.config = function() {
    fixmystreet.controls = [
        new OpenLayers.Control.ArgParserFMS(),
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.Permalink(),
        new OpenLayers.Control.PanZoomFMS()
    ];
    fixmystreet.map_type = OpenLayers.Layer.StreetView;
};

// http://os.openstreetmap.org/openlayers/OS.js (added one line)

/**
 * @requires OpenLayers/Layer/XYZ.js
 *
 * Class: OpenLayers.Layer.StreetView
 *
 * Inherits from:
 *  - <OpenLayers.Layer.XYZ>
 */
OpenLayers.Layer.StreetView = OpenLayers.Class(OpenLayers.Layer.XYZ, {
    /**
     * Constructor: OpenLayers.Layer.StreetView
     *
     * Parameters:
     * name - {String}
     * url - {String}
     * options - {Object} Hashtable of extra options to tag onto the layer
     */
    initialize: function(name, options) {
        var url = [
            "http://a.os.openstreetmap.org/sv/${z}/${x}/${y}.png",
            "http://b.os.openstreetmap.org/sv/${z}/${x}/${y}.png",
            "http://c.os.openstreetmap.org/sv/${z}/${x}/${y}.png"
        ];
        options = OpenLayers.Util.extend({
            /* Below line added to OSM's file in order to allow minimum zoom level */
            maxResolution: 156543.03390625/Math.pow(2, options.zoomOffset || 0),
            numZoomLevels: 19,
            sphericalMercator: true
        }, options);
        var newArguments = [name, url, options];
        OpenLayers.Layer.XYZ.prototype.initialize.apply(this, newArguments);
    },

    CLASS_NAME: "OpenLayers.Layer.StreetView"
});
