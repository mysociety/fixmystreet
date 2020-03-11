/*
 * Maps for FMS using Buckinghamshire Council's WMTS tile server
 */

fixmystreet.maps.layer_bounds = new OpenLayers.Bounds(
    381056.269,
    138592.641,
    584521.259,
    284907.516);

fixmystreet.maps.matrix_ids = [
    {
        "identifier": "0",
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "scaleDenominator": 944942.3660750897,
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 86,
        "matrixHeight": 64,
    },
    {
        "identifier": "1",
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "scaleDenominator": 472471.18303754483,
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 172,
        "matrixHeight": 128,
    },
    {
        "identifier": "2",
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "scaleDenominator": 236235.59151877242,
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 343,
        "matrixHeight": 256,
    },
    {
        "identifier": "3",
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "scaleDenominator": 118117.79575938621,
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 686,
        "matrixHeight": 512,
    },
    {
        "identifier": "4",
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "scaleDenominator": 60476.31142880573,
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 1340,
        "matrixHeight": 1000,
    },
    {
        "identifier": "5",
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "scaleDenominator": 30238.155714402867,
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 2679,
        "matrixHeight": 1999,
    },
    {
        "identifier": "6",
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "scaleDenominator": 15119.077857201433,
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 5357,
        "matrixHeight": 3997,
    },
    {
        "identifier": "7",
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "scaleDenominator": 7559.538928600717,
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 10713,
        "matrixHeight": 7994,
    },
    {
        "identifier": "8",
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "scaleDenominator": 3779.7694643003583,
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 21426,
        "matrixHeight": 15988,
    },
    {
        "identifier": "9",
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "scaleDenominator": 1889.8847321501792,
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 42852,
        "matrixHeight": 31976,
    },
    {
        "identifier": "10",
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "scaleDenominator": 944.9423660750896,
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 85703,
        "matrixHeight": 63951,
    }
];

/*
 * maps.config() is called on dom ready in map-OpenLayers.js
 * to setup the way the map should operate.
 */
fixmystreet.maps.config = function() {
    fixmystreet.controls = [
        new OpenLayers.Control.ArgParserFMS(),
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.PermalinkFMS('map'),
        new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' })
    ];

    /* Linking back to around from report page, keeping track of map moves */
    if ( fixmystreet.page == 'report' ) {
        fixmystreet.controls.push( new OpenLayers.Control.PermalinkFMS('key-tool-problems-nearby', '/around') );
    }

    this.setup_wmts_base_map();
};

fixmystreet.maps.zoom_for_normal_size = 7;
fixmystreet.maps.zoom_for_small_size = 4;
