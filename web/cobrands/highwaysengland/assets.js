(function(){

if (!fixmystreet.maps) {
    return;
}

function is_motorway(f) { return f && f.attributes && f.attributes.ROA_NUMBER && f.attributes.ROA_NUMBER.indexOf('M') > -1; }
function is_a_road(f) { return !is_motorway(f); }

var rule_motorway = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({ type: OpenLayers.Filter.Function, evaluate: is_motorway }),
    symbolizer: { strokeColor: "#0079C1" }
});
var rule_a_road = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({ type: OpenLayers.Filter.Function, evaluate: is_a_road }),
    symbolizer: { strokeColor: "#00703C" }
});

var highways_style = new OpenLayers.Style({ fill: false, strokeOpacity: 0.8, strokeWidth: 4 });
highways_style.addRules([rule_motorway, rule_a_road]);
var highways_stylemap = new OpenLayers.StyleMap({ 'default': highways_style });

var defaults = {
    wfs_url: "https://tilma.mysociety.org/mapserver/highways",
    // this covers zoomed right out on Cumbrian sections of the M6
    max_resolution: 40,
    min_resolution: 0.0001,
    srsName: "EPSG:3857",
    body: 'National Highways'
};

fixmystreet.assets.add(defaults, {
    wfs_feature: "Highways",
    stylemap: highways_stylemap,
    always_visible: true,

    non_interactive: true,
    road: true,
    usrn: [
        {
            field: 'road_name',
            attribute: 'ROA_NUMBER'
        },
        {
            field: 'area_name',
            attribute: 'area_name'
        },
        {
            field: 'sect_label',
            attribute: 'sect_label'
        }
    ],

    // motorways are wide and the lines to define them are narrow so we
    // need a bit more margin for error in finding the nearest to stop
    // clicking in the middle of them being undetected
    nearest_radius: 50,
    asset_type: 'road',
    no_asset_msg_id: '#js-not-he-road',
    no_asset_msgs_class: '.js-roads-he',
    actions: {
        found: function(layer, feature) {
            // If the road is a DBFO road then we want to show the not found message.
            fixmystreet.message_controller.road_found(layer, feature, function(feature) {
                if (feature.attributes.area_name.indexOf('DBFO') === -1) {
                    $('#js-top-message').show();
                    $('.js-reporting-page--category').removeClass('hidden-js');
                    return true;
                } else {
                    $('#js-top-message').hide();
                    $('.js-reporting-page--category').addClass('hidden-js');
                    return false;
                }
            }, '#js-dbfo-road');
            change_header('maintenance');
        },
        not_found: function(layer) {
            fixmystreet.message_controller.road_not_found(layer);
            $('#js-top-message').hide();
            $('.js-reporting-page--category').addClass('hidden-js');
            change_header('maintenance');
        }
    }
});

fixmystreet.assets.add(defaults, {
    wfs_url: "https://tilma.mysociety.org/mapserver/highways?litter",
    wfs_feature: "Highways_litter_pick",
    stylemap: highways_stylemap,
    always_visible: true,
    non_interactive: true,
    road: true,
    nearest_radius: 50,
    asset_type: 'road',
    no_asset_msg_id: '#js-not-litter-pick-road',
    no_asset_msgs_class: '.js-roads-he',
    actions: {
        found: function(layer, feature) {
            if ( $("#js-dbfo-road").is(":hidden") && ( !$('.js-mobile-not-an-asset').length || $('.js-mobile-not-an-asset').is(':hidden')) ) {
                fixmystreet.message_controller.road_found(layer, feature, function(feature) {
                    $('#js-top-message').show();
                    $('.js-reporting-page--category').removeClass('hidden-js');
                    return true;
                });
            }
            change_header('maintenance');
        },
        not_found: function(layer) {
            if (fixmystreet.assets.layers[0].selected_feature) {
                var road_number = fixmystreet.assets.layers[0].selected_feature.attributes.ROA_NUMBER;
                if ( $('#js-not-he-road').is(':hidden') && ( !$('.js-mobile-not-an-asset').length || $('.js-mobile-not-an-asset').is(':hidden')) ) {
                    var selected = fixmystreet.reporting.selectedCategory();
                    if ((selected.category === 'Flytipping (NH)' || selected.group === 'Litter') && (road_number && !road_number.match(/^(M|A\d+M)/)) ) {
                        fixmystreet.message_controller.road_not_found(layer);
                        $('#js-top-message').hide();
                        $('.js-reporting-page--category').addClass('hidden-js');
                        change_header('litter');
                    } else {
                        $('.js-reporting-page--category').removeClass('hidden-js');
                        change_header('maintenance');
                    }
                }
            }
        }
    }
});

function change_header(header) {
    if (header === 'maintenance') {
        $('#he_maintenance_heading').show();
        $('#he_litter_heading').hide();
    } else if (header === 'litter') {
        $('#he_maintenance_heading').hide();
        $('#he_litter_heading').show();
    }
}

})();


OpenLayers.Layer.Highways = OpenLayers.Class(OpenLayers.Layer.XYZ, {
    name: 'Highways',
    url: [
        "//tilma.mysociety.org/highways/${z}/${x}/${y}.png",
        "//a.tilma.mysociety.org/highways/${z}/${x}/${y}.png",
        "//b.tilma.mysociety.org/highways/${z}/${x}/${y}.png",
        "//c.tilma.mysociety.org/highways/${z}/${x}/${y}.png"
    ],
    sphericalMercator: true,
    isBaseLayer: false,
    CLASS_NAME: "OpenLayers.Layer.Highways"
});

$(function() {
    if (!fixmystreet.map) {
        return;
    }

    // Can't use vector layer on reports, too big, use tiles instead
    var layer;
    if (fixmystreet.page === 'reports') {
        layer = new OpenLayers.Layer.Highways(null, null, { className: 'olLayerHighways' });
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
