/*
 * Maps for FMZ using Zurich council's WMTS tile server
 */

// From 'fullExtent' from http://www.gis.stadt-zuerich.ch/maps/rest/services/tiled95/LuftbildHybrid/MapServer?f=pjson
fixmystreet.maps.layer_bounds = new OpenLayers.Bounds(
    2676000.9069999997, // W
    1241399.842, // S
    2689900.9069999997, // E
    1254599.842); // N

fixmystreet.maps.matrix_ids = [
  // The two highest zoom levels are pretty much useless so they're disabled.
  // {
  //   "matrixHeight": 882,
  //   "scaleDenominator": 241905.24571522293,
  //   "identifier": "0",
  //   "tileWidth": 512,
  //   "supportedCRS": "urn:ogc:def:crs:EPSG::2056",
  //   "tileHeight": 512,
  //   "matrixWidth": 868
  // },
  // {
  //   "matrixHeight": 1764,
  //   "scaleDenominator": 120952.62285761147,
  //   "identifier": "1",
  //   "tileWidth": 512,
  //   "supportedCRS": "urn:ogc:def:crs:EPSG::2056",
  //   "tileHeight": 512,
  //   "matrixWidth": 1735
  // },

  {
    "matrixHeight": 3527,
    "scaleDenominator": 60476.31142880573,
    "identifier": "2",
    "tileWidth": 512,
    "supportedCRS": "urn:ogc:def:crs:EPSG::2056",
    "tileHeight": 512,
    "matrixWidth": 3470
  },
  {
    "matrixHeight": 7053,
    "scaleDenominator": 30238.155714402867,
    "identifier": "3",
    "tileWidth": 512,
    "supportedCRS": "urn:ogc:def:crs:EPSG::2056",
    "tileHeight": 512,
    "matrixWidth": 6939
  },
  {
    "matrixHeight": 14106,
    "scaleDenominator": 15119.077857201433,
    "identifier": "4",
    "tileWidth": 512,
    "supportedCRS": "urn:ogc:def:crs:EPSG::2056",
    "tileHeight": 512,
    "matrixWidth": 13877
  },
  {
    "matrixHeight": 28211,
    "scaleDenominator": 7559.538928600717,
    "identifier": "5",
    "tileWidth": 512,
    "supportedCRS": "urn:ogc:def:crs:EPSG::2056",
    "tileHeight": 512,
    "matrixWidth": 27753
  },
  {
    "matrixHeight": 56422,
    "scaleDenominator": 3779.7694643003583,
    "identifier": "6",
    "tileWidth": 512,
    "supportedCRS": "urn:ogc:def:crs:EPSG::2056",
    "tileHeight": 512,
    "matrixWidth": 55505
  },
  {
    "matrixHeight": 112844,
    "scaleDenominator": 1889.8847321501792,
    "identifier": "7",
    "tileWidth": 512,
    "supportedCRS": "urn:ogc:def:crs:EPSG::2056",
    "tileHeight": 512,
    "matrixWidth": 111010
  },
  {
    "matrixHeight": 225687,
    "scaleDenominator": 944.9423660750896,
    "identifier": "8",
    "tileWidth": 512,
    "supportedCRS": "urn:ogc:def:crs:EPSG::2056",
    "tileHeight": 512,
    "matrixWidth": 222020
  },
  {
    "matrixHeight": 451374,
    "scaleDenominator": 472.4711830375448,
    "identifier": "9",
    "tileWidth": 512,
    "supportedCRS": "urn:ogc:def:crs:EPSG::2056",
    "tileHeight": 512,
    "matrixWidth": 444039
  },
  {
    "matrixHeight": 902748,
    "scaleDenominator": 236.2355915187724,
    "identifier": "10",
    "tileWidth": 512,
    "supportedCRS": "urn:ogc:def:crs:EPSG::2056",
    "tileHeight": 512,
    "matrixWidth": 888078
  }
];

(function() {
    function pin_dragged(lonlat) {
        document.getElementById('fixmystreet.latitude').value = lonlat.y;
        document.getElementById('fixmystreet.longitude').value = lonlat.x;
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
                $(window).load(function() { fixmystreet.maps.admin_drag(pin_dragged, true); });
            } else {
                fixmystreet.maps.admin_drag(pin_dragged, true);
            }
        }
    });

})();

/*
 * maps.config() is called on dom ready in map-OpenLayers.js
 * to setup the way the map should operate.
 */
fixmystreet.maps.config = function() {
    // This stuff is copied from js/map-bing-ol.js

    fixmystreet.controls = [
        new OpenLayers.Control.ArgParser(),
        new OpenLayers.Control.Navigation()
    ];
    if ( fixmystreet.page != 'report' || !$('html').hasClass('mobile') ) {
        fixmystreet.controls.push( new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' }) );
    }

    /* Linking back to around from report page, keeping track of map moves */
    if ( fixmystreet.page == 'report' ) {
        fixmystreet.controls.push( new OpenLayers.Control.PermalinkFMS('key-tool-problems-nearby', '/around') );
    }

    this.setup_wmts_base_map();

    fixmystreet.area_format = { fillColor: 'none', strokeWidth: 4, strokeColor: 'black' };
};

fixmystreet.maps.marker_size = function() {
    var zoom = fixmystreet.map.getZoom() + fixmystreet.zoomOffset;
    if (zoom >= 6) {
        return 'normal';
    } else if (zoom >= 3) {
        return 'small';
    } else {
        return 'mini';
    }
};
