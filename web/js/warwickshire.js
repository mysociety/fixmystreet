/*
 * southampton.js
 * FixMyStreet JavaScript for Warwickshire, cadged from Southampton code, TODO refactor
 */

function update_category_extra(msg) {
    var content = '<div style="margin: 1em 0em 1em 6.5em"><strong>' + msg + '</strong></div>';
    var el = $('#category_extra');
    if ( el.length ) {
        el.html( content );
    } else {
        var cat_extra = '<div id="category_extra" style="margin:0; display_none;">' +
            content +
            '</div>';
        $('#form_title').closest('div.form-field').after(cat_extra);
    }
    $('#category_extra').show('fast');
}

function add_streetlight_layer() {
    var layer = new OpenLayers.Layer.WMS("Street Lights",
            "//maps.warwickshire.gov.uk/gs/ows", {
                layers: "Public_Data_DB:STREET_LIGHTS_WSHIRE",
                transparent: !0,
                format: "image/png",
                srs: "CRS:84",
                crs: "CRS:84",
                version: "1.3.0"
            },
            {
                singleTile: !0,
                featureInfoFormat: "application/vnd.ogc.gml",
                metadata: {
                    wfs: {
                        protocol: "fromWMSLayer",
                        featurePrefix: "Public_Data_DB",
                        featureNS: "http://www.warwickshire.gov.uk/public_data_db"
                    }
                },
            });
    fixmystreet.map.addLayer(layer);
    console.log("added layer");
    fixmystreet.streetLightLayer = layer;
}

