(function(){

if (!fixmystreet.maps) {
    return;
}

function create_rule(fn, style) {
    var opts = {
        filter: new OpenLayers.Filter.FeatureId({
            type: OpenLayers.Filter.Function,
            evaluate: fn
        })
    };
    if (style) {
        opts.symbolizer = style;
    }
    return new OpenLayers.Rule(opts);
}

function test_layer_typename(f, body, type) {
    return f && f.body == body && f.http_options && f.http_options.params && f.http_options.params.TYPENAME == type;
}

// ArcGIS wants to receive the bounding box as a 'geometry' parameter, not 'bbox'
var arcgis_format = new OpenLayers.Format.QueryStringFilter();
OpenLayers.Protocol.ArcgisHTTP = OpenLayers.Class(OpenLayers.Protocol.HTTP, {
    filterToParams: function(filter, params) {
        params = arcgis_format.write(filter, params);
        params.geometry = params.bbox;
        delete params.bbox;
        return params;
    },
    CLASS_NAME: "OpenLayers.Protocol.ArcgisHTTP"
});

/* Bath & NE Somerset */

fixmystreet.assets.banes = {};
fixmystreet.assets.banes.park_asset_details = function() {
    var a = this.attributes;
    return a.description + " " + a.assetid;
};

/* Street lights are included/styled according to their owner. */

var banes_ownernames = [
    "B&NES CAR PARKS",
    "B&NES PARKS",
    "B&NES PROPERTY",
    "B&NES HIGHWAYS"
];

// Some are excluded from the map entirely
var banes_exclude_ownernames = [
    "EXCEPTIONS"
];

function banes_include_feature(f) {
    return f &&
           f.attributes &&
           f.attributes.ownername &&
           OpenLayers.Util.indexOf(banes_exclude_ownernames, f.attributes.ownername) == -1;
}

function banes_owns_feature(f) {
    return f &&
           f.attributes &&
           f.attributes.ownername &&
           OpenLayers.Util.indexOf(banes_ownernames, f.attributes.ownername) > -1 &&
           banes_include_feature(f);
}

function banes_does_not_own_feature(f) {
    return !banes_owns_feature(f) &&
           banes_include_feature(f);
}

var banes_lighting_default_style = new OpenLayers.Style({
    fillColor: "#868686",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.6,
    strokeWidth: 2,
    pointRadius: 4,
    title: '${unitdescription} ${unitno}\r\nNot owned by B&NES. Owned by ${ownername}.'
});

var banes_rule_owned = create_rule(banes_owns_feature, {
    fillColor: "#FFFF00",
    pointRadius: 6,
    title: '${unitdescription} ${unitno}',
});
var banes_rule_not_owned = create_rule(banes_does_not_own_feature);

banes_lighting_default_style.addRules([banes_rule_owned, banes_rule_not_owned]);

fixmystreet.assets.banes.lighting_stylemap = new OpenLayers.StyleMap({
    'default': banes_lighting_default_style,
    'select': fixmystreet.assets.style_default_select,
    'hover': new OpenLayers.Style({
        pointRadius: 8,
        cursor: 'pointer'
    })
});

fixmystreet.assets.banes.lighting_asset_details = function() {
    var a = this.attributes;
    return "street: " + a.street + "\n" +
           "owner: " + a.ownername + "\n" +
           "unitno: " + a.unitno + "\n" +
           "lamp: " + a.lamp + "\n" +
           "lampclass: " + a.lampclass + "\n" +
           "description: " + a.unitdescription;
};

var banes_on_road;

fixmystreet.assets.banes.road_actions = {
    found: function(layer) {
        fixmystreet.message_controller.road_found(layer);
        banes_on_road = true;
    },
    not_found: function(layer) {
        var cat = fixmystreet.reporting.selectedCategory().category;
        var asset_item = layer.fixmystreet.cat_map[cat];
        if (asset_item) {
            layer.fixmystreet.asset_item = asset_item;
            fixmystreet.message_controller.road_not_found(layer);
        } else {
            fixmystreet.message_controller.road_found(layer);
        }
        banes_on_road = false;
    }
};

// List of categories which are Curo Group's responsibility
var curo_categories = [
    'Allotment issue',
    'Dead animals',
    'Dog fouling',
    'Excessive or dangerous littering',
    'Litter bin damaged',
    'Litter bin full',
    'Needles',
    'Obstructive vegetation',
    'Play area safety issue',
    'Trees and woodland'
];

fixmystreet.assets.banes.curo_found = function(layer) {
    var category = fixmystreet.reporting.selectedCategory().category;
    if (curo_categories.indexOf(category) === -1 || banes_on_road) {
        fixmystreet.message_controller.road_found(layer);
        return;
    }

    fixmystreet.message_controller.road_not_found(layer);

    var domain = 'curo-group.co.uk';
    var email = 'estates@' + domain;
    var email_string = $(layer.fixmystreet.no_asset_msg_id).find('.js-roads-asset');
    if (email_string) {
        email_string.html('<a href="mailto:' + email + '">' + email + '</a>');
    }
};
fixmystreet.assets.banes.curo_not_found = function(layer) {
    fixmystreet.message_controller.road_found(layer);
};

/* Bexley */

fixmystreet.assets.bexley = {};
fixmystreet.assets.bexley.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${Unit_No}")
});

/* Brent */

fixmystreet.assets.brent = {};

// The label for street light markers should be everything after the final
// '-' in the feature's unit_id attribute.
var brent_select_style = fixmystreet.assets.construct_named_select_style("${unit_id}");
brent_select_style.createLiterals = function() {
    var literals = Object.getPrototypeOf(this).createLiterals.apply(this, arguments);
    if (literals.label && literals.label.split) {
        literals.label = literals.label.split("-").slice(-1)[0];
    }
    return literals;
};

fixmystreet.assets.brent.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': brent_select_style
});

fixmystreet.assets.brent.construct_asset_name = function(id) {
    if (id.split) {
        var code = id.split("-").slice(-1)[0];
        return {id: code, name: 'street light'};
    }
};

fixmystreet.assets.brent.found = function(layer) {
    fixmystreet.message_controller.road_found(layer);
};

fixmystreet.assets.brent.not_found = function(layer) {
    fixmystreet.message_controller.road_not_found(layer, function() {return true;});
};

fixmystreet.assets.brent.road_found = function(layer) {
    fixmystreet.message_controller.road_found(layer);
};

fixmystreet.assets.brent.road_not_found = function(layer) {
    if (brent_on_red_route()) {
        fixmystreet.message_controller.road_found(layer);
    } else {
        fixmystreet.message_controller.road_not_found(layer);
    }
};

function brent_on_red_route() {
    var red_routes = fixmystreet.map.getLayersByName("Red Routes");
    if (!red_routes.length) {
        return false;
    }
    red_routes = red_routes[0];
    return !!red_routes.selected_feature;
}

fixmystreet.assets.brent.cemetery_actions = {
    found: function(layer) {
        var currentCategory = fixmystreet.reporting.selectedCategory().category;
        if (!fixmystreet.reporting_data || currentCategory === '') {
            // Skip checks until category has been selected.
            fixmystreet.message_controller.road_found(layer);
            return;
        }
        var category = fixmystreet.reporting_data.by_category[currentCategory];

        // If this category is non-TfL then disable reporting.
        if (category.bodies.indexOf('TfL') === -1) {
            // Need to pass a criterion function to force the not found message to be shown.
            fixmystreet.message_controller.road_not_found(layer, function() { return true; });
        } else {
            fixmystreet.message_controller.road_found(layer);
        }
    },
    not_found: function(layer) {
        fixmystreet.message_controller.road_found(layer);
    }
};

/* Bristol */

fixmystreet.assets.bristol = {};
fixmystreet.assets.bristol.park_stylemap = new OpenLayers.StyleMap({
    default: new OpenLayers.Style({
        fill: true,
        fillColor: "#1be547",
        fillOpacity: "0.25"
    })
});

fixmystreet.assets.bristol.road_property_found = function(layer) {
    var roads = fixmystreet.map.getLayersByName('bristol_roads')[0];
    fixmystreet.message_controller.road_found(roads);
};

fixmystreet.assets.bristol.road_property_not_found = function(layer) {
    var roads = fixmystreet.map.getLayersByName('bristol_roads')[0];
    var property = fixmystreet.map.getLayersByName('bristol_property')[0];
    if (!roads.selected_feature && !property.selected_feature && !fixmystreet.staff_set_up) {
        fixmystreet.message_controller.road_not_found(roads, function() {return true;});
    }
};

fixmystreet.assets.bristol.gullies_construct_selected_asset_message = function(asset) {
    if (!asset.attributes.TAGS) {
        return '';
    }
    return '<div class="box-warning"><strong>This gully will be cleansed as part of our annual programme. Once this has been scheduled we’ll change this report to closed.</strong></div>';
};

/* Bromley */

fixmystreet.assets.bromley = {};
fixmystreet.assets.bromley.parks_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillColor: "#C3D9A2",
        fillOpacity: 0.6,
        strokeWidth: 2,
        strokeColor: '#90A66F'
    })
});
fixmystreet.assets.bromley.prow_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        fillOpacity: 0,
        strokeColor: "#660099",
        strokeOpacity: 0.5,
        strokeWidth: 6
    })
});

fixmystreet.assets.bromley.found = function(layer) {
    fixmystreet.message_controller.road_not_found(layer, function() {return true;});
};

fixmystreet.assets.bromley.not_found = function(layer) {
    fixmystreet.message_controller.road_found(layer);
};

fixmystreet.assets.bromley.set_asset_owner = function() {
    $('#form_fms_layer_owner').val('bromley');
};

