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
      "scaleDenominator": 181428.9342864172,
    },
    {
      "identifier": "1",
      "scaleDenominator": 90714.4671432086,
    },
    {
      "identifier": "2",
      "scaleDenominator": 45357.2335716043,
    },
    {
      "identifier": "3",
      "scaleDenominator": 22678.61678580215,
    },
    {
      "identifier": "4",
      "scaleDenominator": 11339.308392901075,
    },
    {
      "identifier": "5",
      "scaleDenominator": 5669.654196450538,
    },
    {
      "identifier": "6",
      "scaleDenominator": 2834.827098225269,
    },
    {
      "identifier": "7",
      "scaleDenominator": 1181.177957593862,
    },
    {
      "identifier": "8",
      "scaleDenominator": 708.7067745563172,
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
