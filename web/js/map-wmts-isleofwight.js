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
  //},
  //{
    //"identifier": 1,
    //"scaleDenominator": 472471.18303754483,
  //},
  //{
    //"identifier": 2,
    //"scaleDenominator": 377976.9464300358,
  //},
  //{
    //"identifier": 3,
    //"scaleDenominator": 283482.7098225269,
  //},
  //{
    //"identifier": 4,
    //"scaleDenominator": 188988.4732150179,
  //},
  {
    "identifier": 5,
    "scaleDenominator": 94494.23660750895,
  },
  {
    "identifier": 6,
    "scaleDenominator": 70870.67745563173,
  },
  {
    "identifier": 7,
    "scaleDenominator": 47247.118303754476,
  },
  {
    "identifier": 8,
    "scaleDenominator": 23623.559151877238,
  },
  {
    "identifier": 9,
    "scaleDenominator": 9449.423660750896,
  },
  {
    "identifier": 10,
    "scaleDenominator": 7559.538928600717,
  },
  {
    "identifier": 11,
    "scaleDenominator": 5669.654196450538,
  },
  {
    "identifier": 12,
    "scaleDenominator": 3779.7694643003583,
  },
  {
    "identifier": 13,
    "scaleDenominator": 1889.8847321501792,
  },
  {
    "identifier": 14,
    "scaleDenominator": 944.9423660750896,
  },
  {
    "identifier": 15,
    "scaleDenominator": 377.9769464300358,
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