fixmystreet.assets.bromley.unset_asset_owner = function() {
    $('#form_fms_layer_owner').val('');
};

fixmystreet.assets.bromley.remove_park_message = function(layer) {
    delete layer.map_messaging.asset;
};

fixmystreet.assets.bromley.add_park_message = function(layer) {
    layer.fixmystreet.asset_message_immediate = true;
    layer.map_messaging.asset = layer.fixmystreet.no_asset_message;
};

/* Buckinghamshire */

fixmystreet.assets.buckinghamshire = {};

// Since the move to Alloy street light features are suffixed with road name
// in the title attribute. We don't want to display this so we strip it.
// Title is of the form "XX111,STREET NAME" e.g. "LC004,MARKET SQUARE" -
// we only want the "LC004" bit.
OpenLayers.Layer.BuckinghamshireLights = OpenLayers.Class(OpenLayers.Layer.VectorAssetMove, {
    preFeatureInsert: function(feature) {
        if (feature.attributes.title && feature.attributes.title.split) {
            feature.attributes.title = feature.attributes.title.split(",")[0];
        }
    },
    CLASS_NAME: 'OpenLayers.Layer.BuckinghamshireLights'
});

fixmystreet.assets.buckinghamshire.prow_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        strokeColor: "#790d8a",
        strokeOpacity: 0.8,
        strokeWidth: 4
    })
});

fixmystreet.assets.buckinghamshire.prow_selected = function(asset) {
    var type = asset.attributes.InfraTypeGroupDescr;
    if (type === 'Other') {
        type = asset.attributes.InfraTypeDescr.replace('Other/', '');
        if (type === 'Undefined') {
            type = '';
        }
    }
    var id = asset.attributes.InfraCode;
    return 'You have selected ' + type + ' <b>' + id + '</b>';
};

fixmystreet.assets.buckinghamshire.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${title}")
});

// The "whole street asset" layer indicates who is responsible for maintaining
// a road via the 'feature_ty' attribute on features.
// These are roads that Bucks maintain.
var bucks_types = [
    "2", // HW: STRATEGIC ROUTE
    "3A", // HW: MAIN DISTRIBUTOR
    "3B", // HW: SECONDARY DISTRIBUTOR
    "4A", // HW: LINK ROAD
    "4B", // HW: LOCAL ACCESS ROAD
    "9", // HW: NO CARRIAGEWAY
    "98", // HW: METALLED PUBLIC FOOTPATH
    "99"  // HW: METALLED PUBLIC BRIDLEWAY
];
// And these are roads they don't maintain.
var non_bucks_types = [
    "HE", // HW: HIGHWAYS ENGLAND
    "HWOA", // OTHER AUTHORITY
    "HWSA", // HW: Whole Street Asset
    "P", // HW: PRIVATE
];

// We show roads that Bucks are and aren't responsible for, and display a
// message to the user if they click something Bucks don't maintain.
fixmystreet.assets.buckinghamshire.types_to_show = bucks_types.concat(non_bucks_types);

// Some road types we don't want to display at all.
var bucks_types_to_hide = [
    "11", // HW: BYWAY OPEN TO TRAFFIC
    "12", // HW: FOOTPATH PROW
    "13", // HW: BYWAY RESTRICTED
    "14", // HW: BRIDLEWAY
    "9", // HW: NO CARRIAGEWAY
];

var bucks_highways_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#5555FF",
    strokeOpacity: 0.1,
    strokeWidth: 7
});

function bucks_owns_feature(f) {
    return f &&
           f.attributes &&
           f.attributes.feature_ty &&
           OpenLayers.Util.indexOf(bucks_types, f.attributes.feature_ty) > -1;
}

function bucks_does_not_own_feature(f) {
    return !bucks_owns_feature(f);
}

var bucks_rule_owned = create_rule(bucks_owns_feature);
var bucks_rule_not_owned = create_rule(bucks_does_not_own_feature, { strokeColor: "#555555" });
bucks_highways_style.addRules([bucks_rule_owned, bucks_rule_not_owned]);

fixmystreet.assets.buckinghamshire.street_stylemap = new OpenLayers.StyleMap({
    'default': bucks_highways_style
});

$(fixmystreet).on('report_new:highways_change', function() {
    if (fixmystreet.body_overrides.get_only_send() === 'National Highways') {
        $('#bucks_dangerous_msg').hide();
    } else {
        $('#bucks_dangerous_msg').show();
    }
});

var bucks_streetlight_code_to_type = {
  'LC': 'street light',
  'S': 'sign',
  'BB': 'belisha beacon',
  'B': 'bollard',
  'BS': 'traffic signal',
  'VMS': 'sign',
  'RB': 'bollard',
  'CPS': 'sign',
  'SF': 'sign'
};

fixmystreet.assets.buckinghamshire.labeled_construct_asset_name = function(id) {
    var code = id.replace(/[O0-9]+[A-Z]*/g, '');
    return {id: id, name: bucks_streetlight_code_to_type[code] || 'street light'};
};

fixmystreet.assets.buckinghamshire.streetlight_construct_selected_asset_message = function(asset) {
    var id = asset.attributes[this.fixmystreet.feature_code] || '';
    if (id === '') {
        return;
    }
    var data = this.fixmystreet.construct_asset_name(id);
    var extra = '. Only ITEMs maintained by Buckinghamshire Highways are displayed.';
    extra = extra.replace(/ITEM/g, data.name);
    return 'You have selected ' + data.name + ' <b>' + data.id + '</b>' + extra;
};
fixmystreet.assets.buckinghamshire.streetlight_asset_found = function(asset) {
    fixmystreet.message_controller.asset_found.call(this, asset);
    fixmystreet.assets.named_select_action_found.call(this, asset);
};
fixmystreet.assets.buckinghamshire.streetlight_asset_not_found = function() {
    fixmystreet.message_controller.asset_not_found.call(this);
    fixmystreet.assets.named_select_action_not_found.call(this);
};

// When the auto-asset selection of a layer occurs, the data for inspections
// may not have loaded. So make sure we poke for a check when the data comes
// in.
function bucks_inspection_layer_loadend() {
    var type = 'junctions';
    var layer = fixmystreet.assets.layers.filter(function(elem) {
        return test_layer_typename(elem.fixmystreet, "Buckinghamshire Council", type);
    });
    layer[0].checkSelected();
}

function bucks_format_date(date_field) {
    var regExDate = /([0-9]{4})-([0-9]{2})-([0-9]{2})/;
    var myMatch = regExDate.exec(date_field);
    if (myMatch) {
        return myMatch[3] + '/' + myMatch[2] + '/' + myMatch[1];
    } else {
        return '';
    }
}

if (fixmystreet.cobrand == 'buckinghamshire' || fixmystreet.cobrand == 'fixmystreet') {
    $(function(){
        var layer = fixmystreet.map.getLayersByName('Bucks Junction Inspections')[0];
        if (layer) {
            layer.events.register( 'loadend', layer, bucks_inspection_layer_loadend);
        }
    });
}

fixmystreet.assets.buckinghamshire.drains_construct_selected_asset_message = function(asset) {
    if (!asset.attributes.last_cleaned_date) {
        return '';
    }
    return 'This gulley was last cleaned on ' + bucks_format_date(asset.attributes.last_cleaned_date);
};

fixmystreet.assets.buckinghamshire.street_found = function(layer, feature) {
    var map = {
        "HE": '#js-not-council-road-he',
        "HWOA": '#js-not-council-road-other'
    };
    var msg_id = map[feature.attributes.feature_ty] || '#js-not-council-road';
    fixmystreet.message_controller.road_found(layer, feature, function(feature) {
        if (OpenLayers.Util.indexOf(bucks_types, feature.attributes.feature_ty) != -1) {
            return true;
        }
        return false;
    }, msg_id);
};
fixmystreet.assets.buckinghamshire.street_not_found = function(layer) {
    fixmystreet.message_controller.road_not_found(layer, function() {
        var selected = fixmystreet.reporting.selectedCategory();
        if (selected.group == 'Grass, hedges and weeds') {
            // Want to always show the road not found message.
            // This skips the is_only_body check in road_not_found
            return true;
        }
        return false;
    });
};

fixmystreet.assets.buckinghamshire.winter_found = function() {
    var $div = $(".js-reporting-page.js-gritting-notice");
    if ($div.length) {
        $div.removeClass('js-reporting-page--skip');
    } else {
        var msg = "<div class='box-warning js-gritting-notice'>" +
                    "<h1>Winter Gritting</h1>" +
                    "<p>The road you have selected is on a regular " +
                    "gritting route, and will be gritted according " +
                    "to the published " +
                    "<a href='https://www.buckinghamshire.gov.uk/parking-roads-and-transport/check-to-see-which-roads-are-gritted/'>" +
                    "policy</a>.</p>" +
                    "</div>";
        $div = $(msg);
        fixmystreet.pageController.addNextPage('gritting', $div);
    }
};
fixmystreet.assets.buckinghamshire.winter_not_found = function() {
    $('.js-reporting-page.js-gritting-notice').addClass('js-reporting-page--skip');
};

fixmystreet.assets.buckinghamshire.car_parks_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillColor: "#BBB",
        fillOpacity: 0.5,
        strokeWidth: 2,
        strokeColor: '#666666'
    })
});

// The maximum speed for reports to be sent to the parish council.
var bucks_parish_speed_threshold = 30;

fixmystreet.assets.buckinghamshire.speed_found = function(layer, feature, criterion, msg_id) {
    // Answer speed limit question based on speed limit of the road.
    var $question = $('#form_speed_limit_greater_than_30');
    if (feature.attributes.speed && feature.attributes.speed <= bucks_parish_speed_threshold) {
        $question.val('no');
    } else {
        $question.val('yes');
    }
    // Fire the change event so the council text is updated.
    $question.trigger('change');
};
fixmystreet.assets.buckinghamshire.speed_not_found = function(layer) {
    $('#form_speed_limit_greater_than_30').val('dont_know').trigger('change');
};

