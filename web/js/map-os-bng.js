fixmystreet.maps.config = function() {
    fixmystreet.maps.controls.unshift( new OpenLayers.Control.AttributionFMS() );
};

fixmystreet.maps.tile_base = 'https://{S}tilma.mysociety.org/mapcache/gmaps/oml@osmaps';

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

    tile_prefix: [ '', 'a-', 'b-', 'c-' ],

    getURL: function (bounds) {
        var xyz = this.getXYZ(bounds);
        var url = this.url;
        if (!fixmystreet.os_premium && fixmystreet.os_oml_zoom_switch && xyz.z >= fixmystreet.os_oml_zoom_switch) {
            url = [];
            for (i=0; i < this.tile_prefix.length; i++) {
                url.push( fixmystreet.maps.tile_base.replace('{S}', this.tile_prefix[i]) + "/${z}/${x}/${y}.png" );
            }
        }

        if (OpenLayers.Util.isArray(url)) {
            var s = '' + xyz.x + xyz.y + xyz.z;
            url = this.selectUrl(s, url);
        }
        return OpenLayers.String.format(url, xyz);
    },

    CLASS_NAME: "OpenLayers.Layer.OSMapsBNG"
});

OpenLayers.Layer.OSLeisure = OpenLayers.Class(OpenLayers.Layer.OSMapsBNG, {
    getURL: function (bounds) {
        var url = OpenLayers.Layer.OSMapsBNG.prototype.getURL.apply(this, [bounds]);
        var regex = new RegExp(fixmystreet.os_layer + '/([78])');
        url = url.replace(regex, 'Leisure_27700/$1');
        return url;
    },

    CLASS_NAME: "OpenLayers.Layer.OSLeisure"
});

fixmystreet.maps.zoom_for_normal_size = 8;
fixmystreet.maps.zoom_for_small_size = 6;
