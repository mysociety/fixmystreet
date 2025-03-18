/*
 * This map layer uses OSM in Northern Ireland, our own tile server for
 * Great Britain zoom levels 16/17+, and the OS Maps API otherwise
 */

fixmystreet.maps.tile_base = 'https://{S}tilma.mysociety.org/oml';

OpenLayers.Layer.FixMyStreet = OpenLayers.Class(OpenLayers.Layer.OSM.Mapnik, {
    gb_bounds: [
        new OpenLayers.Bounds(-6.6, 49.8, 1.102680, 51),
        new OpenLayers.Bounds(-5.4, 51, 2.28, 54.94),
        new OpenLayers.Bounds(-5.85, 54.94, -1.15, 55.33),
        new OpenLayers.Bounds(-9.35, 55.33, -0.7, 60.98)
    ],

    in_gb: function(c) {
        c = c.clone();
        c.transform(
            fixmystreet.map.getProjectionObject(),
            new OpenLayers.Projection("EPSG:4326")
        );
        if ( this.gb_bounds[0].contains(c.lon, c.lat) || this.gb_bounds[1].contains(c.lon, c.lat) || this.gb_bounds[2].contains(c.lon, c.lat) || this.gb_bounds[3].contains(c.lon, c.lat) ) {
            return true;
        }
        return false;
    },

    setMap: function() {
        OpenLayers.Layer.OSM.Mapnik.prototype.setMap.apply(this, arguments);
        this.map.events.register("moveend", this, this.updateAttribution);
    },

    updateAttribution: function() {
        var z = this.map.getZoom() + this.zoomOffset;
        var copyrights;
        var logo = '';
        var c = this.map.getCenter();
        var in_gb = c ? this.in_gb(c) : true;
        var year = (new Date()).getFullYear();
        if (in_gb) {
            copyrights = '<div class="os-api-branding copyright">Contains National Highways and OS data<br>&copy; Crown copyright and database rights ' + year;
            if (fixmystreet.os_licence) {
                copyrights += " " + fixmystreet.os_licence;
            }
            copyrights += '</div>';
            logo = '<div class="os-api-branding logo"></div>';
        } else {
            copyrights = '<div class="os-api-branding copyright">&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors</div>';
        }
        this.attribution = logo + copyrights;
        if (this.map) {
            this.map.events.triggerEvent("changelayer", {
                layer: this,
                property: "attribution"
            });
        }
    },

    tile_prefix: [ '', 'a-', 'b-', 'c-' ],

    getURL: function (bounds) {
        var xyz = this.getXYZ(bounds);
        var in_gb = this.in_gb(bounds.getCenterLonLat());

        var url = this.url;
        if (!fixmystreet.os_premium && xyz.z >= fixmystreet.os_oml_zoom_switch && in_gb) {
            url = [];
            for (i=0; i< this.tile_prefix.length; i++) {
                url.push( fixmystreet.maps.tile_base.replace('{S}', this.tile_prefix[i]) + "/${z}/${x}/${y}.png" );
            }
        } else if (in_gb) {
            url = fixmystreet.os_url.replace('%s', fixmystreet.os_layer) + "/${z}/${x}/${y}.png";
            if (fixmystreet.os_key) {
                url += "?key=" + fixmystreet.os_key;
            }
        }

        if (OpenLayers.Util.isArray(url)) {
            var s = '' + xyz.x + xyz.y + xyz.z;
            url = this.selectUrl(s, url);
        }
        return OpenLayers.String.format(url, xyz);
    },

    CLASS_NAME: "OpenLayers.Layer.FixMyStreet"
});

fixmystreet.layer_options = [
  { map_type: OpenLayers.Layer.FixMyStreet },
  { map_type: OpenLayers.Layer.BingAerial }
];
