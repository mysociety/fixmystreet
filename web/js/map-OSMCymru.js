fixmystreet.maps.config = function() {
    fixmystreet.maps.controls.unshift( new OpenLayers.Control.AttributionFMS() );
    if (OpenLayers.Layer.BingAerial) {
        fixmystreet.layer_options = [
          { map_type: fixmystreet.map_type },
          { map_type: OpenLayers.Layer.BingAerial }
        ];
    }
};

OpenLayers.Layer.OSM.Cymru = OpenLayers.Class(OpenLayers.Layer.OSM, {
    /**
     * Constructor: OpenLayers.Layer.OSM.Cymru
     *
     * Parameters:
     * name - {String}
     * options - {Object} Hashtable of extra options to tag onto the layer
     */
    initialize: function(name, options) {
        var url = "//tilma.mysociety.org/proxy/osm-cymru/${z}/${x}/${y}.png";
        options = OpenLayers.Util.extend({
            /* Below line added to OSM's file in order to allow minimum zoom level */
            maxResolution: 156543.03390625/Math.pow(2, options.zoomOffset || 0),
            numZoomLevels: 19,
            buffer: 0
        }, options);
        var newArguments = [name, url, options];
        OpenLayers.Layer.OSM.prototype.initialize.apply(this, newArguments);
    },

    CLASS_NAME: "OpenLayers.Layer.OSM.Cymru"
});
