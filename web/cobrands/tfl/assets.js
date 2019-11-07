(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.staging.mysociety.org/mapserver/tfl",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    body: "TfL"
};

var asset_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    no_asset_msg_id: '#js-not-an-asset',
    actions: {
        asset_found: fixmystreet.message_controller.asset_found,
        asset_not_found: fixmystreet.message_controller.asset_not_found
    }
});

fixmystreet.assets.add(asset_defaults, {
    http_options: {
        params: {
            TYPENAME: "trafficsignals"
        }
    },
    asset_id_field: 'Site',
    attributes: {
        site: 'Site',
    },
    asset_group: "Traffic Lights",
    asset_item: 'traffic signal'
});

fixmystreet.assets.add(asset_defaults, {
    http_options: {
        params: {
            TYPENAME: "busstops"
        }
    },
    asset_id_field: 'STOP_CODE',
    attributes: {
        stop_code: 'STOP_CODE',
    },
    asset_group: "Bus Stops and Shelters",
    asset_item: 'bus stop'
});


/* Red routes (TLRN) asset layer & handling for disabling form when red route
   is not selected for specific categories. */

var tlrn_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillColor: "#ff0000",
        fillOpacity: 0.3,
        strokeColor: "#ff0000",
        strokeOpacity: 0.6,
        strokeWidth: 2
    })
});


/* Reports in these categories can only be made on a red route */
var tlrn_categories = [
    "All out - three or more street lights in a row",
    "Blocked drain",
    "Damage - general (Trees)",
    "Dead animal in the carriageway or footway",
    "Debris in the carriageway",
    "Fallen Tree",
    "Flooding",
    "Flytipping",
    "Graffiti / Flyposting (non-offensive)",
    "Graffiti / Flyposting (offensive)",
    "Graffiti / Flyposting on street light (non-offensive)",
    "Graffiti / Flyposting on street light (offensive)",
    "Grass Cutting and Hedges",
    "Hoardings blocking carriageway or footway",
    "Light on during daylight hours",
    "Lights out in Pedestrian Subway",
    "Low hanging branches and general maintenance",
    "Manhole Cover - Damaged (rocking or noisy)",
    "Manhole Cover - Missing",
    "Mobile Crane Operation",
    "Pavement Defect (uneven surface / cracked paving slab)",
    "Pothole",
    "Roadworks",
    "Scaffolding blocking carriageway or footway",
    "Single Light out (street light)",
    "Standing water",
    "Unstable hoardings",
    "Unstable scaffolding",
    "Worn out road markings"
];

var red_routes_layer = fixmystreet.assets.add(defaults, {
    http_options: {
        url: "https://tilma.mysociety.org/mapserver/tfl",
        params: {
            TYPENAME: "RedRoutes"
        }
    },
    name: "Red Routes",
    max_resolution: 9.554628534317017,
    road: true,
    non_interactive: true,
    asset_category: tlrn_categories,
    nearest_radius: 0.1,
    stylemap: tlrn_stylemap,
    no_asset_msg_id: '#js-not-tfl-road',
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: fixmystreet.message_controller.road_not_found
    }
});
if (red_routes_layer) {
    red_routes_layer.events.register( 'loadend', red_routes_layer, function(){
        // The roadworks layer may have finished loading before this layer, so
        // ensure the filters to only show markers that intersect with a red route
        // are re-applied.
        var roadworks = fixmystreet.map.getLayersByName("Roadworks");
        if (roadworks.length) {
            // .redraw() reapplies filters without issuing any new requests
            roadworks[0].redraw();
        }
    });
}


/* Roadworks.org asset layer */

var org_id = '1250';
var body = "TfL";

var rw_stylemap = new OpenLayers.StyleMap({
    'default': fixmystreet.assets.style_default,
    'select': fixmystreet.assets.style_default_select,
    'hover': new OpenLayers.Style({
        fillColor: "#55BB00",
        fillOpacity: 0.8,
        strokeColor: "#000000",
        strokeOpacity: 1,
        strokeWidth: 2,
        pointRadius: 8,
        cursor: 'pointer'
    })
});

OpenLayers.Format.TfLRoadworksOrg = OpenLayers.Class(OpenLayers.Format.RoadworksOrg, {
    endMonths: 0,
    convertToPoints: true,
    CLASS_NAME: "OpenLayers.Format.TfLRoadworksOrg"
});

fixmystreet.assets.add(fixmystreet.roadworks.layer_future, {
    http_options: {
        params: { organisation_id: org_id },
    },
    name: "Roadworks",
    format_class: OpenLayers.Format.TfLRoadworksOrg,
    body: body,
    non_interactive: false,
    always_visible: false,
    road: false,
    all_categories: false,
    actions: null,
    asset_category: "Roadworks",
    stylemap: rw_stylemap,
    asset_id_field: 'promoter_works_ref',
    asset_item: 'roadworks',
    attributes: {
        promoter_works_ref: 'promoter_works_ref',
        start: 'start',
        end: 'end',
        promoter: 'promoter',
        works_desc: 'works_desc',
        works_state: function(feature) {
            return {
                1: "1", // Haven't seen this in the wild yet
                2: "Advanced planning",
                3: "Planned work about to start",
                4: "Work in progress"
            }[this.attributes.works_state] || this.attributes.works_state;
        },
        tooltip: 'tooltip'
    },
    filter_key: true,
    filter_value: function(feature) {
        var red_routes = fixmystreet.map.getLayersByName("Red Routes");
        if (!red_routes.length) {
            return false;
        }
        red_routes = red_routes[0];
        return red_routes.getFeaturesWithinDistance(feature.geometry, 10).length > 0;
    }
});


})();