/* Camden */

fixmystreet.assets.camden = {};
fixmystreet.assets.camden.housing_estate_actions = {
    // When a housing estate is found we want to prevent reporting,
    // which is why we run the road_not_found function, to display
    // the message.
    found: function(layer) {
        var currentCategory = fixmystreet.reporting.selectedCategory().category;
        if (!fixmystreet.reporting_data || currentCategory === '') {
            // Skip checks until category has been selected.
            fixmystreet.message_controller.road_found(layer);
            return;
        }
        var category = fixmystreet.reporting_data.by_category[currentCategory];

        // If this category is non-TfL then disable reporting.
        if (category.bodies.indexOf('TfL') === -1) {
            // Need to pass a criterion function to force the not found message to be shown.
            fixmystreet.message_controller.road_not_found(layer, function() { return true; });
        } else {
            fixmystreet.message_controller.road_found(layer);
        }
    },
    not_found: function(layer) {
        fixmystreet.message_controller.road_found(layer);
    }
};

// Filter to check for symlink != 0
fixmystreet.assets.camden.filter_column = new OpenLayers.Filter.Comparison({
    type: OpenLayers.Filter.Comparison.NOT_EQUAL_TO,
    property: "symlink",
    value: "0"
});

/* Central Bedfordshire */

fixmystreet.assets.centralbedfordshire = {};
fixmystreet.assets.centralbedfordshire.streetlight_stylemap = new OpenLayers.StyleMap({
    'default': fixmystreet.assets.style_default,
    'hover': fixmystreet.assets.style_default_hover,
    'select': fixmystreet.assets.construct_named_select_style("${lighting_c}")
});

fixmystreet.assets.centralbedfordshire.style_default_green = new OpenLayers.Style({
    fillColor: "#55BB00",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.8,
    strokeWidth: 2,
    pointRadius: 6
});

fixmystreet.assets.centralbedfordshire.tree_stylemap = new OpenLayers.StyleMap({
    'default': fixmystreet.assets.centralbedfordshire.style_default_green,
    'hover': fixmystreet.assets.style_default_hover,
    'select': fixmystreet.assets.style_default_select
});

var centralbeds_types = [
    "CBC",
    "Fw",
];

function cb_should_not_require_road() {
    // Ensure the user can select anywhere on the map if they want to
    // make a report in the "Trees", "Fly Tipping" or "Public Rights of way" categories.
    // This means we don't show the "not found" message if no category/group has yet been selected
    // or if one of the groups containing either the "Trees", "Fly Tipping" or "Public Rights of way"
    // categories has been selected.
    var selected = fixmystreet.reporting.selectedCategory();
    return selected.category === "Trees" ||
            (selected.group === "Grass, Trees, Verges and Weeds" && !selected.category) ||
            selected.category === "Fly Tipping" ||
            (selected.group === "Flytipping, Bins and Graffiti" && !selected.category) ||
            selected.category === 'Housing Fly-tipping' ||
            selected.category === 'Public Rights of way' ||
            (!selected.group && !selected.category);
}

function cb_show_non_stopper_message(layer) {
    // For reports about trees on private roads, Central Beds want the
    // "not our road" message to be shown and also for the report to be
    // able to be made.
    // The existing stopper message code doesn't allow for this situation, so
    // this function is used to show a custom DOM element that contains the
    // message.
    var msg = $("#js-not-council-road").html();
    layer.map_messaging.asset = msg;
}

function cb_hide_non_stopper_message(layer) {
    delete layer.map_messaging.asset;
}

fixmystreet.assets.centralbedfordshire.found = function(layer, feature) {
    fixmystreet.message_controller.road_found(layer, feature, function(feature) {
        cb_hide_non_stopper_message(layer);
        if (OpenLayers.Util.indexOf(centralbeds_types, feature.attributes.adoption) != -1) {
            return true;
        }
        if (cb_should_not_require_road()) {
            cb_show_non_stopper_message(layer);
            return true;
        }
        return false;
    }, "#js-not-council-road");
};
fixmystreet.assets.centralbedfordshire.not_found = function(layer) {
    cb_hide_non_stopper_message(layer);
    if (cb_should_not_require_road()) {
        fixmystreet.message_controller.road_found(layer);
    } else {
        fixmystreet.message_controller.road_not_found(layer);
    }
};

/* Cheshire East */

fixmystreet.assets.cheshireeast = {};
fixmystreet.assets.cheshireeast.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${asset_id}")
});

/* East Sussex */

OpenLayers.Format.EastSussex = OpenLayers.Class(OpenLayers.Format.JSON, {
    read: function(json, type, filter) {
        var obj = json;
        if (typeof json == "string") {
            obj = OpenLayers.Format.JSON.prototype.read.apply(this,
                                                              [json, filter]);
        }

        var results = [];
        for (var i=0, len=obj.length; i<len; i++) {
            var item = obj[i];
            var geom = new OpenLayers.Geometry.Point(item.Mid_Location__c.longitude, item.Mid_Location__c.latitude);
            var vec = new OpenLayers.Feature.Vector(geom, item);
            results.push(vec);
        }

        return results;
    },
    CLASS_NAME: "OpenLayers.Format.EastSussex"
});

OpenLayers.Protocol.EastSussex = OpenLayers.Class(OpenLayers.Protocol.HTTP, {
    read: function(options) {
        OpenLayers.Protocol.prototype.read.apply(this, arguments);
        options = options || {};
        options.params = OpenLayers.Util.applyDefaults(
            options.params, this.options.params);
        options = OpenLayers.Util.applyDefaults(options, this.options);
        var types = options.types.join('&types=');
        var coords = fixmystreet.map.getCenterWGS84();
        options.url = options.url + '?longitude=' + coords.lat + '&latitude=' + coords.lon + '&types=' + types;
        var resp = new OpenLayers.Protocol.Response({requestType: "read"});
        resp.priv = OpenLayers.Request.GET({
            url: options.url,
            callback: this.createCallback(this.handleRead, resp, options),
            params: options.params,
            headers: options.headers
        });
    },
    CLASS_NAME: "OpenLayers.Protocol.EastSussex"
});

// can have multiple group
if (fixmystreet.cobrand == 'fixmystreet') {
    $(function(){
        $("#problem_form").on("change.category", function() {
            var group = '';
            if (OpenLayers.Util.indexOf(fixmystreet.bodies, 'East Sussex County Council') != -1 ) {
              group = fixmystreet.reporting.selectedCategory().group;
            }
            $('#form_group').val(group);
        });
    });
}

fixmystreet.assets.eastsussex = {};
fixmystreet.assets.eastsussex.construct_selected_asset_message = function(asset) {
    var last_clean = asset.attributes.Gully_Last_Clean_Date__c || '';
    var next_clean = asset.attributes.Gully_Next_Clean_Date__c || '';
    if (last_clean !== '' || next_clean !== '') {
        var message = '';
        if (last_clean) { message += '<b>Last Cleaned</b>: ' + last_clean; }
        if (next_clean) { message += ' <b>Next Clean</b>: ' + next_clean; }
        return message;
    }
};

/* Gloucester */

fixmystreet.assets.gloucester = {};

fixmystreet.assets.gloucester.watercourses_filter = function(feature) {
    var maintenanceDuty = feature.attributes.Maintenance_Duty;
    return maintenanceDuty && maintenanceDuty.startsWith('GCiC');
};

fixmystreet.assets.gloucester.street_or_plot_found = function(layer, asset) {
    if (asset.attributes.owner && asset.attributes.owner[0] === '64a8227cebabca0376c5c0dd') {
        var combined = layer.fixmystreet.combined;
        var key_layer = fixmystreet.map.getLayersByName(combined[0])[0];
        var original_no_asset_message = key_layer.fixmystreet.no_asset_message;
        var no_asset_message = "This land is not owned by Gloucester city council.";

        key_layer.fixmystreet.no_asset_message = no_asset_message;
        fixmystreet.message_controller.road_not_found(key_layer, function() { return true; } );
        key_layer.fixmystreet.no_asset_message = original_no_asset_message;
    } else {
        var selected_usrn = layer.selected_feature.attributes.itemId;
        $('input[name="asset_resource_id"]').val(selected_usrn);
        fixmystreet.assets.cobranduk.combined_road_found(layer, asset);
    }
};

fixmystreet.assets.gloucester.street_or_plot_not_found = function(layer) {
    var outcome = fixmystreet.assets.cobranduk.combined_road_not_found(layer);
    if (outcome === 'no') {
        $('input[name="asset_resource_id"]').val('');
    }
};

fixmystreet.assets.cobranduk = {};

/* Gloucester have separate layers for watercourses and ponds which
 * they want to act as a single layer, with selection required.
 * This is similar to other combined layers so this is a generic
 * function requiring the two layer to be combined to have names
 * which are then specified in an array in layer.fixmystreet.combined
 *
 * 1. Don't block when a selection is made in one but not the other.
 * 2. Do block when there isn't a selection in either.
 * 3. Only apply the block to one layer so we don't show the block message twice. */

fixmystreet.assets.cobranduk.combined_road_found = function(layer, asset) {
    var combined = layer.fixmystreet.combined;
    var name = layer.fixmystreet.name;
    if (!combined || !name) {
        console.warn("Layers not set up correctly");
        return;
    } else {
        var key_layer = fixmystreet.map.getLayersByName(combined[0])[0];
        fixmystreet.message_controller.road_found(key_layer);
    }
};

