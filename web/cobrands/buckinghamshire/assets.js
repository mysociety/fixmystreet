(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.mysociety.org/mapserver/bucks",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    format_class: OpenLayers.Format.GML.v3.MultiCurveFix,
    asset_type: 'spot',
    max_resolution: 4.777314267158508,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'central_as',
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'Site_code'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "Buckinghamshire County Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Grit_Bins"
        }
    },
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'site_code' // different capitalisation, sigh
    },
    asset_category: ["Salt bin damaged", "Salt bin refill"],
    asset_item: 'grit bin'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "StreetLights_Merged"
        }
    },
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'Site_code'
    },
    asset_category: [
        'Light on during the day',
        'Street light dim',
        'Street light intermittent',
        'Street light not working' ],
    asset_item: 'street light'
}));


// The "whole street asset" layer indicates who is responsible for maintaining
// a road via the 'feature_ty' attribute on features.
// These are roads that Bucks maintain.
var bucks_types = [
    "2", // HW: STRATEGIC ROUTE
    "3A", // HW: MAIN DISTRIBUTOR
    "3B", // HW: SECONDARY DISTRIBUTOR
    "4A", // HW: LINK ROAD
    "4B", // HW: LOCAL ACCESS ROAD
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
var types_to_show = bucks_types.concat(non_bucks_types);

// Some road types we don't want to display at all.
var types_to_hide = [
    "11", // HW: BYWAY OPEN TO TRAFFIC
    "12", // HW: FOOTPATH PROW
    "13", // HW: BYWAY RESTRICTED
    "14", // HW: BRIDLEWAY
    "9", // HW: NO CARRIAGEWAY
];

var highways_style = new OpenLayers.Style({
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

var rule_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: bucks_owns_feature
    })
});

var rule_not_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: bucks_does_not_own_feature
    }),
    symbolizer: {
        strokeColor: "#555555"
    }
});
highways_style.addRules([rule_owned, rule_not_owned]);

function show_responsibility_error(id) {
    hide_responsibility_errors();
    $("#js-roads-responsibility").removeClass("hidden");
    $("#js-roads-responsibility .js-responsibility-message").addClass("hidden");
    $(id).removeClass("hidden");
}

function hide_responsibility_errors() {
    $("#js-roads-responsibility").addClass("hidden");
    $("#js-roads-responsibility .js-responsibility-message").addClass("hidden");
}

function disable_report_form() {
    $("#problem_form").hide();
}

function enable_report_form() {
    $("#problem_form").show();
}

function is_only_body(body) {
    if (fixmystreet.bodies && fixmystreet.bodies.length == 1 && fixmystreet.bodies[0] == body) {
        return true;
    }
    return false;
}

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Whole_Street"
        }
    },
    stylemap: new OpenLayers.StyleMap({
        'default': highways_style
    }),
    always_visible: true,
    non_interactive: true,
    road: true,
    asset_item: 'road',
    all_categories: true,
    actions: {
        found: function(layer, feature) {
            fixmystreet.body_overrides.allow_send(layer.fixmystreet.body);
            fixmystreet.body_overrides.remove_only_send();
            if (fixmystreet.assets.selectedFeature()) {
                hide_responsibility_errors();
                enable_report_form();
            } else if (OpenLayers.Util.indexOf(bucks_types, feature.attributes.feature_ty) != -1) {
                var cat = $('select#form_category').val();
                if (cat === 'Flytipping') {
                    fixmystreet.body_overrides.only_send(layer.fixmystreet.body);
                }
                hide_responsibility_errors();
                enable_report_form();
            } else if (is_only_body(layer.fixmystreet.body)) {
                // User has clicked a road that Bucks don't maintain.
                fixmystreet.body_overrides.do_not_send(layer.fixmystreet.body);
                show_responsibility_error("#js-not-council-road");
                disable_report_form();
            }
        },

        not_found: function(layer) {
            // If a feature wasn't found at the location they've clicked, it's
            // probably a field or something. Show an error to that effect,
            // unless an asset is selected.
            fixmystreet.body_overrides.do_not_send(layer.fixmystreet.body);
            fixmystreet.body_overrides.remove_only_send();
            if (fixmystreet.assets.selectedFeature()) {
                fixmystreet.body_overrides.allow_send(layer.fixmystreet.body);
                hide_responsibility_errors();
                enable_report_form();
            } else if (is_only_body(layer.fixmystreet.body)){
                show_responsibility_error("#js-not-a-road");
                disable_report_form();
            }
        }
    },
    usrn: {
        attribute: 'site_code',
        field: 'site_code'
    },
    filter_key: 'feature_ty',
    filter_value: types_to_show,
}));

})();
