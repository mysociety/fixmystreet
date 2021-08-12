(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.mysociety.org/mapserver/tfl",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};
if (fixmystreet.cobrand === 'tfl') {
    // On .com we change the categories depending on where is clicked; on the
    // cobrand we use the standard 'Please click on a road' message which needs
    // the body to be set so is_only_body passes.
    defaults.body = 'TfL';
}

// This is required so that the found/not found actions are fired on category
// select and pin move rather than just on asset select/not select.
OpenLayers.Layer.TfLVectorAsset = OpenLayers.Class(OpenLayers.Layer.VectorAsset, {
    initialize: function(name, options) {
        OpenLayers.Layer.VectorAsset.prototype.initialize.apply(this, arguments);
        $(fixmystreet).on('maps:update_pin', this.checkSelected.bind(this));
        $(fixmystreet).on('report_new:category_change', this.checkSelected.bind(this));
    },

    CLASS_NAME: 'OpenLayers.Layer.TfLVectorAsset'
});

/* Point asset layers, bus stops and traffic lights. */

var asset_defaults = $.extend(true, {}, defaults, {
    class: OpenLayers.Layer.TfLVectorAsset,
    body: 'TfL',
    select_action: true,
    actions: {
        asset_found: function(asset) {
            fixmystreet.message_controller.asset_found.call(this, asset);
            fixmystreet.assets.named_select_action_found.call(this, asset);
        },
        asset_not_found: function() {
            fixmystreet.message_controller.asset_not_found.call(this);
            fixmystreet.assets.named_select_action_not_found.call(this);
        }
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
        shelter_id: 'SHELTER_ID',
    },
    asset_group: "Bus Stops and Shelters",
    asset_item: 'bus stop'
});

fixmystreet.assets.add(asset_defaults, {
    http_options: { params: { TYPENAME: "busstations" } },
    asset_id_field: 'Name',
    feature_code: 'Name',
    attributes: { station_name: 'Name' },
    asset_group: "Bus Stations",
    asset_item: 'bus station'
});

/* Roadworks asset layer */

var rw_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillOpacity: 1,
        fillColor: "#FFFF00",
        strokeColor: "#000000",
        strokeOpacity: 0.8,
        strokeWidth: 2,
        pointRadius: 6,
        graphicWidth: 39,
        graphicHeight: 25,
        graphicOpacity: 1,
        externalGraphic: '/cobrands/tfl/warning@2x.png'
    }),
    'hover': new OpenLayers.Style({
        fillColor: "#55BB00",
        externalGraphic: '/cobrands/tfl/warning-green@2x.png'
    }),
    'select': new OpenLayers.Style({
        fillColor: "#55BB00",
        externalGraphic: '/cobrands/tfl/warning-green@2x.png'
    })
});

function to_ddmmyyyy(date) {
    date = date.toISOString();
    date = date.slice(8, 10) + '/' + date.slice(5, 7) + '/' + date.slice(0, 4);
    return date;
}

