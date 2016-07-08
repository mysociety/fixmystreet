// Functionality required by all OpenLayers WMTS base maps

function setup_wmts_base_map() {
    fixmystreet.map_type = OpenLayers.Layer.WMTS;

    // Set DPI - default is 72
    OpenLayers.DOTS_PER_INCH = fixmystreet.wmts_config.tile_dpi;

    fixmystreet.map_options = {
        maxExtent: layer_bounds,
        units: 'm',
        scales: fixmystreet.wmts_config.scales
    };

    fixmystreet.layer_options = [];
    fixmystreet.wmts_config.layer_names.forEach(function(v, i) {
        fixmystreet.layer_options.push({
            projection: new OpenLayers.Projection(fixmystreet.wmts_config.map_projection),
            name: fixmystreet.wmts_config.layer_names[i],
            layer: fixmystreet.wmts_config.layer_names[i],
            formatSuffix: fixmystreet.wmts_config.tile_suffix.replace(".", ""),
            matrixSet: fixmystreet.wmts_config.matrix_set,
            requestEncoding: "REST",
            url: fixmystreet.wmts_config.tile_urls[i],
            style: fixmystreet.wmts_config.layer_style,
            matrixIds: matrix_ids,
            tileOrigin: new OpenLayers.LonLat(fixmystreet.wmts_config.origin_x, fixmystreet.wmts_config.origin_y)
        });
    });

    // Give main code a new bbox_strategy that translates between
    // lat/lon and our WMTS layer's coordinates
    fixmystreet.bbox_strategy = new OpenLayers.Strategy.ReprojectBBOX({
        ratio: 1
    });
}

OpenLayers.Strategy.ReprojectBBOX = OpenLayers.Class(OpenLayers.Strategy.BBOX, {
    getMapBounds: function() {
        // Get the map bounds but return them in lat/lon, not
        // local coordinates
        if (this.layer.map === null) {
            return null;
        }

        var localBounds = this.layer.map.getExtent();
        // Transform bound corners into WGS84
        localBounds.transform( new OpenLayers.Projection(fixmystreet.wmts_config.map_projection), new OpenLayers.Projection("EPSG:4326") );
        return localBounds;
    },

    CLASS_NAME: "OpenLayers.Strategy.ReprojectBBOX"
});


// 