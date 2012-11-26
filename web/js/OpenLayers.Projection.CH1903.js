/**
 * OpenLayers Swiss (CH1903) grid projection transformations
 * 
 * Provides transform functions for WGS84<->CH1903 projections.
 *
 * Maths courtesy of the Swiss Federal Office of Topography:
 * http://www.swisstopo.admin.ch/internet/swisstopo/en/home/products/software/products/skripts.html
 */


OpenLayers.Projection.CH1903 = {

    // Convert SEX DMS angle to DEC
    SEXtoDEC: function(angle) {

        // Extract DMS
        var deg = parseInt(angle, 10);
        var min = parseInt((angle - deg) * 100, 10);
        var sec = (((angle - deg) * 100) - min) * 100;

        // Result in degrees sex (dd.mmss)
        return deg + ((sec / 60 + min) / 60);

    },

    // Convert DEC angle to SEX DMS
    DECtoSEX: function(angle) {

        // Extract DMS
        var deg = parseInt(angle, 10);
        var min = parseInt((angle - deg) * 60, 10);
        var sec =  (((angle - deg) * 60) - min) * 60;   

        // Result in degrees sex (dd.mmss)
        return deg + (min / 100) + (sec / 10000);

    },

    // Convert Degrees angle to seconds
    DEGtoSEC: function(angle) {

        // Extract DMS
        var deg = parseInt( angle );
        var min = parseInt( (angle - deg) * 100 );
        var sec = (((angle - deg) * 100) - min) * 100;

        // Result in degrees sex (dd.mmss)
        return sec + (min * 60) + (deg * 3600);

    },

    // Convert WGS lat/long (° dec) to CH y
    WGStoCHy: function(lat, lng) {

        // Converts degrees dec to sex
        lat = OpenLayers.Projection.CH1903.DECtoSEX(lat);
        lng = OpenLayers.Projection.CH1903.DECtoSEX(lng);

        // Converts degrees to seconds (sex)
        lat = OpenLayers.Projection.CH1903.DEGtoSEC(lat);
        lng = OpenLayers.Projection.CH1903.DEGtoSEC(lng);

        // Axiliary values (% Bern)
        var lat_aux = (lat - 169028.66) / 10000;
        var lng_aux = (lng - 26782.5) / 10000;

        // Process Y
        y = 600072.37;
        y = y + (211455.93 * lng_aux);
        y = y - (10938.51 * lng_aux * lat_aux);
        y = y - (0.36 * lng_aux * Math.pow(lat_aux, 2));
        y = y - (44.54 * Math.pow(lng_aux, 3));

        return y;
    },

    // Convert WGS lat/long (° dec) to CH x
    WGStoCHx: function(lat, lng) {

        // Converts degrees dec to sex
        lat = OpenLayers.Projection.CH1903.DECtoSEX(lat);
        lng = OpenLayers.Projection.CH1903.DECtoSEX(lng);

        // Converts degrees to seconds (sex)
        lat = OpenLayers.Projection.CH1903.DEGtoSEC(lat);
        lng = OpenLayers.Projection.CH1903.DEGtoSEC(lng);

        // Axiliary values (% Bern)
        var lat_aux = (lat - 169028.66)/10000;
        var lng_aux = (lng - 26782.5)/10000;

        // Process X
        x = 200147.07;
        x = x + (308807.95 * lat_aux);
        x = x + (3745.25 * Math.pow(lng_aux, 2));
        x = x + (76.63 * Math.pow(lat_aux, 2));
        x = x - (194.56 * Math.pow(lng_aux, 2) * lat_aux);
        x = x + (119.79 * Math.pow(lat_aux, 3));

        return x;
      
    },

    // Convert CH y/x to WGS lat
    chToWGSlat: function(y, x) {

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

    },

    // Convert CH y/x to WGS long
    chToWGSlng: function(y, x) {

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

    },

    // Function to convert a WGS84 coordinate to a Swiss coordinate.
    projectForwardSwiss: function(point) {
        var x = OpenLayers.Projection.CH1903.WGStoCHx(point.y, point.x),
            y = OpenLayers.Projection.CH1903.WGStoCHy(point.y, point.x);
        point.x = y; // x/y are geometrically swapped by the conversion functions
        point.y = x;
        return point;
    },

    // Function to convert a Swiss coordinate to a WGS84 coordinate. 
    projectInverseSwiss: function(point) {
        var lon = OpenLayers.Projection.CH1903.chToWGSlng(point.x, point.y);
        var lat = OpenLayers.Projection.CH1903.chToWGSlat(point.x, point.y);
        point.x = lon;
        point.y = lat;
        return point;
    }
};

/**
 * Note: One transform declared
 * Transforms from EPSG:4326 to EPSG:21781
 */
 OpenLayers.Projection.addTransform("EPSG:4326", "EPSG:21781",
    OpenLayers.Projection.CH1903.projectForwardSwiss);
 OpenLayers.Projection.addTransform("EPSG:21781", "EPSG:4326",
    OpenLayers.Projection.CH1903.projectInverseSwiss);
