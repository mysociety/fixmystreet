fixmystreet.maps.config = function() {
    fixmystreet.maps.controls.unshift( new OpenLayers.Control.AttributionFMS() );
};

OpenLayers.Layer.OSMapsBNG = OpenLayers.Class(OpenLayers.Layer.XYZ, {
    initialize: function(name, options) {
        var url = fixmystreet.os_url.replace('%s', fixmystreet.os_layer) + "/${z}/${x}/${y}.png";
        if (fixmystreet.os_key) {
            url += "?key=" + fixmystreet.os_key;
        }

        var year = (new Date()).getFullYear();
        var logo = '<div class="os-api-branding logo"></div>';
        var attribution = '<div class="os-api-branding copyright">Contains National Highways and OS data<br>&copy; Crown copyright and database rights ' + year;
        if (fixmystreet.os_licence) {
            attribution += " " + fixmystreet.os_licence;
        }
        attribution += '</div>';
        this.attribution = logo + attribution;

        options = OpenLayers.Util.extend({
            units: "m",
            projection: new OpenLayers.Projection("EPSG:27700"),
            tileOrigin: new OpenLayers.LonLat(-238375, 1376256),
            maxExtent: new OpenLayers.Bounds(-3276800, -3276800, 3276800, 3276800),
            resolutions: [896, 448, 224, 112, 56, 28, 14, 7, 7/2, 7/4, 7/8, 7/16, 7/32, 7/64].slice(fixmystreet.zoomOffset || 0).slice(0, fixmystreet.numZoomLevels),
        }, options);
        OpenLayers.Layer.XYZ.prototype.initialize.call(this, name, url, options);
    },

    CLASS_NAME: "OpenLayers.Layer.OSMapsBNG"
});

fixmystreet.maps.zoom_for_normal_size = 8;
fixmystreet.maps.zoom_for_small_size = 6;