fixmystreet.assets.cobranduk.combined_road_not_found = function(layer) {
    var combined = layer.fixmystreet.combined;
    var name = layer.fixmystreet.name;
    if (!combined || !name) {
        console.warn("Layers not set up correctly");
        return 'error';
    } else {
        var key_layer = fixmystreet.map.getLayersByName(combined[0])[0];
        var secondary_layer = fixmystreet.map.getLayersByName(combined[1])[0];
        if (!key_layer.selected_feature && !secondary_layer.selected_feature) {
            fixmystreet.message_controller.road_not_found(key_layer, function() { return true; });
            return 'no';
        }
        return 'yes';
    }
};

/* Gloucester have separate layers for free and paid car parks which
 * they want to act as a single layer, with selection required.
 * The car_park_found and car_park_not_found functions fire separately for each
 * sub layer so we need to make sure that we:
 * 1. Don't block when a selection is made in one but not the other.
 * 2. Do block when there isn't a selection in either.
 * 3. Only apply the block to one layer so we don't show the block message twice. */

fixmystreet.assets.gloucester.car_park_found = function(layer, asset) {
    var free_car_parks_layer = fixmystreet.map.getLayersByName('free_car_parks')[0];
    fixmystreet.message_controller.road_found(free_car_parks_layer);
};

fixmystreet.assets.gloucester.car_park_not_found = function(layer) {
    var free_car_parks_layer = fixmystreet.map.getLayersByName('free_car_parks')[0];
    var paid_car_parks_layer = fixmystreet.map.getLayersByName('paid_car_parks')[0];
    if (!free_car_parks_layer.selected_feature && !paid_car_parks_layer.selected_feature) {
        fixmystreet.message_controller.road_not_found(free_car_parks_layer, function() { return true; });
    }
};

/* Similar to car parks, Gloucester make use of separate layers for public land
 * and public highways which they want to act as a single public layer with
 * reports in most categories needing to be made within or nearby assets in these.
 * The public_found and public_not_found functions fire separately for each
 * sub layer so we need to make sure that we:
 * 1. Don't block when a selection is made in one but not the other.
 * 2. Do block when there isn't a selection in either.
 * 3. Only apply the block to one layer so we don't show the block message twice. */

fixmystreet.assets.gloucester.public_relevant = function(options) {
    return (options.group || options.category) &&
        options.group != 'Car parks' &&
        options.group != 'Graffiti' &&
        options.group != 'Litter bins' &&
        options.group != 'Playground and park equipment' &&
        options.group != 'Public toilets' &&
        options.group != 'Watercourse' &&
        options.category != 'Dog fouling';
};

fixmystreet.assets.gloucester.public_found = function(layer, asset) {
    var public_land = fixmystreet.map.getLayersByName('public_land')[0];
    fixmystreet.message_controller.road_found(public_land);
};

fixmystreet.assets.gloucester.public_not_found = function(layer) {
    var public_land = fixmystreet.map.getLayersByName('public_land')[0];
    var public_highways = fixmystreet.map.getLayersByName('public_highways')[0];
    if (!public_land.selected_feature && !public_highways.selected_feature) {
        fixmystreet.message_controller.road_not_found(public_land, function() { return true; });
    }
};

/* Gloucestershire */

fixmystreet.assets.gloucestershire = {};

fixmystreet.assets.gloucestershire.street_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        strokeColor: "navy",
        strokeOpacity: 0.5,
        strokeWidth: 8
    })
});

fixmystreet.assets.gloucestershire.traffic_asset_details = function() {
    var a = this.attributes;
    return "Install No: " + a.install_no + "\n" +
        "Equipment type: " + a.equip_type + "\n" +
        "LED/Halogen: " + a.led_halogen;
};

/* Hounslow */

fixmystreet.assets.hounslow = {};

// The label for street light markers should be everything after the final
// '/' in the feature's FeatureId attribute.
// This seems to be the easiest way to perform custom processing
// on style attributes in OpenLayers...
var hounslow_select_style = fixmystreet.assets.construct_named_select_style("${FeatureId}");
hounslow_select_style.createLiterals = function() {
    var literals = Object.getPrototypeOf(this).createLiterals.apply(this, arguments);
    if (literals.label && literals.label.split) {
        literals.label = literals.label.split("/").slice(-1)[0];
    }
    return literals;
};

fixmystreet.assets.hounslow.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': hounslow_select_style
});

fixmystreet.assets.hounslow.construct_asset_name = function(id) {
    if (id.split) {
        var code = id.split("/").slice(-1)[0];
        return {id: code, name: 'column'};
    }
};

/* Isle of Wight */

fixmystreet.assets.isleofwight = {};
fixmystreet.assets.isleofwight.streets_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        strokeColor: "#5555FF",
        strokeOpacity: 0.1,
        strokeWidth: 7
    })
});

fixmystreet.assets.isleofwight.not_found_msg_update = function() {
    $("input[name=asset_details]").val('');
    fixmystreet.assets.named_select_action_not_found.call(this);
};

fixmystreet.assets.isleofwight.found_item = function(asset) {
    fixmystreet.assets.named_select_action_found.call(this, asset);
};

fixmystreet.assets.isleofwight.construct_message = function(asset) {
    var id = asset.attributes.central_asset_id || '';
    if (id !== '') {
        var attrib = asset.attributes;
        var asset_name = attrib.feature_type_name + '; ' + attrib.site_name + '; ' + attrib.feature_location;
        $("input[name=asset_details]").val(asset_name);
        return 'You have selected ' + asset_name;
    }
};

fixmystreet.assets.isleofwight.line_found_item = function(layer, feature) {
    if ( fixmystreet.assets.selectedFeature() ) {
        return;
    }
    fixmystreet.assets.isleofwight.found_item.call(layer, feature);
};
fixmystreet.assets.isleofwight.line_not_found_msg_update = function(layer) {
    if ( fixmystreet.assets.selectedFeature() ) {
        return;
    }
    fixmystreet.assets.isleofwight.not_found_msg_update.call(layer);
};

/* Lincolnshire */

fixmystreet.assets.lincolnshire = {};
fixmystreet.assets.lincolnshire.barrier_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        strokeColor: "#000000",
        strokeOpacity: 0.9,
        strokeWidth: 4
    }),
    'select': new OpenLayers.Style({
        strokeColor: "#55BB00",
        strokeOpacity: 1,
        strokeWidth: 8
    }),
    'hover': new OpenLayers.Style({
        strokeWidth: 6,
        strokeOpacity: 1,
        strokeColor: "#FFFF00",
        cursor: 'pointer'
    })
});
fixmystreet.assets.lincolnshire.llpg_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillOpacity: 0,
        strokeColor: "#000000",
        strokeOpacity: 0.25,
        strokeWidth: 2,
        pointRadius: 10,

        label: "${label}",
        labelOutlineColor: "white",
        labelOutlineWidth: 2,
        fontSize: '11px',
        fontWeight: 'bold'
    })
});

fixmystreet.assets.lincolnshire.grass_found = function(layer) {
    var data = layer.selected_feature.attributes;
    var parish_regex = new RegExp(/Contact Parish/);
    /* If it is handled by LCC and has cut dates provided,
    add an extra notice to the reporting form showing the cut dates */
    if (data.Cut_By.match(/LCC|F0|F1|Flail|STR/) && lincs_has_dates([data.Cut_1, data.Cut_2, data.Cut_3]).length) {
        var $div = $(".js-reporting-page.js-lincs-grass-notice");
        if ($div.length) {
            $div.removeClass('js-reporting-page--skip');
        } else {
            var msg = "<div class='box-warning js-lincs-grass-notice'>" +
                        "<h1>Grass cutting schedule</h1>" +
                        "<p>The grass in this area is scheduled to be cut ";
                        if (data.Cut_3 === 'N/A') {
                            msg = msg + "on <strong>" + lincs_has_dates([data.Cut_1, data.Cut_2, data.Cut_3])[0] + "</strong>";
                        } else {
                            msg = msg + "between <strong>" + lincs_has_dates([data.Cut_1, data.Cut_2, data.Cut_3])[0] + "</strong>";
                        }

            if (data.Cut_By != 'LCC') {
                msg += '<p>In rural areas we cut roads to the first 1.1m width from the edge of the road and leave the rest for wildlife except for areas providing visibility at junctions and bends where a greater width is cut. We also cut a strip either side of footways where possible.</p>';
            }
            msg += "<p>Does this answer your question about grass cutting?</p>";
            $div = $(msg);

            var $button = $("<div><button id='lincs-yes-verge-query' class='btn btn--block'>Yes</button></div>");
            $button.on( "click", function(e) {
                e.preventDefault();
                $('.js-reporting-page--next').prop('disabled', true);
                if (!$('#lincs-thank-you').length) {
                    $div.append('<p id="lincs-thank-you">Thank you for making an enquiry. If you have any other highways faults to report please <a href="/">make another report</a>.</p>');
                }
            });
            $div.append($button);
            // We'll call the 'Continue' button 'No' for this page
            // as clicking 'No' should continue report
            $(fixmystreet).on("report_new:page_change", function(e, $curr, $page) {
                if ($page.hasClass('js-lincs-grass-notice')) {
                    $('.js-reporting-page--next').text('No');
                } else {
                    $('.js-reporting-page--next').prop('disabled', false);
                    $('.js-reporting-page--next').text('Continue');
                }
            });
            fixmystreet.pageController.addNextPage('lincs_grass', $div);
        }
        fixmystreet.body_overrides.only_send('Lincolnshire County Council');
    }
    /* If handled by a district council (LCDC or SKDC) that says contact them,
    send the report to that relevant district council in their Grass Cutting category.
    If handled by LCC (or a district council) but with “Contact LCC” (or similar) as the cut date,
    do nothing and allow reporting to proceed to LCC’s Grass Cutting category.*/
    else if (data.Cut_By === 'DIS') {
        var district_council = {
            'LCDC': 'Lincoln City Council',
            'SKDC': 'South Kesteven District Council'
        };
        var lcc_regex = new RegExp(/Contact LCC/);
        if (district_council[data.Authority] && !lcc_regex.test(data.Cut_1)) {
            fixmystreet.body_overrides.only_send(district_council[data.Authority]);
        } else {
            fixmystreet.body_overrides.only_send('Lincolnshire County Council');
        }
    }
    /* If handled by a parish (with a cut date of “Contact Parish Council” or “Contact Parish to Add”)
    prevent reporting and display a message informing the user which parish council handles the area */
    else if (data.Cut_By === 'PAR' && parish_regex.test(data.Cut_1)) {
        var text = $('#js-lincs-parish-grass').html();
        new_text = text.replace('{{PARISH_COUNCIL}}', data.Authority);
        layer.fixmystreet.no_asset_message = new_text;
        fixmystreet.message_controller.road_found(layer, null, function() { return false; }, '#js-lincs-parish-grass');
    }

    function lincs_has_dates(cut_info) {
        var dates = [];
        if (cut_info[0].match(/Contact /) && cut_info[0] === cut_info[1] && cut_info[1] === cut_info[2]) {
            return dates;
        } else if (cut_info[0] && cut_info[1] && cut_info[2] === 'N/A') {
            var now = new Date();
            for (var i=0; i < cut_info.length; i++) {
                var date_components = cut_info[i].split(' ');
                var date = new Date(now.getFullYear(), months(date_components[1]), date_components[0], '23', '59', '59');
                if (date >= now) {
                    dates.push(cut_info[i]);
                    return dates;
                }
            }
            return dates;
        } else {
            for (var j=0; j < cut_info.length; j++) {
                var date_returned = check_date(cut_info[j]);
                if (date_returned) {
                    dates.push(date_returned);
                }
            }
            return dates;
        }

        function check_date(date) {
            var dates = date.split(" - ");
            if (dates.length === 2) {
                var now = new Date();
                var end_date_components = dates[1].split(' ');
                var end_date = new Date(now.getFullYear(), months(end_date_components[1]), end_date_components[0], '23', '59', '59');
                if (end_date < now) {
                    return 0;
                } else {
                    return date;
                }
            } else {
                return 0;
            }
        }
        function months($day) {
            var months = {
                January: '0',
                February: '1',
                March: '2',
                April: '3',
                May: '4',
                June: '5',
                July: '6',
                August: '7',
                September: '8',
                October: '9',
                November: '10',
                December: '11',
            };
            return months[$day];
        }
    }
};

