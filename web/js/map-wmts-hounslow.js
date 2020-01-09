/*
 * Maps for FMS using Hounslow Highways' WMTS tile server
 */

fixmystreet.maps.layer_bounds = new OpenLayers.Bounds(
    500968.38879189314,
    164348.14012837573,
    528802.2803971764,
    185779.43299096148);

fixmystreet.maps.matrix_ids = [
    // The first 5 levels don't load and are really zoomed-out, so
    //  they're not included here.
    // {
    //     "identifier": 0,
    //     "scaleDenominator": 566965.4196450538,
    //     "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    //     "tileWidth": 256,
    //     "tileHeight": 256,
    //     "matrixWidth": 142,
    //     "matrixHeight": 106,
    // },
    // {
    //     "identifier": 1,
    //     "scaleDenominator": 472471.18303754483,
    //     "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    //     "tileWidth": 256,
    //     "tileHeight": 256,
    //     "matrixWidth": 170,
    //     "matrixHeight": 128,
    // },
    // {
    //     "identifier": 2,
    //     "scaleDenominator": 377976.9464300358,
    //     "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    //     "tileWidth": 256,
    //     "tileHeight": 256,
    //     "matrixWidth": 213,
    //     "matrixHeight": 159,
    // },
    // {
    //     "identifier": 3,
    //     "scaleDenominator": 283482.7098225269,
    //     "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    //     "tileWidth": 256,
    //     "tileHeight": 256,
    //     "matrixWidth": 283,
    //     "matrixHeight": 212,
    // },
    // {
    //     "identifier": 4,
    //     "scaleDenominator": 188988.4732150179,
    //     "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    //     "tileWidth": 256,
    //     "tileHeight": 256,
    //     "matrixWidth": 425,
    //     "matrixHeight": 318,
    // },
    {
        "identifier": 5,
        "scaleDenominator": 94494.23660750895,
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 849,
        "matrixHeight": 636,
    },
    {
        "identifier": 6,
        "scaleDenominator": 70870.67745563173,
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 1132,
        "matrixHeight": 848,
    },
    {
        "identifier": 7,
        "scaleDenominator": 47247.118303754476,
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 1698,
        "matrixHeight": 1272,
    },
    {
        "identifier": 8,
        "scaleDenominator": 23623.559151877238,
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 3396,
        "matrixHeight": 2543,
    },
    {
        "identifier": 9,
        "scaleDenominator": 9449.423660750896,
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 8488,
        "matrixHeight": 6358,
    },
    {
        "identifier": 10,
        "scaleDenominator": 7559.538928600717,
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 10610,
        "matrixHeight": 7947,
    },
    {
        "identifier": 11,
        "scaleDenominator": 5669.654196450538,
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 14147,
        "matrixHeight": 10596,
    },
    {
        "identifier": 12,
        "scaleDenominator": 3779.7694643003583,
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 21220,
        "matrixHeight": 15893,
    },
    {
        "identifier": 13,
        "scaleDenominator": 1889.8847321501792,
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 42440,
        "matrixHeight": 31786,
    },
    {
        "identifier": 14,
        "scaleDenominator": 944.9423660750896,
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 84880,
        "matrixHeight": 63571,
    },
    {
        "identifier": 15,
        "scaleDenominator": 377.9769464300358,
        "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
        "tileWidth": 256,
        "tileHeight": 256,
        "matrixWidth": 212200,
        "matrixHeight": 158927,
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

fixmystreet.maps.zoom_for_normal_size = 8;
fixmystreet.maps.zoom_for_small_size = 4;
