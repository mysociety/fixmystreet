/**
 * OpenLayers Swiss (CH1903+/LV95) grid projection transformations
 * 
 * Provides transform functions for WGS84<->CH1903+ projections.
 *
 * Maths courtesy of the Swiss Federal Office of Topography:
 * http://www.swisstopo.admin.ch/internet/swisstopo/en/home/products/software/products/skripts.html
 * Simplifed a bit, and with x/y swapped the normal way round.
 */

// Use the same calcs as CH1903 but with offset.
// Maximum distortion is 3M which should be sufficient for our purposes.
var LV95_X_OFFSET = 2000000;
var LV95_Y_OFFSET = 1000000;


OpenLayers.Projection.CH1903Plus = {

    // Convert WGS lat/long (° dec) to CH x
    WGStoCHx: function(lat, lng) {

        // Converts degrees dec to seconds
        lat = lat * 3600;
        lng = lng * 3600;

        // Auxiliary values (% Bern)
        var lat_aux = (lat - 169028.66) / 10000;
        var lng_aux = (lng - 26782.5) / 10000;

        // Process X
        var x = 600072.37 + LV95_X_OFFSET;
        x = x + (211455.93 * lng_aux);
        x = x - (10938.51 * lng_aux * lat_aux);
        x = x - (0.36 * lng_aux * Math.pow(lat_aux, 2));
        x = x - (44.54 * Math.pow(lng_aux, 3));

        return x;
    },

    // Convert WGS lat/long (° dec) to CH y
    WGStoCHy: function(lat, lng) {

        // Converts degrees dec to seconds
        lat = lat * 3600;
        lng = lng * 3600;

        // Auxiliary values (% Bern)
        var lat_aux = (lat - 169028.66)/10000;
        var lng_aux = (lng - 26782.5)/10000;

        // Process Y
        var y = 200147.07 + LV95_Y_OFFSET;
        y = y + (308807.95 * lat_aux);
        y = y + (3745.25 * Math.pow(lng_aux, 2));
        y = y + (76.63 * Math.pow(lat_aux, 2));
        y = y - (194.56 * Math.pow(lng_aux, 2) * lat_aux);
        y = y + (119.79 * Math.pow(lat_aux, 3));

        return y;
      
    },

    // Convert CH x/y to WGS lat
    chToWGSlat: function(x, y) {

        // Converts militar to civil and  to unit = 1000km
        // Axiliary values (% Bern)
        var x_aux = (x - 600000 - LV95_X_OFFSET) / 1000000;
        var y_aux = (y - 200000 - LV95_Y_OFFSET) / 1000000;

        // Process lat
        var lat = 16.9023892;
        lat = lat + (3.238272 * y_aux);
        lat = lat - (0.270978 * Math.pow(x_aux, 2));
        lat = lat - (0.002528 * Math.pow(y_aux, 2));
        lat = lat - (0.0447 * Math.pow(x_aux, 2) * y_aux);
        lat = lat - (0.0140 * Math.pow(y_aux, 3));

        // Unit 10000" to 1 " and converts seconds to degrees (dec)
        lat = lat * 100 / 36;

        return lat;

    },

    // Convert CH x/y to WGS long
    chToWGSlng: function(x, y) {

        // Converts militar to civil and  to unit = 1000km
        // Axiliary values (% Bern)
        var x_aux = (x - 600000 - LV95_X_OFFSET) / 1000000;
        var y_aux = (y - 200000 - LV95_Y_OFFSET) / 1000000;

        // Process long
        var lng = 2.6779094;
        lng = lng + (4.728982 * x_aux);
        lng = lng + (0.791484 * x_aux * y_aux);
        lng = lng + (0.1306 * x_aux * Math.pow(y_aux, 2));
        lng = lng - (0.0436 * Math.pow(x_aux, 3));

        // Unit 10000" to 1 " and converts seconds to degrees (dec)
        lng = lng * 100 / 36;

        return lng;

    },

    // Function to convert a WGS84 coordinate to a Swiss coordinate.
    projectForwardSwiss: function(point) {
        var x = OpenLayers.Projection.CH1903Plus.WGStoCHx(point.y, point.x),
            y = OpenLayers.Projection.CH1903Plus.WGStoCHy(point.y, point.x);
        point.x = x;
        point.y = y;
        return point;
    },

    // Function to convert a Swiss coordinate to a WGS84 coordinate. 
    projectInverseSwiss: function(point) {
        var lon = OpenLayers.Projection.CH1903Plus.chToWGSlng(point.x, point.y);
        var lat = OpenLayers.Projection.CH1903Plus.chToWGSlat(point.x, point.y);
        point.x = lon;
        point.y = lat;
        return point;
    }
};

/**
 * Note: One transform declared
 * Transforms from EPSG:4326 to EPSG:2056
 */
 OpenLayers.Projection.addTransform("EPSG:4326", "EPSG:2056",
    OpenLayers.Projection.CH1903Plus.projectForwardSwiss);
 OpenLayers.Projection.addTransform("EPSG:2056", "EPSG:4326",
    OpenLayers.Projection.CH1903Plus.projectInverseSwiss);