fixmystreet.assets.lincolnshire.grass_not_found = function(layer) {
    // road_found to remove any stopper messages
    fixmystreet.message_controller.road_found(layer);
    fixmystreet.body_overrides.only_send('Lincolnshire County Council');
};

fixmystreet.assets.lincolnshire.light_found = function(asset) {
    fixmystreet.body_overrides.only_send(asset.layer.fixmystreet.body);
};
fixmystreet.assets.lincolnshire.light_not_found = function() {
    // Default to Lincolnshire if layer is visible
    // (this action fires on the Lincolnshire part of the asset layer)
    if (this.getVisibility()) {
        fixmystreet.body_overrides.only_send(this.fixmystreet.body);
    } else {
        fixmystreet.body_overrides.remove_only_send();
    }
};

/* Merton */

fixmystreet.assets.merton = {};
fixmystreet.assets.merton.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${UnitNumber}")
});

merton_style_default_green = new OpenLayers.Style({
    fillColor: "#55BB00",
    strokeColor: "#000000",
    strokeOpacity: 0.8,
    strokeWidth: 4,
    pointRadius: 12
});

fixmystreet.assets.merton.recyling_stylemap = new OpenLayers.StyleMap({
    'default': merton_style_default_green,
    'hover': fixmystreet.assets.style_default_hover,
    'select': fixmystreet.assets.style_default_select
});
fixmystreet.assets.merton.park_found = function(layer) {
    fixmystreet.body_overrides.only_send(layer.fixmystreet.body);

    var asset = layer.selected_feature;
    if (asset.attributes.Park_Name == 'Morden Hall Park') {
        layer.fixmystreet.no_asset_msg_id = '#js-not-a-park-morden-hall';
        fixmystreet.message_controller.road_not_found(layer, function() { return true; });
    } else if (asset.attributes.Park_Name == 'Mitcham Common') {
        layer.fixmystreet.no_asset_msg_id = '#js-not-a-park-mitcham-common';
        fixmystreet.message_controller.road_not_found(layer, function() { return true; });
    } else if (asset.attributes.Park_Name == 'Wimbledon Common') {
        layer.fixmystreet.no_asset_msg_id = '#js-not-a-park-wimbledon-common';
        fixmystreet.message_controller.road_not_found(layer, function() { return true; });
    } else {
        fixmystreet.message_controller.road_found(layer);
    }
};

fixmystreet.assets.merton.park_not_found = function(layer) {
    fixmystreet.body_overrides.remove_only_send();
    layer.fixmystreet.no_asset_msg_id = '#js-not-a-merton-park';
    fixmystreet.message_controller.road_not_found(layer, function() { return true; });
};

/* Northamptonshire */

fixmystreet.assets.northamptonshire = {};

fixmystreet.assets.northamptonshire.asset_found = function(asset) {
    if (fixmystreet.message_controller.asset_found.call(this)) {
        return;
    }
    var lonlat = asset.geometry.getBounds().getCenterLonLat();
    // Features considered overlapping if within 1M of each other
    // TODO: Should zoom/marker size be considered when determining if markers overlap?
    var overlap_threshold = 1;
    var overlapping_features = this.getFeaturesWithinDistance(
        new OpenLayers.Geometry.Point(lonlat.lon, lonlat.lat),
        overlap_threshold
    );
    if (overlapping_features.length > 1) {
        // TODO: In an ideal world we'd be able to show the user a photo of each
        // of the assets and ask them to pick one.
        // Instead, we tell the user there are multiple things here
        // and ask them to describe the asset in the description field.
        var $p = $("#overlapping_features_msg");
        if (!$p.length) {
            $p = $("<p id='overlapping_features_msg' class='hidden box-warning'>" +
            "There is more than one <span class='overlapping_item_name'></span> at this location. " +
            "Please describe which <span class='overlapping_item_name'></span> has the problem clearly.</p>");
            $('#category_meta').before($p).closest('.js-reporting-page').removeClass('js-reporting-page--skip');
        }
        $p.find(".overlapping_item_name").text(this.fixmystreet.asset_item);
        $p.removeClass('hidden');
    } else {
        $("#overlapping_features_msg").addClass('hidden');
    }
};

fixmystreet.assets.northamptonshire.asset_not_found = function() {
    $("#overlapping_features_msg").addClass('hidden');
    if (this.fixmystreet.snap_threshold === "0") {
        // Not a typo, asset selection is not mandatory
        fixmystreet.message_controller.asset_found.call(this);
    } else {
        fixmystreet.message_controller.asset_not_found.call(this);
    }
};

fixmystreet.assets.northamptonshire.highways_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        strokeColor: "#111111",
        strokeOpacity: 0.1,
        strokeWidth: 7
    })
});

fixmystreet.assets.northamptonshire.prow_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        strokeColor: "#115511",
        strokeOpacity: 0.8,
        strokeWidth: 7
    })
});

var northants_barrier_style = $.extend({
    strokeColor: '#1BE547',
    strokeWidth: 4,
}, fixmystreet.assets.style_default_select.defaultStyle);

fixmystreet.assets.northamptonshire.stylemap_barriers = new OpenLayers.StyleMap({
    'default': fixmystreet.assets.style_default,
    'select': new OpenLayers.Style(northants_barrier_style),
    'hover': fixmystreet.assets.style_default_hover
});

fixmystreet.message_controller.add_ignored_body("Northamptonshire Highways");

/* Northumberland */

fixmystreet.assets.northumberland = {};

var ncc_rightsofway_style = new OpenLayers.Style({
    fill: false,
    fillOpacity: 0,
    strokeColor: "#000000",
    strokeOpacity: 0.8,
    strokeWidth: 5
});

var ncc_rightsofway_rules = [
    create_rule(
        function(f) { return f && f.attributes && f.attributes.type && f.attributes.type === 'Footpath'; },
        { strokeColor: '#FF0000', strokeDashstyle: "dash" }
    ),
    create_rule(
        function(f) { return f && f.attributes && f.attributes.type && f.attributes.type === 'Bridleway'; },
        { strokeColor: '#4CE600', strokeDashstyle: "dash" }
    ),
    create_rule(
        function(f) { return f && f.attributes && f.attributes.type && f.attributes.type === 'Byway Open to All Traffic'; },
        { strokeColor: '#B7814A' }
    ),
    create_rule(
        function(f) { return f && f.attributes && f.attributes.type && f.attributes.type === 'Restricted Byway'; },
        { strokeColor: '#F789D8' }
    )
];
ncc_rightsofway_style.addRules(ncc_rightsofway_rules);

fixmystreet.assets.northumberland.rightsofway_stylemap = new OpenLayers.StyleMap({
    'default': ncc_rightsofway_style,
    'select': fixmystreet.assets.style_default_select,
    'hover': fixmystreet.assets.style_default_hover
});

/* Oxfordshire */

fixmystreet.assets.oxfordshire = {};

var occ_asset_fillColor = fixmystreet.cobrand === "oxfordshire" ? "#007258" : "#FFFF00";