function set_map_config() {
    fixmystreet.map_type = OpenLayers.Layer.WMTS;

    fixmystreet.zoomOffset = 0;

    fixmystreet.map_options = {
        units: 'm',
        projection: new OpenLayers.Projection("EPSG:27700"),
        yx: {
            "EPSG:27700": !1
        },
        maxExtent: [0, 0, 700000, 1300000],
        // resolutions: [2800, 1400, 700, 350, 175, 84, 42, 21, 11.2, 5.6, 2.8, 1.4, 0.7, 0.35, 0.14, 0.07],
        scales: [1.0E7, 5000000.0, 2500000.0, 1250000.0, 625000.0, 300000.0, 150000.0, 75000.0, 40000.0, 20000.0, 10000.0, 5000.0, 2500.0, 1250.0, 500.0000000000001, 250.00000000000006],
        // center: "430000, 270000",
        // xy_precision: 2,
        // zoom: 4
    };

    fixmystreet.layer_options = [
        {
            projection: new OpenLayers.Projection("EPSG:27700"),
            name: "z_OS_Vector_Basemap",
            layer: "z_OS_Vector_Basemap",
            matrixSet: "UK_OSGB",
            url: "http://maps.warwickshire.gov.uk/gs/gwc/service/wmts",
            style: "",
            format: "image/png8",
            matrixIds: [
                { identifier: "UK_OSGB:0", scaleDenominator: 1.0E7, topLeftCorner: { lon: 0.0, lat: 1433600.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 1, matrixHeight: 2, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:1", scaleDenominator: 5000000.0, topLeftCorner: { lon: 0.0, lat: 1433600.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 2, matrixHeight: 4, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:2", scaleDenominator: 2500000.0, topLeftCorner: { lon: 0.0, lat: 1433600.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 4, matrixHeight: 8, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:3", scaleDenominator: 1250000.0, topLeftCorner: { lon: 0.0, lat: 1344000.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 8, matrixHeight: 15, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:4", scaleDenominator: 625000.0, topLeftCorner: { lon: 0.0, lat: 1344000.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 16, matrixHeight: 30, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:5", scaleDenominator: 300000.0, topLeftCorner: { lon: 0.0, lat: 1311744.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 33, matrixHeight: 61, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:6", scaleDenominator: 150000.0, topLeftCorner: { lon: 0.0, lat: 1300992.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 66, matrixHeight: 121, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:7", scaleDenominator: 75000.0, topLeftCorner: { lon: 0.0, lat: 1300992.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 131, matrixHeight: 242, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:8", scaleDenominator: 40000.0, topLeftCorner: { lon: 0.0, lat: 1301709.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 245, matrixHeight: 454, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:9", scaleDenominator: 20000.0, topLeftCorner: { lon: 0.0, lat: 1300275.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 489, matrixHeight: 907, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:10", scaleDenominator: 10000.0, topLeftCorner: { lon: 0.0, lat: 1300275.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 977, matrixHeight: 1814, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:11", scaleDenominator: 5000.0, topLeftCorner: { lon: 0.0, lat: 1300275.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 1954, matrixHeight: 3628, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:12", scaleDenominator: 2500.0, topLeftCorner: { lon: 0.0, lat: 1300096.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 3907, matrixHeight: 7255, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:13", scaleDenominator: 1250.0, topLeftCorner: { lon: 0.0, lat: 1300006.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 7813, matrixHeight: 14509, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:14", scaleDenominator: 500.0000000000001, topLeftCorner: { lon: 0.0, lat: 1300024.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 19532, matrixHeight: 36273, supportedCRS: "urn:ogc:def:crs:EPSG::27700"},
                { identifier: "UK_OSGB:15", scaleDenominator: 250.00000000000006, topLeftCorner: { lon: 0.0, lat: 1300006.0 }, tileWidth: 256, tileHeight: 256, matrixWidth: 39063, matrixHeight: 72545, supportedCRS: "urn:ogc:def:crs:EPSG::27700"}
            ]
        }
    ];
    // Give main code a new bbox_strategy that translates between
    // lat/lon and our BNG coordinates
    fixmystreet.bbox_strategy = new OpenLayers.Strategy.BNGBBOX({ratio: 1});
}

OpenLayers.Strategy.BNGBBOX = OpenLayers.Class(OpenLayers.Strategy.BBOX, {
    getMapBounds: function() {
        console.log("getMapBounds");

        // Get the map bounds but return them in lat/lon, not
        // BNG coordinates
        if (this.layer.map === null) {
            return null;
        }

        var bngBounds = this.layer.map.getExtent();
        console.log(bngBounds);
        // Transform bound corners into WGS84
        bngBounds.transform( new OpenLayers.Projection("EPSG:27700"), new OpenLayers.Projection("EPSG:4326") );
        console.log(bngBounds);
        return bngBounds;
    },

    CLASS_NAME: "OpenLayers.Strategy.BNGBBOX"
});


$(function(){

    $('[placeholder]').focus(function(){
        var input = $(this);
        if (input.val() == input.attr('placeholder')) {
            input.val('');
            input.removeClass('placeholder');
            input.css({ 'color': '#000000' });
        }
    }).blur(function(){
        var input = $(this);
        if (input.val() === '' || input.val() == input.attr('placeholder')) {
            input.css({ 'color': '#999999' });
            input.val(input.attr('placeholder'));
        }
    }).blur();

    // use on() here because the #form_category may be replaced 
    // during the page's lifetime
    $("#problem_form").on("change.warwickshire", "select#form_category", 
      function() {
        $('#form_sign_in').show('fast');
        $('#problem_submit').show('fast');
        $('#street_light_report').hide('fast');
        $('#depth_extra').hide('fast');
        $('#category_extra').hide('fast');
        var category = $(this).val();
        if ('Street lighting' == category) {
            $('#category_extra').hide('fast');
            var lighting_content =
                '<div id="street_light_report" style="margin: 1em 0em 1em 6.5em"> TODO: extra guidance text here!</div>';
            if ( $('#form_category_row').count ) {
                $('#form_category_row').after(lighting_content);
            } else {
                $('#form_category:parent').after(lighting_content);
            }
            add_streetlight_layer();
        } else {
            $('#category_extra').hide('fast');
        }
    }
    ).change(); // change called to trigger (in case we've come in with potholes selected)

});

