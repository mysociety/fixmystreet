/*
 * Maps for FMS using  Island Roads' WMTS tile server
 */

fixmystreet.maps.layer_bounds = new OpenLayers.Bounds(
  428576.1131782566,
  70608.46901095579,
  468137.51522498735,
  101069.6062942903
);

fixmystreet.maps.matrix_ids = [
    // The first 5 levels don't load and are really zoomed-out, so
    //  they're not included here.
  //{
    //"identifier": 0,
    //"scaleDenominator": 566965.4196450538,
    //"supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    //"tileWidth": 256,
    //"tileHeight": 256,
    //"matrixWidth": 140,
    //"matrixHeight": 109
  //},
  //{
    //"identifier": 1,
    //"scaleDenominator": 472471.18303754483,
    //"supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    //"tileWidth": 256,
    //"tileHeight": 256,
    //"matrixWidth": 168,
    //"matrixHeight": 130
  //},
  //{
    //"identifier": 2,
    //"scaleDenominator": 377976.9464300358,
    //"supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    //"tileWidth": 256,
    //"tileHeight": 256,
    //"matrixWidth": 210,
    //"matrixHeight": 163
  //},
  //{
    //"identifier": 3,
    //"scaleDenominator": 283482.7098225269,
    //"supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    //"tileWidth": 256,
    //"tileHeight": 256,
    //"matrixWidth": 280,
    //"matrixHeight": 217
  //},
  //{
    //"identifier": 4,
    //"scaleDenominator": 188988.4732150179,
    //"supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    //"tileWidth": 256,
    //"tileHeight": 256,
    //"matrixWidth": 420,
    //"matrixHeight": 325
  //},
  {
    "identifier": 5,
    "scaleDenominator": 94494.23660750895,
    "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    "tileWidth": 256,
    "tileHeight": 256,
    "matrixWidth": 840,
    "matrixHeight": 650
  },
  {
    "identifier": 6,
    "scaleDenominator": 70870.67745563173,
    "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    "tileWidth": 256,
    "tileHeight": 256,
    "matrixWidth": 1120,
    "matrixHeight": 867
  },
  {
    "identifier": 7,
    "scaleDenominator": 47247.118303754476,
    "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    "tileWidth": 256,
    "tileHeight": 256,
    "matrixWidth": 1680,
    "matrixHeight": 1300
  },
  {
    "identifier": 8,
    "scaleDenominator": 23623.559151877238,
    "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    "tileWidth": 256,
    "tileHeight": 256,
    "matrixWidth": 3360,
    "matrixHeight": 2599
  },
  {
    "identifier": 9,
    "scaleDenominator": 9449.423660750896,
    "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    "tileWidth": 256,
    "tileHeight": 256,
    "matrixWidth": 8399,
    "matrixHeight": 6496
  },
  {
    "identifier": 10,
    "scaleDenominator": 7559.538928600717,
    "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    "tileWidth": 256,
    "tileHeight": 256,
    "matrixWidth": 10499,
    "matrixHeight": 8120
  },
  {
    "identifier": 11,
    "scaleDenominator": 5669.654196450538,
    "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    "tileWidth": 256,
    "tileHeight": 256,
    "matrixWidth": 13998,
    "matrixHeight": 10826
  },
  {
    "identifier": 12,
    "scaleDenominator": 3779.7694643003583,
    "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    "tileWidth": 256,
    "tileHeight": 256,
    "matrixWidth": 20997,
    "matrixHeight": 16239
  },
  {
    "identifier": 13,
    "scaleDenominator": 1889.8847321501792,
    "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    "tileWidth": 256,
    "tileHeight": 256,
    "matrixWidth": 41993,
    "matrixHeight": 32478
  },
  {
    "identifier": 14,
    "scaleDenominator": 944.9423660750896,
    "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    "tileWidth": 256,
    "tileHeight": 256,
    "matrixWidth": 83985,
    "matrixHeight": 64955
  },
  {
    "identifier": 15,
    "scaleDenominator": 377.9769464300358,
    "supportedCRS": "urn:ogc:def:crs:EPSG:27700",
    "tileWidth": 256,
    "tileHeight": 256,
    "matrixWidth": 209961,
    "matrixHeight": 162387
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