var occ_default = $.extend({}, fixmystreet.assets.style_default.defaultStyle, {
    fillColor: occ_asset_fillColor
});

var occ_hover = new OpenLayers.Style({
    pointRadius: 8,
    cursor: 'pointer'
});

fixmystreet.assets.oxfordshire.stylemap = new OpenLayers.StyleMap({
    'default': occ_default,
    'select': fixmystreet.assets.style_default_select,
    'hover': occ_hover
});

var occ_ownernames = [
    "LocalAuthority", "CountyCouncil", 'ODS'
];

fixmystreet.assets.oxfordshire.owns_feature = function(f) {
    return f &&
           f.attributes &&
           f.attributes.maintained_by &&
           OpenLayers.Util.indexOf(occ_ownernames, f.attributes.maintained_by) > -1;
};

function occ_does_not_own_feature(f) {
    return !fixmystreet.assets.oxfordshire.owns_feature(f);
}

var occ_owned_default_style = new OpenLayers.Style({
    fillColor: "#868686",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.6,
    strokeWidth: 2,
    pointRadius: 4,
    title: 'Not maintained by Oxfordshire County Council. Maintained by ${maintained_by}.'
});

var occ_rule_owned = create_rule(fixmystreet.assets.oxfordshire.owns_feature, {
    fillColor: occ_asset_fillColor,
    pointRadius: 6,
    title: ''
});
var occ_rule_not_owned = create_rule(occ_does_not_own_feature);
occ_owned_default_style.addRules([occ_rule_owned, occ_rule_not_owned]);

fixmystreet.assets.oxfordshire.owned_stylemap = new OpenLayers.StyleMap({
    'default': occ_owned_default_style,
    'select': fixmystreet.assets.style_default_select,
    'hover': occ_hover
});

fixmystreet.assets.oxfordshire.owned_asset_found = function(asset) {
    var is_occ = this.fixmystreet.owns_function(asset);
    if (!is_occ) {
        fixmystreet.message_controller.asset_not_found.call(this);
    } else {
        fixmystreet.message_controller.asset_found.call(this);
    }
};

fixmystreet.assets.oxfordshire.drain_construct_selected_asset_message = function(asset) {
    var junctionInspectionLayer = window.fixmystreet.assets.layers.filter(function(elem) {
        return elem.fixmystreet.body == "Oxfordshire County Council" &&
        elem.fixmystreet.http_options &&
        elem.fixmystreet.http_options.format.featureType == 'junction_inspections';
    });
    var inspection;
    if (junctionInspectionLayer[0]) {
        inspection = junctionInspectionLayer[0].features.filter(function(elem) {
            return elem.attributes.asset_id == asset.attributes.asset_id &&
            occ_format_date(elem.attributes.created) == occ_format_date(asset.attributes.last_inspected);
        });
    }
    var last_clean = '';
    var message = '';
    if (inspection && inspection[0]) {
        if (asset.attributes.last_inspected && (inspection[0].attributes.junction_cleaned === 'true' || inspection[0].attributes.channel_cleaned === 'true')) {
            last_clean = occ_format_date(asset.attributes.last_inspected);
            message = 'This gully was last cleaned on ' + last_clean;
        }
    }
    return message;
};

function occ_format_date(date_field) {
    var regExDate = /([0-9]{4})-([0-9]{2})-([0-9]{2})/;
    var myMatch = regExDate.exec(date_field);
    if (myMatch) {
        return myMatch[3] + '/' + myMatch[2] + '/' + myMatch[1];
    } else {
        return '';
    }
}

// Junction/channel inspection layers (not shown on the map, but used by the layers below)

// When the auto-asset selection of a layer occurs, the data for inspections
// may not have loaded. So make sure we poke for a check when the data comes
// in.
function occ_inspection_layer_loadend() {
    var type = this.fixmystreet.http_options.params.TYPENAME.replace(/_inspections/g, 's');
    var layer = fixmystreet.assets.layers.filter(function(elem) {
        return test_layer_typename(elem.fixmystreet, "Oxfordshire County Council", type);
    });
    layer[0].checkSelected();
}

if (fixmystreet.cobrand == 'oxfordshire' || fixmystreet.cobrand == 'fixmystreet') {
    $(function(){
        var layer;
        layer = fixmystreet.map.getLayersByName('Oxon Drain Inspections')[0];
        if (layer) {
            layer.events.register( 'loadend', layer, occ_inspection_layer_loadend);
        }
    });
}

// Bridges

fixmystreet.assets.oxfordshire.owns_bridge = function(f) {
    return f &&
           f.attributes &&
           f.attributes.MAINTENANCE_AUTHORITY_UID &&
           f.attributes.MAINTENANCE_AUTHORITY_UID == 1;
};

function occ_does_not_own_bridge(f) {
    return !fixmystreet.assets.oxfordshire.owns_bridge(f);
}

var occ_bridge_default_style = new OpenLayers.Style({
    fillColor: "#868686",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.6,
    strokeWidth: 2,
    pointRadius: 4,
    title: 'Not maintained by Oxfordshire County Council.'
});

var occ_rule_bridge_owned = create_rule(fixmystreet.assets.oxfordshire.owns_bridge, {
    fillColor: occ_asset_fillColor,
    pointRadius: 6,
    title: ''
});
var occ_rule_bridge_not_owned = create_rule(occ_does_not_own_bridge);
occ_bridge_default_style.addRules([occ_rule_bridge_owned, occ_rule_bridge_not_owned]);

fixmystreet.assets.oxfordshire.bridge_stylemap = new OpenLayers.StyleMap({
    'default': occ_bridge_default_style,
    'select': fixmystreet.assets.style_default_select,
    'hover': occ_hover
});

// Alloy street lighting

var occ_streetlight_select = $.extend({
    label: "${title}",
    fontColor: "#FFD800",
    labelOutlineColor: "black",
    labelOutlineWidth: 3,
    labelYOffset: 69,
    fontSize: '18px',
    fontWeight: 'bold'
}, fixmystreet.assets.style_default_select.defaultStyle);

function oxfordshire_light(f) {
    return f && f.attributes && !f.attributes.private;
}
function oxfordshire_light_not(f) {
    return !oxfordshire_light(f);
}

var occ_light_default_style = new OpenLayers.Style(occ_default);
var occ_rule_light_owned = create_rule(oxfordshire_light);
var occ_rule_light_not_owned = create_rule(oxfordshire_light_not, {
    fillColor: "#868686",
    strokeWidth: 1,
    pointRadius: 4
});
occ_light_default_style.addRules([ occ_rule_light_owned, occ_rule_light_not_owned ]);

fixmystreet.assets.oxfordshire.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': occ_light_default_style,
  'select': new OpenLayers.Style(occ_streetlight_select),
  'hover': occ_hover
});

fixmystreet.assets.oxfordshire.light_construct_selected_asset_message = function(asset) {
    var out = 'You have selected ';
    out += asset.attributes.unit_type || "street light";
    out += " <b>" + asset.attributes.title + '</b>.';
    if (asset.attributes.private) {
        out += " This private street light asset is not under the responsibility of Oxfordshire County Council and therefore we are unable to accept reports for the asset.";
    }
    return out;
};

fixmystreet.assets.oxfordshire.light_asset_found = function(asset) {
    fixmystreet.assets.named_select_action_found.call(this, asset);
    if (asset.attributes.private) {
        fixmystreet.message_controller.asset_not_found.call(this);
        return;
    } else if (fixmystreet.message_controller.asset_found.call(this)) {
        return;
    }

    var lonlat = asset.geometry.getBounds().getCenterLonLat();
    // Features considered overlapping if within 1M of each other
    // TODO: Should zoom/marker size be considered when determining if markers overlap?
    var overlap_threshold = 1;
    var overlapping_features = this.getFeaturesWithinDistance(
        new OpenLayers.Geometry.Point(lonlat.lon, lonlat.lat),
        overlap_threshold
    );
    if (overlapping_features.length > 1) {
        // TODO: In an ideal world we'd be able to show the user a photo of each
        // of the assets and ask them to pick one.
        // However the Alloy API requires authentication for photos which we
        // don't have in FMS JS. Instead, we tell the user there are multiple things here
        // and ask them to describe the asset in the description field.
        var $p = $("#overlapping_features_msg");
        if (!$p.length) {
            $p = $("<p id='overlapping_features_msg' class='hidden box-warning'>" +
            "There is more than one <span class='overlapping_item_name'></span> at this location. " +
            "Please describe which <span class='overlapping_item_name'></span> has the problem clearly.</p>");
            $('#category_meta').before($p).closest('.js-reporting-page').removeClass('js-reporting-page--skip');
        }
        $p.find(".overlapping_item_name").text(this.fixmystreet.asset_item);
        $p.removeClass('hidden');
    } else {
        $("#overlapping_features_msg").addClass('hidden');
    }
};

fixmystreet.assets.oxfordshire.light_asset_not_found = function() {
    $("#overlapping_features_msg").addClass('hidden');
    fixmystreet.message_controller.asset_not_found.call(this);
    fixmystreet.assets.named_select_action_not_found.call(this);
};

/* Peterborough */

var pboro_NEW_TREE_CATEGORY_NAME = 'Request for tree to be planted';
var pboro_UNKNOWN_LIGHT_CATEGORY_NAME = 'Problem with a light not shown on map';

fixmystreet.assets.peterborough = {};

fixmystreet.assets.peterborough.trees_relevant = function(options) {
    return options.group === 'Trees' && options.category !== pboro_NEW_TREE_CATEGORY_NAME;
};

fixmystreet.assets.peterborough.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${UNITNO}")
});

