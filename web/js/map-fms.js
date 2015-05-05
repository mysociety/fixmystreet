var fms_tile_base = [ [ '', 'a-', 'b-', 'c-' ], '//{S}tilma.mysociety.org/sv' ];

function set_map_config(perm) {
    _set_map_config();

    if (fixmystreet.map_type) {
        fms_tile_base = fixmystreet.map_type;
    }
    fixmystreet.map_type = OpenLayers.Layer.BingUK;
}

OpenLayers.Layer.BingUK = OpenLayers.Class(OpenLayers.Layer.Bing, {
    uk_bounds: [
        new OpenLayers.Bounds(-6.6, 49.8, 1.102680, 51),
        new OpenLayers.Bounds(-5.4, 51, 2.28, 54.94),
        new OpenLayers.Bounds(-5.85, 54.94, -1.15, 55.33),
        new OpenLayers.Bounds(-9.35, 55.33, -0.7, 60.98)
    ],

    in_uk: function(c) {
        c = c.clone();
        c.transform(
            fixmystreet.map.getProjectionObject(),
            new OpenLayers.Projection("EPSG:4326")
        );
        if ( this.uk_bounds[0].contains(c.lon, c.lat) || this.uk_bounds[1].contains(c.lon, c.lat) || this.uk_bounds[2].contains(c.lon, c.lat) || this.uk_bounds[3].contains(c.lon, c.lat) ) {
            return true;
        }
        return false;
    },

    setMap: function() {
        OpenLayers.Layer.Bing.prototype.setMap.apply(this, arguments);
        this.map.events.register("moveend", this, this.updateAttribution);
    },

    updateAttribution: function() {
        var z = this.map.getZoom() + this.zoomOffset;
        var copyrights;
        var logo = '';
        var c = this.map.getCenter();
        var in_uk = c ? this.in_uk(c) : true;
        if (z >= 16 && in_uk) {
            copyrights = 'Contains Ordnance Survey data &copy; Crown copyright and database right 2014';
        } else {
            logo = '<a href="https://www.bing.com/maps/"><img border=0 src="//dev.virtualearth.net/Branding/logo_powered_by.png"></a>';
            copyrights = '&copy; 2011 <a href="https://www.bing.com/maps/">Microsoft</a>. &copy; AND, Navteq, Ordnance Survey';
        }
        this._updateAttribution(copyrights, logo);
    },

    get_urls: function(bounds, z) {
        var urls;
        var in_uk = this.in_uk(bounds.getCenterLonLat());
        if (z >= 16 && in_uk) {
            urls = [];
            for (var i=0; i< fms_tile_base[0].length; i++) {
                urls.push( fms_tile_base[1].replace('{S}', fms_tile_base[0][i]) + "/${z}/${x}/${y}.png" );
            }
        } else {
            var type = '';
            if (z > 10 && in_uk) {
                type = '&productSet=mmOS&key=' + fixmystreet.key;
            }
            urls = [
                "//ecn.t0.tiles.virtualearth.net/tiles/r${id}.png?g=3467" + type,
                "//ecn.t1.tiles.virtualearth.net/tiles/r${id}.png?g=3467" + type,
                "//ecn.t2.tiles.virtualearth.net/tiles/r${id}.png?g=3467" + type,
                "//ecn.t3.tiles.virtualearth.net/tiles/r${id}.png?g=3467" + type
            ];
        }
        return urls;
    },

    CLASS_NAME: "OpenLayers.Layer.BingUK"
});
