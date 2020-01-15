if (window.Heatmap) {
    // We do want heatmap page to run on load... Bit cheeky
    OpenLayers.Strategy.FixMyStreetNoLoad = OpenLayers.Strategy.FixMyStreet;
    OpenLayers.Strategy.FixMyStreetHeatmap = OpenLayers.Class(OpenLayers.Strategy.FixMyStreet, {
        // Same as update, but doesn't check layer visibility (as running when markers invisible)
        update: function(options) {
            var mapBounds = this.getMapBounds();
            if (mapBounds !== null && ((options && options.force) ||
              (this.layer.calculateInRange() && this.invalidBounds(mapBounds)))) {
                this.calculateBounds(mapBounds);
                this.resolution = this.layer.map.getResolution();
                this.triggerRead(options);
            }
        },
        CLASS_NAME: 'OpenLayers.Strategy.FixMyStreetHeatmap'
    });
}

fixmystreet.protocol_params.wards = 'wards';
fixmystreet.protocol_params.start_date = 'start_date';
fixmystreet.protocol_params.end_date = 'end_date';
fixmystreet.protocol_params.body = 'body';

$(function(){
    if (!window.Heatmap) {
        return;
    }

    var heatmap_on = $('input[name=heatmap]:checked').val() === 'Yes';

    var heat_layer = new Heatmap.Layer("Heatmap");
    heat_layer.setOpacity(0.7);
    heat_layer.setVisibility(false);

    var s = new OpenLayers.Strategy.FixMyStreetHeatmap();
    s.setLayer(heat_layer);
    s.activate();
    // Now it's listening on heat layer, set it to update markers layer
    s.layer = fixmystreet.markers;

    function create_heat_layer() {
        heat_layer.points = [];
        for (var i = 0; i < fixmystreet.markers.features.length; i++) {
            var m = fixmystreet.markers.features[i];
            var ll = new OpenLayers.LonLat(m.geometry.x, m.geometry.y);
            heat_layer.addSource(new Heatmap.Source(ll));
        }
        heat_layer.redraw();
    }

    fixmystreet.markers.events.register('loadend', null, create_heat_layer);
    create_heat_layer();
    fixmystreet.map.addLayer(heat_layer);

    $('#heatmap_yes').on('click', function() {
        fixmystreet.markers.setVisibility(false);
        heat_layer.setVisibility(true);
        $(fixmystreet.map.div).addClass("heatmap-active");
    });

    $('#heatmap_no').on('click', function() {
        $(fixmystreet.map.div).removeClass("heatmap-active");
        heat_layer.setVisibility(false);
        fixmystreet.markers.setVisibility(true);
    });

    if (heatmap_on) {
        fixmystreet.markers.setVisibility(false);
        heat_layer.setVisibility(true);
        $(fixmystreet.map.div).addClass("heatmap-active");
    }

    $('#sort').closest('.report-list-filters').hide();

    $("#wards, #start_date, #end_date").on("change.filters", debounce(function() {
        // If the category or status has changed we need to re-fetch map markers
        fixmystreet.markers.events.triggerEvent("refresh", {force: true});
    }, 1000));
    $("#filter_categories, #statuses").on("change.filters", debounce(function() {
        if (!fixmystreet.markers.getVisibility()) {
            // If not visible, still want to trigger change for heatmap
            fixmystreet.markers.events.triggerEvent("refresh", {force: true});
        }
    }, 1000));

});