fixmystreet.assets.peterborough.lighting_asset_details = function() {
    var a = this.attributes;
    return "street: " + a.FULLSTREET + "\n" +
        "locality: " + a.LOCALITY + "\n" +
        "unitno: " + a.UNITNO + "\n" +
        "unitid: " + a.UNITID;
};

fixmystreet.assets.peterborough.lighting_relevant = function(options) {
    return  ( options.group === 'Street lighting' &&
              options.category !== pboro_UNKNOWN_LIGHT_CATEGORY_NAME
            ) || options.category === "Lighting enquiry";
};
fixmystreet.assets.peterborough.lighting_asset_found = function(asset) {
    fixmystreet.message_controller.asset_found.call(this, asset);
    fixmystreet.assets.named_select_action_found.call(this, asset);
};
fixmystreet.assets.peterborough.lighting_asset_not_found = function() {
    fixmystreet.message_controller.asset_not_found.call(this);
    fixmystreet.assets.named_select_action_not_found.call(this);
};

fixmystreet.assets.peterborough.bin_asset_details = function() {
    var a = this.attributes;
    return a.Reference + ", " + a.Location;
};

// Show a special flytipping/graffiti message on private or leased land, not a
// road. If we're in a leased area, show the message; if we're not on PCC land
// at all, show the message if we're not on a road.

fixmystreet.assets.peterborough.pcc_found = function(layer) {
    delete layer.map_messaging.asset;
};
fixmystreet.assets.peterborough.pcc_not_found = function(layer) {
    for ( var i = 0; i < fixmystreet.assets.layers.length; i++ ) {
        var l = fixmystreet.assets.layers[i];
        if ( l.fixmystreet.name == 'Adopted Highways' && l.selected_feature ) {
            delete layer.map_messaging.asset;
            return;
        }
    }
    var msg = $(layer.fixmystreet.message_template).html();
    layer.map_messaging.asset = msg;
};
fixmystreet.assets.peterborough.leased_found = function(layer) {
    var msg = $(layer.fixmystreet.message_template).html();
    layer.map_messaging.asset = msg;
};
fixmystreet.assets.peterborough.leased_not_found = function(layer) {
    delete layer.map_messaging.asset;
};

/* Shropshire */

fixmystreet.assets.shropshire = {};

fixmystreet.assets.shropshire.street_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        strokeColor: "#5555FF",
        strokeOpacity: 0.1,
        strokeWidth: 7
    })
});

fixmystreet.assets.shropshire.street_found = function(layer, asset) {
    fixmystreet.message_controller.road_found(layer, asset.attributes.SITE_CLASS, function(name) {
        if (name == 'PUB' || name === 'PUPI') { return 1; }
        else { return 0; }
    }, "#js-not-council-road");
};
fixmystreet.assets.shropshire.street_not_found = function(layer) {
      fixmystreet.message_controller.road_not_found(layer);
};

// Only parish rows have an owner
function shropshire_light(f) {
    return f &&
           f.attributes &&
           !f.attributes.OWNER;
}
function shropshire_parish_light(f) {
    return !shropshire_light(f);
}

var shropshire_light_default_style = new OpenLayers.Style({
    fillColor: "#868686",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.6,
    strokeWidth: 2,
    pointRadius: 4
});
var shropshire_rule_light_owned = create_rule(shropshire_light, {
    fillColor: "#FFFF00",
    pointRadius: 6
});
var shropshire_rule_light_not_owned = create_rule(shropshire_parish_light);
shropshire_light_default_style.addRules([ shropshire_rule_light_owned, shropshire_rule_light_not_owned ]);

fixmystreet.assets.shropshire.streetlight_stylemap = new OpenLayers.StyleMap({
    'default': shropshire_light_default_style,
    'select': fixmystreet.assets.style_default_select,
    'hover': new OpenLayers.Style({
        pointRadius: 8,
        cursor: 'pointer'
    })
});

fixmystreet.assets.shropshire.streetlight_found = function(asset) {
    var controller_fn = shropshire_light(asset) ? 'asset_found' : 'asset_not_found';
    if (asset.attributes.OWNER) {
        this.fixmystreet.no_asset_msg_id = '#sl-owner-' + asset.attributes.FEAT_LABEL + asset.attributes.OWNER.replace(/[^a-zA-Z0-9]/g, '');
        this.fixmystreet.no_asset_message = fixmystreet.assets.shropshire.streetlight_asset_message(asset);
    }
    fixmystreet.message_controller[controller_fn].call(this);
    fixmystreet.assets.named_select_action_found.call(this, asset);
};
fixmystreet.assets.shropshire.streetlight_not_found = function(asset) {
    fixmystreet.message_controller.asset_not_found.call(this);
    fixmystreet.assets.named_select_action_not_found.call(this);
};

fixmystreet.assets.shropshire.streetlight_asset_message = function(asset) {
    var out = 'You have selected streetlight <b>' + asset.attributes.FEAT_LABEL + '</b>.';
    if (asset.attributes.PART_NIGHT === "YES") {
        out += "<br>This light is switched off from 12am until 5.30am.";
    }
    if (asset.attributes.OWNER) {
        out += " This light is the responsibility of " + asset.attributes.OWNER + " and should be reported to them, please see <a href='https://shropshire.gov.uk/committee-services/mgParishCouncilDetails.aspx?bcr=1'>the list of parish councils</a>.";
    }
    return out;
};

/* Surrey */

fixmystreet.assets.surrey = {};

fixmystreet.assets.surrey.road_not_found = function(layer) {
    var currentCategory = fixmystreet.reporting.selectedCategory().category;
    if (!fixmystreet.reporting_data || currentCategory === '') {
        // Skip checks until category has been selected.
        fixmystreet.message_controller.road_found(layer);
        return;
    }
    if (layer.fixmystreet.permissive_categories && layer.fixmystreet.permissive_categories.indexOf(fixmystreet.reporting.selectedCategory().category) !== -1) {
        fixmystreet.message_controller.road_found(layer);
    } else {
        fixmystreet.message_controller.road_not_found(layer);
    }
};

/* TfL */

fixmystreet.assets.tfl = {};

function tfl_check_bus_layer(layer, asset) {
    var lonlat = asset.geometry.getBounds().getCenterLonLat();

    var overlap_threshold = 1;
    var overlapping_features = layer.getFeaturesWithinDistance(
        new OpenLayers.Geometry.Point(lonlat.lon, lonlat.lat),
        overlap_threshold
    );
    if (overlapping_features.length) {
        layer.setAttributeFields(overlapping_features[0], true);
    }
}

fixmystreet.assets.tfl.bus_attribute_set = function(asset) {
    var other_layer;
    if (this.name == 'TfL Bus Stops') {
        other_layer = fixmystreet.map.getLayersByName("TfL Bus Shelters")[0];
    } else if (this.name == 'TfL Bus Shelters') {
        other_layer = fixmystreet.map.getLayersByName("TfL Bus Stops")[0];
    }
    if (!other_layer) {
        return;
    }
    tfl_check_bus_layer(other_layer, asset);
};

fixmystreet.assets.tfl.asset_found = function(asset) {
    if (this.name == 'TfL Bus Stations') {
        var $vcs_question = $('#form_Victoria_Area'),
            $page = $vcs_question.closest('.js-reporting-page');
        if ($vcs_question.length && asset.attributes.STOP_NAME != "Victoria Coach Station") {
            $page.addClass('js-reporting-page--skip');
        } else {
            $page.removeClass('js-reporting-page--skip');
        }
    }
    fixmystreet.message_controller.asset_found.call(this, asset);
    fixmystreet.assets.named_select_action_found.call(this, asset);
};
fixmystreet.assets.tfl.asset_not_found = function() {
    fixmystreet.message_controller.asset_not_found.call(this);
    fixmystreet.assets.named_select_action_not_found.call(this);
};

fixmystreet.assets.tfl.construct_selected_asset_message = function(asset) {
    var id = asset.attributes.STOP_CODE || '';
    var road = asset.attributes.ROAD_NAME || '';

    if (!id) {
        // Clicked on a shelter, but always want to show the bus stop ID
        var lonlat = asset.geometry.getBounds().getCenterLonLat();
        var other_layer = fixmystreet.map.getLayersByName("TfL Bus Stops")[0];
        var overlapping_features = other_layer.getFeaturesWithinDistance(
            new OpenLayers.Geometry.Point(lonlat.lon, lonlat.lat), 1);
        if (overlapping_features.length) {
            id = overlapping_features[0].attributes.STOP_CODE;
        }
    }
    if (!id) {
        return;
    }

    var message = ['You have selected', this.fixmystreet.asset_item, '<b>' + id + '</b>'];
    if (road) {
        road = road.replace(/[^-\s]+/g, function(s) { return s.charAt(0).toUpperCase() + s.substring(1).toLowerCase(); });
        message.push('(' + road + ')');
    }
    return message.join(' ');
};

// Roadworks asset layer

fixmystreet.assets.tfl.roadworks_stylemap = new OpenLayers.StyleMap({
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

function tfl_to_ddmmyyyy(date) {
    date = date.toISOString();
    date = date.slice(8, 10) + '/' + date.slice(5, 7) + '/' + date.slice(0, 4);
    return date;
}

fixmystreet.assets.tfl.roadworks_attribute_start = function() {
    return tfl_to_ddmmyyyy(new Date(this.attributes.start_date));
};
fixmystreet.assets.tfl.roadworks_attribute_end = function() {
    return tfl_to_ddmmyyyy(new Date(this.attributes.end_date));
};

fixmystreet.assets.tfl.roadworks_filter_value = function(feature) {
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
};

fixmystreet.assets.tfl.roadworks_asset_found = function(feature) {
    this.fixmystreet.actions.asset_not_found.call(this);
    feature.layer = this;
    var attr = feature.attributes,
        start = tfl_to_ddmmyyyy(new Date(attr.start_date)),
        end = tfl_to_ddmmyyyy(new Date(attr.end_date)),
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
};

fixmystreet.assets.tfl.roadworks_asset_not_found = function() {
    $(".js-roadworks-message-" + this.id).remove();
};

/* Red routes (TLRN) asset layer & handling for disabling form when red route
   is not selected for specific categories.
   This comes after the point assets so that any asset is deselected by the
   time the check for the red-route only categories is run.
 */

fixmystreet.assets.tfl.tlrn_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillColor: "#ff0000",
        fillOpacity: 0.3,
        strokeColor: "#ff0000",
        strokeOpacity: 1,
        strokeWidth: 2
    })
});

