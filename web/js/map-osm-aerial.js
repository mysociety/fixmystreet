OpenLayers.Layer.AerialOSM = OpenLayers.Class(OpenLayers.Layer.OSM.Mapnik, {
    initialize: function(name, options) {
        var url = fixmystreet.aerial_url + "/${z}/${x}/${y}.png";
        var attribution = '<div class="os-api-branding copyright">&copy; Bluesky International Ltd and Getmapping Ltd 1999-2020<br>&copy; Bluesky International Limited 2021 and onwards</div>';
        this.attribution = attribution;

        if (options.zoomOffset + options.numZoomLevels >= 20) {
            options.numZoomLevels = 19 - options.zoomOffset;
        }
        options = OpenLayers.Util.extend({
            /* Below line added to OSM's file in order to allow minimum zoom level */
            maxResolution: 156543.03390625/Math.pow(2, options.zoomOffset || 0),
            numZoomLevels: 19,
            buffer: 0
        }, options);
        var newArguments = [name, url, options];
        OpenLayers.Layer.OSM.prototype.initialize.apply(this, newArguments);
    },

    CLASS_NAME: "OpenLayers.Layer.AerialOSM"
});

$(function(){
    $('.map-layer-toggle').on('click', fixmystreet.maps.toggle_base);
    // If page loaded with Aerial as starting, rather than default road
    if ($('.map-layer-toggle').text() == translation_strings.map_roads) {
        fixmystreet.map.setBaseLayer(fixmystreet.map.layers[1]);
    }
});

(function() {
    // We haven't yet got the data out of js-map-data (as map.js needs all the layer types defined), so get it from the DOM directly.
    var map_data = document.getElementById('js-map-data');
    var aerial_url = map_data ? map_data.getAttribute('data-aerial_url') : undefined;
    if (aerial_url) {
        fixmystreet.layer_options = [
            {},
            { map_type: OpenLayers.Layer.AerialOSM }
        ];
    }
})();
