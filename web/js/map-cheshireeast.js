fixmystreet.maps.config = function() {
    fixmystreet.controls = [
        new OpenLayers.Control.Attribution(),
        new OpenLayers.Control.ArgParserFMS(),
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.PermalinkFMS('map'),
        new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' })
    ];
    /* Linking back to around from report page, keeping track of map moves */
    if ( fixmystreet.page == 'report' ) {
        fixmystreet.controls.push( new OpenLayers.Control.PermalinkFMS('key-tool-problems-nearby', '/around') );
    }
    fixmystreet.map_type = OpenLayers.Layer.CheshireEast;
};

OpenLayers.Layer.CheshireEast = OpenLayers.Class(OpenLayers.Layer.XYZ, {
    url: 'https://maps-cache.cheshiresharedservices.gov.uk/maps/?wmts/CE_OS_AllBasemaps_COLOUR/oscce_grid/${z}/${x}/${y}.jpeg&KEY=3a3f5c60eca1404ea114e6941c9d3895',

    initialize: function(name, options) {
        options = OpenLayers.Util.extend({
            units: "m",
            projection: new OpenLayers.Projection("EPSG:27700"),
            maxExtent: new OpenLayers.Bounds(-3276800, -3276800, 3276800, 3276800),
            resolutions: [1792.003584007169, 896.0017920035843, 448.0008960017922, 224.0004480008961, 112.000224000448, 56.000112000224014, 28.000056000111993, 14.000028000056004, 7.000014000028002, 2.8000056000112004, 1.4000028000056002, 0.7000014000028001, 0.35000070000140004, 0.14000028000056003].slice(fixmystreet.zoomOffset || 0),
        }, options);
        OpenLayers.Layer.XYZ.prototype.initialize.call(this, name, this.url, options);
    },

    CLASS_NAME: "OpenLayers.Layer.CheshireEast"
});

fixmystreet.maps.zoom_for_normal_size = 7;
fixmystreet.maps.zoom_for_small_size = 4;
