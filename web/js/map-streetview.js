YAHOO.util.Event.onContentReady('map', function() {
    var map = new OpenLayers.Map("map", {
        controls: [
            new OpenLayers.Control.ArgParser(),
            //new OpenLayers.Control.LayerSwitcher(),
            new OpenLayers.Control.Navigation(),
            new OpenLayers.Control.PanZoom()
        ],
        displayProjection: new OpenLayers.Projection("EPSG:4326")
    });
    var streetview = new OpenLayers.Layer.StreetView("OS StreetView (1:10000)", {
        zoomOffset: 14,
        numZoomLevels: 4
    });
    map.addLayer(streetview);

    var centre = new OpenLayers.LonLat( fixmystreet.easting, fixmystreet.northing );
    centre.transform(
        new OpenLayers.Projection("EPSG:27700"),
        map.getProjectionObject()
    );
    map.setCenter(centre, 2);
});


// http://os.openstreetmap.org/openlayers/OS.js (added one line)

/**
 * Namespace: Util.OS
 */
OpenLayers.Util.OS = {};

/**
 * Constant: MISSING_TILE_URL
 * {String} URL of image to display for missing tiles
 */
OpenLayers.Util.OS.MISSING_TILE_URL = "http://openstreetmap.org/openlayers/img/404.png";

/**
 * Property: originalOnImageLoadError
 * {Function} Original onImageLoadError function.
 */
OpenLayers.Util.OS.originalOnImageLoadError = OpenLayers.Util.onImageLoadError;

/**
 * Function: onImageLoadError
 */
OpenLayers.Util.onImageLoadError = function() {
    OpenLayers.Util.OS.originalOnImageLoadError;
};

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
            maxResolution: 156543.0339/Math.pow(2, options.zoomOffset || 0),
            numZoomLevels: 18,
            transitionEffect: "resize",
            sphericalMercator: true,
            attribution: "Contains Ordnance Survey data © Crown copyright and database right 2010"
        }, options);
        var newArguments = [name, url, options];
        OpenLayers.Layer.XYZ.prototype.initialize.apply(this, newArguments);
    },

    CLASS_NAME: "OpenLayers.Layer.StreetView"
});
