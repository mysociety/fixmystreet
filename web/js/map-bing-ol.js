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
};

$(function(){
    $('.map-layer-toggle').on('click', fixmystreet.maps.toggle_base);
    // If page loaded with Aerial as starting, rather than default road
    if ($('.map-layer-toggle').text() == translation_strings.map_roads) {
        fixmystreet.map.setBaseLayer(fixmystreet.map.layers[1]);
    }
});

OpenLayers.Layer.Bing = OpenLayers.Class(OpenLayers.Layer.XYZ, {
    tile_base: '//t{S}.ssl.ak.dynamic.tiles.virtualearth.net/comp/ch/${id}?mkt=en-US&it=G,L&src=t&shading=hill&og=969&n=z',
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
        var year = (new Date()).getFullYear();
        var copyrights = '&copy; ' + year + ' <a href="https://www.bing.com/maps/">Microsoft</a>, HERE';
        var logo = '<a href="https://www.bing.com/maps/"><img border=0 src="//dev.virtualearth.net/Branding/logo_powered_by.png"></a>';
        this._updateAttribution(copyrights, logo);
    },

    initialize: function(name, options) {
        var url = [];
        options = OpenLayers.Util.extend({
            /* Below line added to OSM's file in order to allow minimum zoom level */
            maxResolution: 156543.03390625/Math.pow(2, options.zoomOffset || 0),
            numZoomLevels: 20,
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
        var urls = [];
        for (var i=0; i<4; i++) {
            urls.push(this.tile_base.replace('{S}', i));
        }
        return urls;
    },

    CLASS_NAME: "OpenLayers.Layer.Bing"
});

OpenLayers.Layer.BingAerial = OpenLayers.Class(OpenLayers.Layer.Bing, {
    tile_base: '//t{S}.ssl.ak.dynamic.tiles.virtualearth.net/comp/ch/${id}?mkt=en-US&it=A,G,L&src=t&og=969&n=z',

    setMap: function() {
        OpenLayers.Layer.Bing.prototype.setMap.apply(this, arguments);
        this.map.events.register("moveend", this, this.updateAttribution);
    },

    updateAttribution: function() {
        var z = this.map.getZoom() + this.zoomOffset;
        var year = (new Date()).getFullYear();
        var copyrights = '&copy; ' + year + ' <a href="https://www.bing.com/maps/">Microsoft</a>, HERE, ';
        if (z >= 13) {
            copyrights += 'Maxar, CNES Distribution Airbus DS';
        } else {
            copyrights += 'Earthstar Geographics SIO';
        }
        var logo = '<a href="https://www.bing.com/maps/"><img border=0 src="//dev.virtualearth.net/Branding/logo_powered_by.png"></a>';
        this._updateAttribution(copyrights, logo);
    },

    CLASS_NAME: "OpenLayers.Layer.BingAerial"
});

fixmystreet.layer_options = [
  { map_type: OpenLayers.Layer.Bing },
  { map_type: OpenLayers.Layer.BingAerial }
];
