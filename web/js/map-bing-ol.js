function set_map_config(perm) {
    fixmystreet.controls = [
        new OpenLayers.Control.Attribution(),
        new OpenLayers.Control.ArgParser(),
        new OpenLayers.Control.Navigation(),
        perm,
        //new OpenLayers.Control.ZoomPanel()
        new OpenLayers.Control.PanZoomFMS()
    ];
    fixmystreet.map_type = OpenLayers.Layer.Bing;
}

OpenLayers.Layer.Bing = OpenLayers.Class(OpenLayers.Layer.XYZ, {
    attributionTemplate: '${logo}${copyrights}',

    setMap: function() {
        OpenLayers.Layer.XYZ.prototype.setMap.apply(this, arguments);
        this.updateAttribution();
        this.map.events.register("moveend", this, this.updateAttribution);
    },

    updateAttribution: function() {
        var z = this.map.getZoom() + this.zoomOffset;
        var copyrights;
        var logo = '';
        if (z >= 16) {
            copyrights = 'Contains Ordnance Survey data &copy; Crown copyright and database right 2010';
        } else {
            logo = '<a href="http://www.bing.com/maps/"><img border=0 src="http://dev.virtualearth.net/Branding/logo_powered_by.png"></a>';
            copyrights = '&copy; 2011 <a href="http://www.bing.com/maps/">Microsoft</a>. &copy; AND, Navteq, Ordnance Survey';
        }
        this.attribution = OpenLayers.String.format(this.attributionTemplate, {
            logo: logo,
            copyrights: copyrights
        });
        this.map && this.map.events.triggerEvent("changelayer", {
            layer: this,
            property: "attribution"
        });
    },

    initialize: function(name, options) {
        var url = [];
        options = OpenLayers.Util.extend({
            /* Below line added to OSM's file in order to allow minimum zoom level */
            maxResolution: 156543.0339/Math.pow(2, options.zoomOffset || 0),
            numZoomLevels: 18,
            transitionEffect: "resize",
            sphericalMercator: true,
            buffer: 0
            //attribution: "© Microsoft / OS 2010"
        }, options);
        var newArguments = [name, url, options];
        OpenLayers.Layer.XYZ.prototype.initialize.apply(this, newArguments);
    },

    get_quadkey: function(x, y, level) {
        var key = '';
        for (var i = level; i > 0; i--) {
            var digit = 0;
            var mask = 1 << (i - 1);
            if ((x & mask) != 0) {
                digit++;
            }
            if ((y & mask) != 0) {
                digit += 2;
            }
            key += digit;
        }
        return key;
    },

    getURL: function (bounds) {
        var res = this.map.getResolution();
        var x = Math.round((bounds.left - this.maxExtent.left)
            / (res * this.tileSize.w));
        var y = Math.round((this.maxExtent.top - bounds.top)
            / (res * this.tileSize.h));
        var z = this.serverResolutions != null ?
            OpenLayers.Util.indexOf(this.serverResolutions, res) :
            this.map.getZoom() + this.zoomOffset;

        if (z >= 16) {
            var url = [
                "http://tilma.mysociety.org/sv/${z}/${x}/${y}.png",
                "http://a.tilma.mysociety.org/sv/${z}/${x}/${y}.png",
                "http://b.tilma.mysociety.org/sv/${z}/${x}/${y}.png",
                "http://c.tilma.mysociety.org/sv/${z}/${x}/${y}.png"
            ];
        } else {
            var type = '';
            if (z > 10) type = '&productSet=mmOS';
            var url = [
                "http://ecn.t0.tiles.virtualearth.net/tiles/r${id}.png?g=701" + type,
                "http://ecn.t1.tiles.virtualearth.net/tiles/r${id}.png?g=701" + type,
                "http://ecn.t2.tiles.virtualearth.net/tiles/r${id}.png?g=701" + type,
                "http://ecn.t3.tiles.virtualearth.net/tiles/r${id}.png?g=701" + type
            ];
        }
        var s = '' + x + y + z;
        url = this.selectUrl(s, url);
       
        var id = this.get_quadkey(x, y, z);
        var path = OpenLayers.String.format(url, {'id': id, 'x': x, 'y': y, 'z': z});
        return path;
    },

    CLASS_NAME: "OpenLayers.Layer.Bing"
});
