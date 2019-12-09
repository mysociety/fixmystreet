// Functionality required by all OpenLayers WMS base maps

fixmystreet.maps.setup_wms_base_map = function() {
    fixmystreet.map_type = OpenLayers.Layer.WMS;

    fixmystreet.map_options = {
        maxExtent: this.layer_bounds,
        units: 'm'
    };

    fixmystreet.layer_options = [];
    $.each(fixmystreet.wms_config.layer_names, function(i, v) {
        fixmystreet.layer_options.push(OpenLayers.Util.extend({
            projection: new OpenLayers.Projection(fixmystreet.wms_config.map_projection),
            name: v,
            layer: v,
            url: fixmystreet.wms_config.tile_urls[i]
        }, fixmystreet.wms_config));
    });
};
