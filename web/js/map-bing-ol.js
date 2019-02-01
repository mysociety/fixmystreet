fixmystreet.maps.config = function() {
    var permalink_id;
    if ($('#map_permalink').length) {
        permalink_id = 'map_permalink';
    }

    fixmystreet.controls = [
        new OpenLayers.Control.Attribution(),
        new OpenLayers.Control.ArgParserFMS(),
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.PermalinkFMS(permalink_id),
        new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' })
    ];
    /* Linking back to around from report page, keeping track of map moves */
    if ( fixmystreet.page == 'report' ) {
        fixmystreet.controls.push( new OpenLayers.Control.PermalinkFMS('key-tool-problems-nearby', '/around') );
    }
    fixmystreet.map_type = OpenLayers.Layer.Bing;
};

OpenLayers.Layer.Bing = OpenLayers.Class(OpenLayers.Layer.XYZ, {
    attributionTemplate: '${logo}${copyrights}',

    setMap: function() {
        OpenLayers.Layer.XYZ.prototype.setMap.apply(this, arguments);
        this.updateAttribution();
    },

    _updateAttribution: function(copyrights, logo) {
        this.attribution = OpenLayers.String.format(this.attributionTemplate, {
            logo: logo,
            copyrights: copyrights
        });
        if (this.map) {
            this.map.events.triggerEvent("changelayer", {
                layer: this,
                property: "attribution"
            });
        }
    },

    updateAttribution: function() {
        var copyrights = '&copy; 2011 <a href="https://www.bing.com/maps/">Microsoft</a>. &copy; AND, Navteq';
        var logo = '<a href="https://www.bing.com/maps/"><img border=0 src="//dev.virtualearth.net/Branding/logo_powered_by.png"></a>';
        this._updateAttribution(copyrights, logo);
    },

    initialize: function(name, options) {
        var url = [];
        options = OpenLayers.Util.extend({
            /* Below line added to OSM's file in order to allow minimum zoom level */
            maxResolution: 156543.03390625/Math.pow(2, options.zoomOffset || 0),
            numZoomLevels: 19,
            sphericalMercator: true,
            buffer: 0
        }, options);
        var newArguments = [name, url, options];
        OpenLayers.Layer.XYZ.prototype.initialize.apply(this, newArguments);
    },

    get_quadkey: function(x, y, level) {
        var key = '';
        for (var i = level; i > 0; i--) {
            var digit = 0;
            var mask = 1 << (i - 1);
            if ((x & mask) !== 0) {
                digit++;
            }
            if ((y & mask) !== 0) {
                digit += 2;
            }
            key += digit;
        }
        return key;
    },

    getURL: function (bounds) {
        var res = this.map.getResolution();
        var x = Math.round((bounds.left - this.maxExtent.left) /
            (res * this.tileSize.w));
        var y = Math.round((this.maxExtent.top - bounds.top) /
            (res * this.tileSize.h));
        var z = this.serverResolutions !== null ?
            OpenLayers.Util.indexOf(this.serverResolutions, res) :
            this.map.getZoom() + this.zoomOffset;

        var url = this.get_urls(bounds, z);
        var s = '' + x + y + z;
        url = this.selectUrl(s, url);
       
        var id = this.get_quadkey(x, y, z);
        var path = OpenLayers.String.format(url, {'id': id, 'x': x, 'y': y, 'z': z});
        return path;
    },

    get_urls: function(bounds, z) {
        return [
            "//ecn.t0.tiles.virtualearth.net/tiles/r${id}.png?g=6570",
            "//ecn.t1.tiles.virtualearth.net/tiles/r${id}.png?g=6570",
            "//ecn.t2.tiles.virtualearth.net/tiles/r${id}.png?g=6570",
            "//ecn.t3.tiles.virtualearth.net/tiles/r${id}.png?g=6570"
        ];
    },

    CLASS_NAME: "OpenLayers.Layer.Bing"
});