/*
    Reports in these categories can only be made on a red route.
*/
var tlrn_categories = document.getElementById('tlrn-categories');
if (tlrn_categories) {
    tlrn_categories = JSON.parse(tlrn_categories.dataset.tlrnCategories);
} else {
    tlrn_categories = [];
}

function is_tlrn_category_only(category, bodies) {
    return OpenLayers.Util.indexOf(tlrn_categories, category) > -1 &&
        OpenLayers.Util.indexOf(bodies, 'TfL') > -1 &&
        bodies.length <= 1;
}

var a13dbfo_categories = tlrn_categories.concat([
    "Flytipping (TfL)",
    "Graffiti / Flyposting on traffic light (non-offensive)",
    "Graffiti / Flyposting on traffic light (offensive)"
]);

function is_a13dbfo_category(category, bodies) {
    return OpenLayers.Util.indexOf(a13dbfo_categories, category) > -1 &&
        OpenLayers.Util.indexOf(bodies, 'TfL') > -1 &&
        bodies.length <= 1;
}

fixmystreet.assets.tfl.red_routes_not_found = function(layer) {
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
};

$(function(){
    var layer = fixmystreet.map.getLayersByName('Red Routes')[0];
    if (layer) {
        layer.events.register( 'loadend', layer, function(){
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
    // One of the bus stop/shelter layers could have loaded before the other,
    // and a feature auto-selected already, and we need the data from both
    // layers, so make sure we poke it after the second layer loads
    layers = fixmystreet.map.getLayersByName(/TfL Bus/);
    $.each(layers, function(i, layer) {
        layer.events.register( 'loadend', layer, function(){
            var feature = fixmystreet.assets.selectedFeature();
            if (feature) {
                tfl_check_bus_layer(this, feature);
            }
        });
    });
});

fixmystreet.assets.tfl.a13_found = function(layer) {
    // Only care about this on TfL cobrand
    if (fixmystreet.cobrand !== 'tfl') {
        return;
    }
    // "Other (TfL)" has a stopper message set in the admin"
    $('#js-category-stopper').remove();
    var category = fixmystreet.reporting.selectedCategory().category;
    if (is_a13dbfo_category(category, fixmystreet.bodies)) {
        fixmystreet.message_controller.road_not_found(layer);
        var body = new RegExp('&body=.*');
        ($('#a13dbfolink').attr('href', $('#a13dbfolink').attr('href').replace(body, '&body=' +  encodeURIComponent(window.location.href))));
    } else {
        fixmystreet.message_controller.road_found(layer);
    }
};

fixmystreet.assets.tfl.construct_bus_station_selected_asset_message = function(asset) {
    var name = asset.attributes.STOP_NAME || asset.attributes.SITE_NAME || '';

    if (!name) {
        return;
    }

    var message = ['You have selected', this.fixmystreet.asset_item, '<b>' + name + '</b>'];
    return message.join(' ');
};


/* Thamesmead */

fixmystreet.assets.thamesmead = {};
fixmystreet.assets.thamesmead.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${feature_id}")
});

/* Westminster */

fixmystreet.assets.westminster = {};

/* First let us set up some necessary subclasses */

/* This layer is relevant depending upon the category *and* the choice of the 'type' Open311 extra attribute question */
var SubcatMixin = OpenLayers.Class({
    relevant: function() {
        var relevant = OpenLayers.Layer.VectorAsset.prototype.relevant.apply(this, arguments),
            subcategories = this.fixmystreet.subcategories,
            subcategory = $(this.fixmystreet.subcategory_id).val(),
            relevant_sub = OpenLayers.Util.indexOf(subcategories, subcategory) > -1;
        return relevant && relevant_sub;
    },
    CLASS_NAME: 'SubcatMixin'
});
OpenLayers.Layer.VectorAssetWestminsterSubcat = OpenLayers.Class(OpenLayers.Layer.VectorAsset, SubcatMixin, {
    CLASS_NAME: 'OpenLayers.Layer.VectorAssetWestminsterSubcat'
});
OpenLayers.Layer.VectorAssetWestminsterSubcatUPRN = OpenLayers.Class(OpenLayers.Layer.VectorAssetMove, SubcatMixin, {
    CLASS_NAME: 'OpenLayers.Layer.VectorAssetWestminsterSubcatUPRN'
});

function westminster_uprn_sort(a, b) {
    a = a.attributes.ADDRESS;
    b = b.attributes.ADDRESS;
    var a_flat = a.match(/^(Flat|Unit)s? (\d+)/);
    var b_flat = b.match(/^(Flat|Unit)s? (\d+)/);
    if (a_flat && b_flat && a_flat[1] === b_flat[1]) {
        return a_flat[2] - b_flat[2];
    }
    return a.localeCompare(b);
}

var westminster_old_uprn;

function westminster_add_to_uprn_select($select, assets) {
    assets.sort(westminster_uprn_sort);
    $.each(assets, function(i, f) {
        $select.append('<option value="' + f.attributes.UPRN + '">' + f.attributes.ADDRESS + '</option>');
    });
    if (westminster_old_uprn && $select.find('option[value=\"' + westminster_old_uprn + '\"]').length) {
        $select.val(westminster_old_uprn);
    }
}

function westminster_construct_uprn_select(assets, has_children) {
    westminster_old_uprn = $('#uprn').val();
    $('.category_meta_message').html('');
    var $div = $("#uprn_select");
    if (!$div.length) {
        $div = $('<div data-page-name="uprn" class="js-reporting-page extra-category-questions" id="uprn_select"></div>');
        $div.insertBefore('.js-reporting-page[data-page-name="photo"]');
    }
    $div.removeClass('js-reporting-page--skip');
    if (assets.length > 1 || has_children) {
        $div.empty();
        $div.append('<label for="uprn">Please choose a property:</label>');
        var $select = $('<select id="uprn" class="form-control" name="UPRN" required>');
        $select.append('<option value="">---</option>');
        westminster_add_to_uprn_select($select, assets);
        $div.append($select);
    } else {
        $div.html('You have selected <b>' + assets[0].attributes.ADDRESS + '</b>');
    }
    $div.append("<button class='btn btn--block btn--final js-reporting-page--next'>Continue</button>");
}

fixmystreet.assets.westminster.uprn_asset_found = function(asset) {
    if (fixmystreet.message_controller.asset_found.call(this)) {
        return;
    }
    var lonlat = asset.geometry.getBounds().getCenterLonLat();
    var overlap_threshold = 1; // Features considered overlapping if within 1m of each other
    var overlapping_features = this.getFeaturesWithinDistance(
        new OpenLayers.Geometry.Point(lonlat.lon, lonlat.lat),
        overlap_threshold
    );

    var parent_uprns = [];
    $.each(overlapping_features, function(i, f) {
        if (f.attributes.PARENTCHILD === 'Parent') {
            parent_uprns.push("PARENTUPRN='" + f.attributes.UPRN + "'");
        }
    });
    parent_uprns = parent_uprns.join(' OR ');

    if (parent_uprns) {
        var url = this.fixmystreet.http_options.url + OpenLayers.Util.getParameterString({
            inSR: 4326,
            f: 'geojson',
            outFields: 'UPRN,Address',
            where: parent_uprns
        });
        $.getJSON(url, function(data) {
            var features = [];
            $.each(data.features, function(i, f) {
                features.push({ attributes: f.properties });
            });
            westminster_add_to_uprn_select($('#uprn'), features);
        });
    }
    westminster_construct_uprn_select(overlapping_features, parent_uprns);
};

fixmystreet.assets.westminster.uprn_asset_not_found = function() {
    $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
    $("#uprn_select").addClass('js-reporting-page--skip');
    fixmystreet.message_controller.asset_not_found.call(this);
};

fixmystreet.assets.westminster.asset_found = function(asset) {
    // Remove any existing street entertainment messages using function below.
    this.fixmystreet.actions.asset_not_found.call(this);

    var attr = asset.attributes;
    var site = attr.Site;
    var category = attr.Category;
    var terms = attr.Terms_Conditions;

    var $msg = $('<div class="js-street-entertainment-message box-warning"></div>');
    var $dl = $("<dl></dl>").appendTo($msg);

    $dl.append("<dt>Site</dt>");
    $dl.append($("<dd></dd>").text(site));

    $dl.append("<dt>Category</dt>");
    $dl.append($("<dd></dd>").text(category));

    $dl.append("<dt>Terms & conditions</dt>");
    $dl.append($("<dd></dd>").html(terms));

    $msg.prependTo('#js-post-category-messages');
};

fixmystreet.assets.westminster.asset_not_found = function() {
    $('.js-street-entertainment-message').remove();
};

if (fixmystreet.cobrand == 'westminster' || fixmystreet.cobrand == 'fixmystreet') {
    $(function(){
        $("#problem_form").on("change.category", "#form_type, #form_featuretypecode, #form_bin_type", function() {
            $(fixmystreet).trigger('report_new:category_change');
        });
    });
}

})();