fixmystreet.assets.add(asset_defaults, {
    http_options: {
        url: "https://tilma.mysociety.org/streetmanager.php",
        params: {
            points: 1,
            end_date: new Date().toISOString().slice(0, 10)
        }
    },
    srsName: "EPSG:27700",
    format_class: OpenLayers.Format.GeoJSON,
    name: "Roadworks",
    non_interactive: false,
    always_visible: false,
    road: false,
    all_categories: false,
    asset_category: "Roadworks",
    stylemap: rw_stylemap,
    asset_id_field: 'work_ref',
    asset_item: 'roadworks',
    attributes: {
        promoter_works_ref: 'work_ref',
        start: function() {
            return to_ddmmyyyy(new Date(this.attributes.start_date));
        },
        end: function() {
            return to_ddmmyyyy(new Date(this.attributes.end_date));
        },
        promoter: 'promoter',
        works_desc: 'description',
        works_state: 'status',
        tooltip: 'summary'
    },
    filter_key: true,
    filter_value: function(feature) {
        var red_routes = fixmystreet.map.getLayersByName("Red Routes");
        if (!red_routes.length) {
            return false;
        }
        red_routes = red_routes[0];

        var point = feature.geometry;
        var relevant = !!red_routes.getFeatureAtPoint(point);
        if (!relevant) {
            var nearest = red_routes.getFeaturesWithinDistance(point, 10);
            relevant = nearest.length > 0;
        }
        return relevant;
    },
    select_action: true,
    actions: {
        asset_found: function(feature) {
            this.fixmystreet.actions.asset_not_found.call(this);
            feature.layer = this;
            var attr = feature.attributes,
                start = to_ddmmyyyy(new Date(attr.start_date)),
                end = to_ddmmyyyy(new Date(attr.end_date)),
                summary = attr.summary,
                desc = attr.description;

            var $msg = $('<div class="js-roadworks-message js-roadworks-message-' + this.id + ' box-warning"></div>');
            var $dl = $("<dl></dl>").appendTo($msg);
            if (attr.promoter) {
                $dl.append("<dt>Responsibility</dt>");
                $dl.append($("<dd></dd>").text(attr.promoter));
            }
            $dl.append("<dt>Summary</dt>");
            $dl.append($("<dd></dd>").text(summary));
            if (desc) {
                $dl.append("<dt>Description</dt>");
                $dl.append($("<dd></dd>").text(desc));
            }
            $dl.append("<dt>Dates</dt>");
            var $dates = $("<dd></dd>").appendTo($dl);
            $dates.text(start + " until " + end);
            $msg.prependTo('#js-post-category-messages');
        },
        asset_not_found: function() {
            $(".js-roadworks-message-" + this.id).remove();
        }
    }

});

/* Red routes (TLRN) asset layer & handling for disabling form when red route
   is not selected for specific categories.
   This comes after the point assets so that any asset is deselected by the
   time the check for the red-route only categories is run.
 */

var tlrn_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillColor: "#ff0000",
        fillOpacity: 0.3,
        strokeColor: "#ff0000",
        strokeOpacity: 1,
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
    "Drain Cover - Missing or Damaged",
    "Fallen Tree",
    "Flooding",
    "Graffiti / Flyposting (non-offensive)",
    "Graffiti / Flyposting (offensive)",
    "Graffiti / Flyposting on street light (non-offensive)",
    "Graffiti / Flyposting on street light (offensive)",
    "Grass Cutting and Hedges",
    "Hoardings blocking carriageway or footway",
    "Light on during daylight hours",
    "Lights out in Pedestrian Subway",
    "Low hanging branches",
    "Manhole Cover - Damaged (rocking or noisy)",
    "Manhole Cover - Missing",
    "Mobile Crane Operation",
    "Other (TfL)",
    "Pavement Defect (uneven surface / cracked paving slab)",
    "Pavement Overcrowding",
    "Pothole",
    "Pothole (minor)",
    "Roadworks",
    "Scaffolding blocking carriageway or footway",
    "Single Light out (street light)",
    "Standing water",
    "Street Light - Equipment damaged, pole leaning",
    "Streetspace Feedback",
    "Unstable hoardings",
    "Unstable scaffolding",
    "Worn out road markings"
];

function is_tlrn_category_only(category, bodies) {
    return OpenLayers.Util.indexOf(tlrn_categories, category) > -1 &&
        OpenLayers.Util.indexOf(bodies, 'TfL') > -1 &&
        bodies.length <= 1;
}

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
    always_visible: true,
    all_categories: true,
    nearest_radius: 0.1,
    stylemap: tlrn_stylemap,
    no_asset_msg_id: '#js-not-tfl-road',
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: function(layer) {
            // Only care about this on TfL cobrand
            if (fixmystreet.cobrand !== 'tfl') {
                return;
            }
            var category = fixmystreet.reporting.selectedCategory().category;
            if (is_tlrn_category_only(category, fixmystreet.bodies)) {
                fixmystreet.message_controller.road_not_found(layer);
            } else {
                fixmystreet.message_controller.road_found(layer);
            }
        }
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

})();
