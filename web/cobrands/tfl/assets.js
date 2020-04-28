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

/* Red routes (TLRN) asset layer & handling for disabling form when red route
   is not selected for specific categories. */

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
    "Low hanging branches and general maintenance",
    "Manhole Cover - Damaged (rocking or noisy)",
    "Manhole Cover - Missing",
    "Mobile Crane Operation",
    "Other (TfL)",
    "Pavement Defect (uneven surface / cracked paving slab)",
    "Pothole",
    "Pothole (minor)",
    "Roadworks",
    "Scaffolding blocking carriageway or footway",
    "Single Light out (street light)",
    "Standing water",
    "Street Light - Equipment damaged, pole leaning",
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
            var category = $('#form_category').val();
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

/* Point asset layers, bus stops and traffic lights. This comes after the red
 * route so its check for asset not clicked on happens after whether red route
 * clicked on or not */

var asset_defaults = $.extend(true, {}, defaults, {
    class: OpenLayers.Layer.TfLVectorAsset,
    body: 'TfL',
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
        shelter_id: 'SHELTER_ID',
    },
    asset_group: "Bus Stops and Shelters",
    asset_item: 'bus stop'
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

fixmystreet.assets.add(asset_defaults, {
    http_options: {
        params: {
            TYPENAME: "roadworks"
        }
    },
    name: "Roadworks",
    non_interactive: false,
    always_visible: false,
    road: false,
    all_categories: false,
    asset_category: "Roadworks",
    stylemap: rw_stylemap,
    asset_id_field: 'works_ref',
    asset_item: 'roadworks',
    attributes: {
        promoter_works_ref: 'works_ref',
        start: 'start',
        end: 'end',
        promoter: 'promoter',
        works_desc: 'description',
        works_state: 'status',
        tooltip: 'location'
    },
    filter_key: true,
    filter_value: function(feature) {
        var red_routes = fixmystreet.map.getLayersByName("Red Routes");
        if (!red_routes.length) {
            return false;
        }
        red_routes = red_routes[0];
        return red_routes.getFeaturesWithinDistance(feature.geometry, 10).length > 0;
    },
    select_action: true,
    actions: {
        asset_found: function(feature) {
            this.fixmystreet.actions.asset_not_found.call(this);
            feature.layer = this;
            var attr = feature.attributes,
            location = attr.location.replace(/\\n/g, '\n'),
            desc = attr.description.replace(/\\n/g, '\n');

            var $msg = $('<div class="js-roadworks-message js-roadworks-message-' + this.id + ' box-warning"></div>');
            var $dl = $("<dl></dl>").appendTo($msg);
            if (attr.promoter) {
                $dl.append("<dt>Responsibility</dt>");
                $dl.append($("<dd></dd>").text(attr.promoter));
            }
            $dl.append("<dt>Location</dt>");
            var $summary = $("<dd></dd>").appendTo($dl);
            location.split("\n").forEach(function(para) {
                if (para.match(/^(\d{2}\s+\w{3}\s+(\d{2}:\d{2}\s+)?\d{4}( - )?){2}/)) {
                    // skip showing the date again
                    return;
                }
                if (para.match(/^delays/)) {
                    // skip showing traffic delay information
                    return;
                }
                $summary.append(para).append("<br />");
            });
            if (desc) {
                $dl.append("<dt>Description</dt>");
                $dl.append($("<dd></dd>").text(desc));
            }
            $dl.append("<dt>Dates</dt>");
            var $dates = $("<dd></dd>").appendTo($dl);
            $dates.text(attr.start + " until " + attr.end);
            $msg.prependTo('#js-post-category-messages');
            $('#js-post-category-messages .category_meta_message').hide();
        },
        asset_not_found: function() {
            $(".js-roadworks-message-" + this.id).remove();
            $('#js-post-category-messages .category_meta_message').show();
        }
    }

});

})();
