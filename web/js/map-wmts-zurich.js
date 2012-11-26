/* 
 * Maps for FMZ using Zurich council's WMTS tile server 
 */

 /* 
 * Copied from Mark/Matthew's demo of using Zurich's layers
 * and merged with things that js/map-OpenLayers.js does
 */
function init_zurich_map(after) {

    fixmystreet.map = new OpenLayers.Map('map', {
        projection: new OpenLayers.Projection("EPSG:21781"),
        displayProjection: new OpenLayers.Projection("EPSG:4326"),
        maxExtent: new OpenLayers.Bounds(676000,241000,690000,255000),
        units: 'm',
        scales: [ '250000', '125000', '64000', '32000', '16000', '8000', '4000', '2000', '1000', '500'],
        controls: fixmystreet.controls
    });

    var format = new OpenLayers.Format.WMTSCapabilities();

    jQuery.support.cors = true;

    jQuery.get("cobrands/zurich/Zurich-WMTSCapabilities.xml",
        '',
        function (data, textStatus, jqXHR) {

            var layer, centre;
            var capabilities = format.read(data);

            layer = format.createLayer(capabilities, {
                // Mark/Matthew's
                layer: "Luftbild",
                matrixSet: "default028mm",
                //matrixSet: "nativeTileMatrixSet",
                requestEncoding: "REST",
                isBaseLayer: true,
                // Things from the original map-OpenLayers.js
                zoomOffset: fixmystreet.zoomOffset,
                transitionEffect: 'resize',
                numZoomLevels: fixmystreet.numZoomLevels

            });
            // For some reason with OpenLayers 2.11 the format
            // returns a KVP url not a REST one, despite the settings
            // we have above, so for now I'm hardcoding the right one
            layer.url = "http://www.wmts.stadt-zuerich.ch/Luftbild/MapServer/WMTS/tile/";

            fixmystreet.map.addLayer(layer);

            centre = new OpenLayers.LonLat( fixmystreet.longitude, fixmystreet.latitude );
            centre.transform(
                new OpenLayers.Projection("EPSG:4326"),
                fixmystreet.map.getProjectionObject()
            );
            fixmystreet.map.setCenter(centre, fixmystreet.zoom || 3);

            // Call the after callback
            after();
      },
      'xml');
}

/* 
 * set_map_config() is called on dom ready in map-OpenLayers.js
 * to setup the way the map should operate.
 */
 function set_map_config(perm) {
    // This stuff is copied from js/map-bing-ol.js
    var permalink_id;
    if ($('#map_permalink').length) {
        permalink_id = 'map_permalink';
    }

    var nav_opts = { zoomWheelEnabled: false };
    if (fixmystreet.page == 'around' && $('html').hasClass('mobile')) {
        nav_opts = {};
    }
    fixmystreet.nav_control = new OpenLayers.Control.Navigation(nav_opts);

    fixmystreet.controls = [
        new OpenLayers.Control.Attribution(),
        new OpenLayers.Control.ArgParser(),
        fixmystreet.nav_control,
        new OpenLayers.Control.Permalink(permalink_id),
        new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' })
    ];

    fixmystreet.map_type = OpenLayers.Layer.WMTS;

    // Set DPI - default is 72
    OpenLayers.DOTS_PER_INCH = 96;

    // tell the main code to run our function instead
    // of setting the map up itself
    fixmystreet.map_setup = init_zurich_map;

    // Give main code a new bbox_strategy that translates between
    // lat/lon and our swiss coordinates
    fixmystreet.bbox_strategy = new OpenLayers.Strategy.ZurichBBOX({ratio: 1});
}

OpenLayers.Strategy.ZurichBBOX = OpenLayers.Class(OpenLayers.Strategy.BBOX, {
    getMapBounds: function() {
        // Get the map bounds but return them in lat/lon, not
        // Swiss coordinates
        if (this.layer.map === null) {
            return null;
        }

        var swissBounds = this.layer.map.getExtent();
        // Transform bound corners into WGS84
        swissBounds.transform( new OpenLayers.Projection("EPSG:21781"), new OpenLayers.Projection("EPSG:4326") );
        return swissBounds;
    },

    CLASS_NAME: "OpenLayers.Strategy.ZurichBBOX"
});
