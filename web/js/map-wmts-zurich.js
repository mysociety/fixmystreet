/* 
 * Maps for FMZ using Zurich council's WMTS tile server 
 */

function fixmystreet_zurich_admin_drag() {
    var admin_drag = new OpenLayers.Control.DragFeature( fixmystreet.markers, {
        onComplete: function(feature, e) {
            var lonlat = feature.geometry.clone();
            lonlat.transform(
                fixmystreet.map.getProjectionObject(),
                new OpenLayers.Projection("EPSG:4326")
            );
            if (window.confirm( 'Richtiger Ort?' ) ) {
                // Store new co-ordinates
                document.getElementById('fixmystreet.latitude').value = lonlat.y;
                document.getElementById('fixmystreet.longitude').value = lonlat.x;
            } else {
                // Put it back
                var lat = document.getElementById('fixmystreet.latitude').value;
                var lon = document.getElementById('fixmystreet.longitude').value;
                lonlat = new OpenLayers.LonLat(lon, lat).transform(
                    new OpenLayers.Projection("EPSG:4326"),
                    fixmystreet.map.getProjectionObject()
                );
                fixmystreet.markers.features[0].move(lonlat);
            }
        }
    } );
    fixmystreet.map.addControl( admin_drag );
    admin_drag.activate();
}

$(function(){
    $('#map_layer_toggle').toggle(function(){
        $(this).text('Luftbild');
        fixmystreet.map.setBaseLayer(fixmystreet.map.layers[1]);
    }, function(){
        $(this).text('Stadtplan');
        fixmystreet.map.setBaseLayer(fixmystreet.map.layers[0]);
    });

    /* Admin dragging of pin */
    if (fixmystreet.page == 'admin') {
        if ($.browser.msie) {
            $(window).load(fixmystreet_zurich_admin_drag);
        } else {
            fixmystreet_zurich_admin_drag();
        }
    }
});

