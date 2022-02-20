/*
 * Maps for FMZ using Zurich council's WMTS tile server
 */

// From 'fullExtent' from http://www.gis.stadt-zuerich.ch/maps/rest/services/tiled95/LuftbildHybrid/MapServer?f=pjson
fixmystreet.maps.layer_bounds = new OpenLayers.Bounds(
    2480237, // W
    1062032, // S
    2846837, // E
    1315832); // N

fixmystreet.maps.matrix_ids = [
  {
    "scaleDenominator": 256000,
    "identifier": "0",
  },
  {
    "scaleDenominator": 128000,
    "identifier": "1",
  },
  {
    "scaleDenominator": 64000,
    "identifier": "2",
  },
  {
    "scaleDenominator": 32000,
    "identifier": "3",
  },
  {
    "scaleDenominator": 16000,
    "identifier": "4",
  },
  {
    "scaleDenominator": 8000,
    "identifier": "5",
  },
  {
    "scaleDenominator": 4000,
    "identifier": "6",
  },
  {
    "scaleDenominator": 2000,
    "identifier": "7",
  },
  {
    "scaleDenominator": 1000,
    "identifier": "8",
  },
  {
    "scaleDenominator": 500,
    "identifier": "9",
  },
  {
    "scaleDenominator": 250,
    "identifier": "10",
  }
];

(function() {
    function pin_dragged(lonlat) {
        document.getElementById('fixmystreet.latitude').value = lonlat.y.toFixed(6);
        document.getElementById('fixmystreet.longitude').value = lonlat.x.toFixed(6);
    }

    $(function(){
        fixmystreet.maps.base_layer_aerial = true;
        $('.map-layer-toggle').on('click', fixmystreet.maps.toggle_base);

        /* Admin dragging of pin */
        if (fixmystreet.page == 'admin') {
            fixmystreet.maps.admin_drag(pin_dragged, true);
        }
    });

})();

/*
 * maps.config() is called on dom ready in map-OpenLayers.js
 * to setup the way the map should operate.
 */
fixmystreet.maps.config = function() {
    fixmystreet.maps.controls = fixmystreet.maps.controls.slice(0, 3); // Cut out permalink and panzoom
    if ( fixmystreet.page != 'report' || !$('html').hasClass('mobile') ) {
        fixmystreet.maps.controls.push( new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' }) );
    }

    this.setup_wmts_base_map();

    fixmystreet.area_format = { fillColor: 'none', strokeWidth: 4, strokeColor: 'black' };
};

fixmystreet.maps.zoom_for_normal_size = 6;
fixmystreet.maps.zoom_for_small_size = 3;
