// Functionality required by all OpenLayers WMTS base maps

fixmystreet.maps.setup_wmts_base_map = function() {
    fixmystreet.map_type = OpenLayers.Layer.WMTS;

    // Set DPI - default is 72
    OpenLayers.DOTS_PER_INCH = fixmystreet.wmts_config.tile_dpi;

    fixmystreet.map_options = {
        maxExtent: this.layer_bounds,
        units: 'm',
        scales: fixmystreet.wmts_config.scales
    };

    fixmystreet.layer_options = [];
    $.each(fixmystreet.wmts_config.layer_names, function(i, v) {
        fixmystreet.layer_options.push({
            projection: new OpenLayers.Projection(fixmystreet.wmts_config.map_projection),
            name: v,
            layer: v,
            formatSuffix: fixmystreet.wmts_config.tile_suffix.replace(".", ""),
            matrixSet: fixmystreet.wmts_config.matrix_set,
            requestEncoding: "REST",
            url: fixmystreet.wmts_config.tile_urls[i],
            style: fixmystreet.wmts_config.layer_style,
            matrixIds: fixmystreet.maps.matrix_ids,
            scales: fixmystreet.wmts_config.scales,
            tileOrigin: new OpenLayers.LonLat(fixmystreet.wmts_config.origin_x, fixmystreet.wmts_config.origin_y)
        });
    });
};