/* 
 * set_map_config() is called on dom ready in map-OpenLayers.js
 * to setup the way the map should operate.
 */
 function set_map_config(perm) {
    // This stuff is copied from js/map-bing-ol.js

    var nav_opts = { zoomWheelEnabled: false };
    if (fixmystreet.page == 'around' && $('html').hasClass('mobile')) {
        nav_opts = {};
    }
    fixmystreet.nav_control = new OpenLayers.Control.Navigation(nav_opts);

    fixmystreet.controls = [
        new OpenLayers.Control.ArgParser(),
        fixmystreet.nav_control
    ];
    if ( fixmystreet.page != 'report' || !$('html').hasClass('mobile') ) {
        fixmystreet.controls.push( new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' }) );
    }

    /* Linking back to around from report page, keeping track of map moves */
    if ( fixmystreet.page == 'report' ) {
        fixmystreet.controls.push( new OpenLayers.Control.PermalinkFMS('key-tool-problems-nearby', '/around') );
    }

    fixmystreet.map_type = OpenLayers.Layer.WMTS;

    // Set DPI - default is 72
    OpenLayers.DOTS_PER_INCH = 96;

    fixmystreet.map_options = {
        maxExtent: new OpenLayers.Bounds(676000, 241402, 689896, 254596),
        units: 'm',
        scales: [ '64000', '32000', '16000', '8000', '4000', '2000', '1000', '500', '250' ]
    };

    var layer_options = {
        projection: new OpenLayers.Projection("EPSG:21781"),
        name: "tiled_LuftbildHybrid",
        layer: "tiled_LuftbildHybrid",
        matrixSet: "default028mm",
        requestEncoding: "REST",
        url: "//www.gis.stadt-zuerich.ch/maps/rest/services/tiled/LuftbildHybrid/MapServer/WMTS/tile/",
        style: "default",
        matrixIds: [
            // {
            //     "identifier": "0",
            //     "matrixHeight": 903,
            //     "matrixWidth": 889,
            //     "scaleDenominator": 236235.59151877242,
            //     "supportedCRS": "urn:ogc:def:crs:EPSG::21781",
            //     "tileHeight": 512,
            //     "tileWidth": 512,
            //     "topLeftCorner": {
            //         "lat": 30814423,
            //         "lon": -29386322
            //     }
            // },
            // {
            //     "identifier": "1",
            //     "matrixHeight": 1806,
            //     "matrixWidth": 1777,
            //     "scaleDenominator": 118117.79575938621,
            //     "supportedCRS": "urn:ogc:def:crs:EPSG::21781",
            //     "tileHeight": 512,
            //     "tileWidth": 512,
            //     "topLeftCorner": {
            //         "lat": 30814423,
            //         "lon": -29386322
            //     }
            // },
            {
                "identifier": "2",
                "matrixHeight": 3527,
                "matrixWidth": 3470,
                "scaleDenominator": 60476.31142880573,
                "supportedCRS": "urn:ogc:def:crs:EPSG::21781",
                "tileHeight": 512,
                "tileWidth": 512,
                "topLeftCorner": {
                    "lat": 30814423,
                    "lon": -29386322
                }
            },
            {
                "identifier": "3",
                "matrixHeight": 7053,
                "matrixWidth": 6939,
                "scaleDenominator": 30238.155714402867,
                "supportedCRS": "urn:ogc:def:crs:EPSG::21781",
                "tileHeight": 512,
                "tileWidth": 512,
                "topLeftCorner": {
                    "lat": 30814423,
                    "lon": -29386322
                }
            },
            {
                "identifier": "4",
                "matrixHeight": 14106,
                "matrixWidth": 13877,
                "scaleDenominator": 15119.077857201433,
                "supportedCRS": "urn:ogc:def:crs:EPSG::21781",
                "tileHeight": 512,
                "tileWidth": 512,
                "topLeftCorner": {
                    "lat": 30814423,
                    "lon": -29386322
                }
            },
            {
                "identifier": "5",
                "matrixHeight": 28211,
                "matrixWidth": 27753,
                "scaleDenominator": 7559.538928600717,
                "supportedCRS": "urn:ogc:def:crs:EPSG::21781",
                "tileHeight": 512,
                "tileWidth": 512,
                "topLeftCorner": {
                    "lat": 30814423,
                    "lon": -29386322
                }
            },
            {
                "identifier": "6",
                "matrixHeight": 56422,
                "matrixWidth": 55505,
                "scaleDenominator": 3779.7694643003583,
                "supportedCRS": "urn:ogc:def:crs:EPSG::21781",
                "tileHeight": 512,
                "tileWidth": 512,
                "topLeftCorner": {
                    "lat": 30814423,
                    "lon": -29386322
                }
            },
            {
                "identifier": "7",
                "matrixHeight": 112844,
                "matrixWidth": 111010,
                "scaleDenominator": 1889.8847321501792,
                "supportedCRS": "urn:ogc:def:crs:EPSG::21781",
                "tileHeight": 512,
                "tileWidth": 512,
                "topLeftCorner": {
                    "lat": 30814423,
                    "lon": -29386322
                }
            },
            {
                "identifier": "8",
                "matrixHeight": 225687,
                "matrixWidth": 222020,
                "scaleDenominator": 944.9423660750896,
                "supportedCRS": "urn:ogc:def:crs:EPSG::21781",
                "tileHeight": 512,
                "tileWidth": 512,
                "topLeftCorner": {
                    "lat": 30814423,
                    "lon": -29386322
                }
            },
            {
                "identifier": "9",
                "matrixHeight": 451374,
                "matrixWidth": 444039,
                "scaleDenominator": 472.4711830375448,
                "supportedCRS": "urn:ogc:def:crs:EPSG::21781",
                "tileHeight": 512,
                "tileWidth": 512,
                "topLeftCorner": {
                    "lat": 30814423,
                    "lon": -29386322
                }
            },
            {
                "identifier": "10",
                "matrixHeight": 902748,
                "matrixWidth": 888078,
                "scaleDenominator": 236.2355915187724,
                "supportedCRS": "urn:ogc:def:crs:EPSG::21781",
                "tileHeight": 512,
                "tileWidth": 512,
                "topLeftCorner": {
                    "lat": 30814423,
                    "lon": -29386322
                }
            }
        ]
    };
    fixmystreet.layer_options = [
        layer_options, OpenLayers.Util.applyDefaults({
            name: "Stadtplan3D",
            layer: "Stadtplan3D",
            url:  "//www.gis.stadt-zuerich.ch/maps/rest/services/tiled/Stadtplan3D/MapServer/WMTS/tile/"
        }, layer_options)
    ];

    // Give main code a new bbox_strategy that translates between
    // lat/lon and our swiss coordinates
    fixmystreet.bbox_strategy = new OpenLayers.Strategy.ZurichBBOX({ratio: 1});

    fixmystreet.area_format = { fillColor: 'none', strokeWidth: 4, strokeColor: 'black' };
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
