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
        displayProjection: new OpenLayers.Projection("EPSG:21781"),
        maxExtent: new OpenLayers.Bounds(676000,241000,690000,255000),
        //projection: new OpenLayers.Projection("EPSG:4326"),
        //displayProjection: new OpenLayers.Projection("EPSG:4326"),
        //maxExtent: new OpenLayers.Bounds(8.444933818976226,47.31509040172551,8.632922236617937,47.442777990747416),
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
            //layer.url = layer.url.replace('arcgis/rest/services/', '');
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

// These next two functions come from the Swiss Federal Office of Topography
// http://www.swisstopo.admin.ch/internet/swisstopo/en/home/products/software/products/skripts.html

// Convert CH y/x to WGS lat
function chToWGSlat(y, x) {

    // Converts militar to civil and  to unit = 1000km
    // Axiliary values (% Bern)
    var y_aux = (y - 600000) / 1000000;
    var x_aux = (x - 200000) / 1000000;

    // Process lat
    var lat = 16.9023892;
    lat = lat + (3.238272 * x_aux);
    lat = lat - (0.270978 * Math.pow(y_aux, 2));
    lat = lat - (0.002528 * Math.pow(x_aux, 2));
    lat = lat - (0.0447 * Math.pow(y_aux, 2) * x_aux);
    lat = lat - (0.0140 * Math.pow(x_aux, 3));

    // Unit 10000" to 1 " and converts seconds to degrees (dec)
    lat = lat * 100 / 36;

    return lat;
  
}

// Convert CH y/x to WGS long
function chToWGSlng(y, x) {

    // Converts militar to civil and  to unit = 1000km
    // Axiliary values (% Bern)
    var y_aux = (y - 600000) / 1000000;
    var x_aux = (x - 200000) / 1000000;

    // Process long
    var lng = 2.6779094;
    lng = lng + (4.728982 * y_aux);
    lng = lng + (0.791484 * y_aux * x_aux);
    lng = lng + (0.1306 * y_aux * Math.pow(x_aux, 2));
    lng = lng - (0.0436 * Math.pow(y_aux, 3));

    // Unit 10000" to 1 " and converts seconds to degrees (dec)
    lng = lng * 100 / 36;

    return lng;
  
}

// Function to convert a Swiss coordinate to a WGS84 coordinate. 
function getOLLatLonFromSwiss(y, x) {
    return new OpenLayers.LonLat(chToWGSlng(y, x), chToWGSlat(y, x));
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
        var topLeft = getOLLatLonFromSwiss(swissBounds.left,swissBounds.top);
        var bottomRight = getOLLatLonFromSwiss(swissBounds.right,swissBounds.bottom);
        var bounds = new OpenLayers.Bounds();
        bounds.extend(topLeft);
        bounds.extend(bottomRight);
        return bounds;
    },

    CLASS_NAME: "OpenLayers.Strategy.ZurichBBOX"
});
