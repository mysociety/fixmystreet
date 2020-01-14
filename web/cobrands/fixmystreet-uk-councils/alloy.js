(function(){

OpenLayers.Protocol.Alloy = OpenLayers.Class(OpenLayers.Protocol.HTTP, {
    currentRequests: [],

    abort: function() {
        if (this.currentRequests.length) {
            for (var j = 0; j < this.currentRequests.length; j++) {
                this.currentRequests[j].priv.abort();
            }
            this.currentRequests = [];
        }
    },

    read: function(options) {
        OpenLayers.Protocol.prototype.read.apply(this, arguments);
        options = options || {};
        options.params = OpenLayers.Util.applyDefaults(
            options.params, this.options.params);
        options = OpenLayers.Util.applyDefaults(options, this.options);
        var all_tiles = this.getTileRange(options.scope.bounds, options.scope.layer.maxExtent, options.scope.layer.map);
        var rresp;
        var max = all_tiles.length;
        options.scope.newRequest(max);
        for (var i = 0; i < max; i++) {
            var resp = new OpenLayers.Protocol.Response({requestType: "read"});
            var url = this.getURL(all_tiles[i], options);
            resp.priv = OpenLayers.Request.GET({
                url: url, //options.url,
                callback: this.createCallback(this.handleRead, resp, options),
                params: options.params,
                headers: options.headers
            });
            this.currentRequests.push(resp);
            rresp = resp;
        }
        return rresp;
    },

    getURL: function(coords, options) {
        return OpenLayers.String.format(options.base, {'layerid': options.layerid, 'environment': options.environment, 'layerVersion': options.layerVersion, 'z': 15, 'x': coords[0], 'y': coords[1]});
    },

    getTileRange: function(bounds, maxExtent, map) {
        var min = this.getTileCoord([bounds.left, bounds.top], maxExtent, map, true);
        var max = this.getTileCoord([bounds.right, bounds.bottom], maxExtent, map, false);
        var coords = [];
        for (var i = min[0], ii = max[0]; i <= ii; ++i) {
          for (var j = min[1], jj = max[1]; j <= jj; ++j) {
              coords.push([i,j]);
          }
        }
        return coords;
    },

    getTileCoord: function(bounds, maxExtent, map, reverse) {
        var origin = new OpenLayers.LonLat(maxExtent.left, maxExtent.top);
        // hard code this number as we want to avoid fetching asset groups
        // which happens at more zoomed out levels
        var resolution = 2.388657133579254;

        var adjustX = reverse ? 0.5 : 0;
        var adjustY = reverse ? 0 : 0.5;
        var xFromOrigin = Math.floor((bounds[0] - origin.lon) / resolution + adjustX);
        var yFromOrigin = Math.floor((bounds[1] - origin.lat) / resolution + adjustY);
        var tileCoordX = Math.floor(xFromOrigin / 512);
        var tileCoordY = Math.floor(yFromOrigin / 512) * -1;

        if (reverse) {
            tileCoordX -= 1;
            tileCoordY -= 1;
        }

        return [ tileCoordX, tileCoordY ];
    }
});

OpenLayers.Strategy.Alloy = OpenLayers.Class(OpenLayers.Strategy.FixMyStreet, {
    count: 0,
    max: 0,
    requestStart: 0,
    initialize: function(name, options) {
        OpenLayers.Strategy.FixMyStreet.prototype.initialize.apply(this, arguments);
    },
    newRequest: function(max) {
      this.max = max;
      this.count = 0;
      this.failCount = 0;
      this.layer.destroyFeatures();
    },
    merge: function(resp) {
        this.count++;
        // This if/else clause lifted from OpenLayers.Strategy.BBOX
        if (resp.success()) {
            var features = resp.features;
            if(features && features.length > 0) {
                var remote = this.layer.projection;
                var local = this.layer.map.getProjectionObject();
                if(!local.equals(remote)) {
                    var geom;
                    for(var i=0, len=features.length; i<len; ++i) {
                        geom = features[i].geometry;
                        if(geom) {
                            geom.transform(remote, local);
                        }
                    }
                }
                this.layer.addFeatures(features);
            }
        } else {
            this.failCount++;
            if (this.failCount >= this.max) {
                this.bounds = null;
            }
        }
        // only fire loadend things if we've got all the tiles
        if (this.count == this.max) {
            if ( this.layer.checkFeature ) {
                this.layer.checkFeature(null, fixmystreet.get_lonlat_from_dom());
            }
            this.layer.events.triggerEvent("loadend", {response: resp});
        }
    },

});

fixmystreet.alloy_defaults = {
    http_options: {
      base: "https://alloy-api-tile01.yotta.co.uk/api/render-layer/tile/${layerid}/${environment}/${layerVersion}/${z}/${x}/${y}",
    },
    format_class: OpenLayers.Format.GeoJSON,
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.Alloy
};

})();
