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
        "scaleDenominator": 944942.3660750897,
    },
    {
        "identifier": "1",
        "scaleDenominator": 472471.18303754483,
    },
    {
        "identifier": "2",
        "scaleDenominator": 236235.59151877242,
    },
    {
        "identifier": "3",
        "scaleDenominator": 118117.79575938621,
    },
    {
        "identifier": "4",
        "scaleDenominator": 60476.31142880573,
    },
    {
        "identifier": "5",
        "scaleDenominator": 30238.155714402867,
    },
    {
        "identifier": "6",
        "scaleDenominator": 15119.077857201433,
    },
    {
        "identifier": "7",
        "scaleDenominator": 7559.538928600717,
    },
    {
        "identifier": "8",
        "scaleDenominator": 3779.7694643003583,
    },
    {
        "identifier": "9",
        "scaleDenominator": 1889.8847321501792,
    },
    {
        "identifier": "10",
        "scaleDenominator": 944.9423660750896,
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
