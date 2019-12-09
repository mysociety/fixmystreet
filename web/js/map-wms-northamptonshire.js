/*
 * Maps for FMS using Northamptonshire's tile server
 */

fixmystreet.maps.layer_bounds = new OpenLayers.Bounds(
395000,210000,572000,325000
);

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

    this.setup_wms_base_map();
};

fixmystreet.maps.marker_size = function() {
    var zoom = fixmystreet.map.getZoom() + fixmystreet.zoomOffset;
    if (zoom >= 8) {
        return 'normal';
    } else if (zoom >= 4) {
        return 'small';
    } else {
        return 'mini';
    }
};
