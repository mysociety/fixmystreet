(function(){

if (!fixmystreet.maps) {
    return;
}

var canal_style = new OpenLayers.Style({ fill: false, strokeOpacity: 0.8, strokeWidth: 4, strokeColor: '#0079C1' });
var canal_stylemap = new OpenLayers.StyleMap({ 'default': canal_style });

var defaults = {
    wfs_url: "https://tilma.staging.mysociety.org/mapserver/crt",
    // this covers zoomed right out on Cumbrian sections of the M6
    max_resolution: 40,
    min_resolution: 0.0001,
    srsName: "EPSG:3857",
    body: 'Canal & River Trust'
};

fixmystreet.assets.add(defaults, {
    wfs_feature: "Canals",
    stylemap: canal_stylemap,
    always_visible: true,
    non_interactive: true,
    road: true,
    usrn: [
    ],

    // canals are wide and the lines to define them are narrow so we
    // need a bit more margin for error in finding the nearest to stop
    // clicking in the middle of them being undetected
    nearest_radius: 20,
    asset_type: 'canal',
    no_asset_message: '<strong>Not maintained by us</strong> <p>The selected location is not maintained by us. Please follow this link to <a class="js-update-coordinates" href="https://www.fixmystreet.com/">FixMyStreet</a> to continue reporting your issue.',
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: fixmystreet.message_controller.road_not_found
    }
});

// Adjust based upon which base layer is being used
var grid = OpenLayers.Layer.BNG ? 'osmaps' : 'GoogleMapsCompatible';
var base = 'https://tilma.staging.mysociety.org/mapcache/gmaps/crt@' + grid + '/${z}/${x}/${y}.png';
var parent_class = OpenLayers.Layer.BNG || OpenLayers.Layer.XYZ;
OpenLayers.Layer.Canals = OpenLayers.Class(parent_class, {
    name: 'Canals',
    url: [ base ],
    isBaseLayer: false,
    sphericalMercator: OpenLayers.Layer.BNG ? false : true,
    className: 'olLayerCanal',
    options: {
        className: true
    },
    CLASS_NAME: "OpenLayers.Layer.Canals"
});

})();

$(function() {
    if (!fixmystreet.map) {
        return;
    }

    // Can't use vector layer on reports, too big, use tiles instead
    var layer;
    if (fixmystreet.page === 'reports') {
        layer = new OpenLayers.Layer.Canals();
        fixmystreet.map.addLayer(layer);
        layer.setVisibility(true);

        var qs = OpenLayers.Util.getParameters(fixmystreet.original.href);
        if (!qs.bbox && !qs.lat && !qs.lon) {
            var strategy = fixmystreet.markers.strategies[0];
            strategy.deactivate();
            var bounds = new OpenLayers.Bounds(-176879, 6786045, -46630, 7067639);
            var center = bounds.getCenterLonLat();
            var z = fixmystreet.map.getZoomForExtent(bounds);
            fixmystreet.map.setCenter(center, z);
            // Reactivate the strategy and make it think it's done an update
            strategy.activate();
            if (strategy instanceof OpenLayers.Strategy.BBOX) {
                strategy.calculateBounds();
                strategy.resolution = fixmystreet.map.getResolution();
            }
        }
    } else if (fixmystreet.page === 'report') {
        layer = fixmystreet.assets.layers[0];
        fixmystreet.map.addLayer(layer);
    }

    var pins_layer = fixmystreet.map.getLayersByName("Pins")[0];
    if (layer && pins_layer) {
        layer.setZIndex(pins_layer.getZIndex()-1);
    }
});
