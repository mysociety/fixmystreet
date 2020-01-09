/*
 * Maps for FMS using Bristol City Council's WMTS tile server
 */

// From the 'fullExtent' key from http://maps.bristol.gov.uk/arcgis/rest/services/base/2015_BCC_96dpi/MapServer?f=pjson
fixmystreet.maps.layer_bounds = new OpenLayers.Bounds(
    268756.311, // W
    98527.7031, // S
    385799.511, // E
    202566.1031); // N

fixmystreet.maps.matrix_ids = [
    {
      "identifier": "0",
      "supportedCRS": "urn:ogc:def:crs:EPSG::27700",
      "scaleDenominator": 181428.9342864172,
      "tileWidth": 256,
      "tileHeight": 256,
      "matrixWidth": 432,
      "matrixHeight": 337
    },
    {
      "identifier": "1",
      "supportedCRS": "urn:ogc:def:crs:EPSG::27700",
      "scaleDenominator": 90714.4671432086,
      "tileWidth": 256,
      "tileHeight": 256,
      "matrixWidth": 863,
      "matrixHeight": 673
    },
    {
      "identifier": "2",
      "supportedCRS": "urn:ogc:def:crs:EPSG::27700",
      "scaleDenominator": 45357.2335716043,
      "tileWidth": 256,
      "tileHeight": 256,
      "matrixWidth": 1725,
      "matrixHeight": 1345
    },
    {
      "identifier": "3",
      "supportedCRS": "urn:ogc:def:crs:EPSG::27700",
      "scaleDenominator": 22678.61678580215,
      "tileWidth": 256,
      "tileHeight": 256,
      "matrixWidth": 3449,
      "matrixHeight": 2690
    },
    {
      "identifier": "4",
      "supportedCRS": "urn:ogc:def:crs:EPSG::27700",
      "scaleDenominator": 11339.308392901075,
      "tileWidth": 256,
      "tileHeight": 256,
      "matrixWidth": 6898,
      "matrixHeight": 5379
    },
    {
      "identifier": "5",
      "supportedCRS": "urn:ogc:def:crs:EPSG::27700",
      "scaleDenominator": 5669.654196450538,
      "tileWidth": 256,
      "tileHeight": 256,
      "matrixWidth": 13795,
      "matrixHeight": 10758
    },
    {
      "identifier": "6",
      "supportedCRS": "urn:ogc:def:crs:EPSG::27700",
      "scaleDenominator": 2834.827098225269,
      "tileWidth": 256,
      "tileHeight": 256,
      "matrixWidth": 27590,
      "matrixHeight": 21515
    },
    {
      "identifier": "7",
      "supportedCRS": "urn:ogc:def:crs:EPSG::27700",
      "scaleDenominator": 1181.177957593862,
      "tileWidth": 256,
      "tileHeight": 256,
      "matrixWidth": 66215,
      "matrixHeight": 51634
    },
    {
      "identifier": "8",
      "supportedCRS": "urn:ogc:def:crs:EPSG::27700",
      "scaleDenominator": 708.7067745563172,
      "tileWidth": 256,
      "tileHeight": 256,
      "matrixWidth": 110359,
      "matrixHeight": 86057
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
        new OpenLayers.Control.PermalinkFMS('map')
    ];
    if ( fixmystreet.page != 'report' || !$('html').hasClass('mobile') ) {
        fixmystreet.controls.push( new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' }) );
    }

    /* Linking back to around from report page, keeping track of map moves */
    if ( fixmystreet.page == 'report' ) {
        fixmystreet.controls.push( new OpenLayers.Control.PermalinkFMS('key-tool-problems-nearby', '/around') );
    }

    this.setup_wmts_base_map();
};

fixmystreet.maps.zoom_for_normal_size = 7;
fixmystreet.maps.zoom_for_small_size = 4;
