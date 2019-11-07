(function(){

OpenLayers.Protocol.Alloy = OpenLayers.Class(OpenLayers.Protocol.HTTP, {
    currentRequests: [],

    tileSize: 512,
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
        var tileCoordX = Math.floor(xFromOrigin / this.tileSize);
        var tileCoordY = Math.floor(yFromOrigin / this.tileSize) * -1;

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
    // allow sub classes to override the remote projection for converting the geometry
    // of the features
    getRemoteProjection: function() {
        return this.layer.projection;
    },
    merge: function(resp) {
        this.count++;
        // This if/else clause lifted from OpenLayers.Strategy.BBOX
        if (resp.success()) {
            var features = resp.features;
            if(features && features.length > 0) {
                var remote = this.getRemoteProjection();
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

/* for Alloy V2 */
OpenLayers.Format.Alloy = OpenLayers.Class(OpenLayers.Format.GeoJSON, {
    read: function(json, type, filter) {
        var results = null;
        var obj = null;
        if (typeof json == "string") {
            obj = OpenLayers.Format.JSON.prototype.read.apply(this, [json, filter]);
        } else {
            obj = json;
        }

        if(!obj) {
            OpenLayers.Console.error("Bad JSON: " + json);
        } else {
            results = [];
            for(var i=0, len=obj.results.length; i<len; ++i) {
                try {
                    results.push(this.parseFeature(obj.results[i]));
                } catch(err) {
                    results = null;
                    OpenLayers.Console.error(err);
                }
            }
        }
        return results;
    }
});

OpenLayers.Protocol.AlloyV2 = OpenLayers.Class(OpenLayers.Protocol.Alloy, {
    tileSize: 128,
    getURL: function(coords, options) {
        return OpenLayers.String.format(options.base, {'layerid': options.layerid, 'styleid': options.styleid, 'z': 17, 'x': coords[0], 'y': coords[1]});
    }
});

OpenLayers.Strategy.AlloyV2 = OpenLayers.Class(OpenLayers.Strategy.Alloy, {
    initialize: function(name, options) {
        this.remote = new OpenLayers.Projection("EPSG:4326");
        OpenLayers.Strategy.Alloy.prototype.initialize.apply(this, arguments);
    },
    // the layer uses EPSG:3857 for generating the tile location but the features
    // use EPSG:4326
    getRemoteProjection: function() {
        return this.remote;
    }
});

fixmystreet.alloyv2_defaults = {
    http_options: {
      base: "https://tilma.staging.mysociety.org/resource-proxy/proxy.php?https://northants.assets/${layerid}/${x}/${y}/${z}/cluster?styleIds=${styleid}"
    },
    format_class: OpenLayers.Format.Alloy,
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.AlloyV2
};
})();
