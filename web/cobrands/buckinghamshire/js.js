(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://davea.tilma.dev.mysociety.org/mapserver/bucks",
        // url: "https://confirmdev.eu.ngrok.io/tilma/mapserver/bucks",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    format_class: OpenLayers.Format.GML.v3.MultiCurveFix,
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'central_as',
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'Site_code'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
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

var highways_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        fillOpacity: 0,
        strokeColor: "#55BB00",
        strokeOpacity: 0.3,
        strokeWidth: 8
    })
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


function show_responsibility_error(id) {
    hide_responsibility_errors();
    $("#js-bucks-responsibility").removeClass("hidden");
    $("#js-bucks-responsibility .js-responsibility-message").addClass("hidden");
    $(id).removeClass("hidden");

    // TODO: Disable report creation at this point?
}

function hide_responsibility_errors() {
    $("#js-bucks-responsibility").addClass("hidden");
    $("#js-bucks-responsibility .js-responsibility-message").addClass("hidden");
}

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Whole_Street"
        }
    },
    stylemap: highways_stylemap,
    always_visible: true,
    non_interactive: true,
    road: true,
    asset_item: 'road',
    asset_category: [
        "Pothole",
        "Road surface"
    ],
    actions: {
        found: function(layer, feature) {
            if (bucks_types.indexOf(feature.attributes.feature_ty) != -1) {
                hide_responsibility_errors();
            } else {
                // User has clicked a road that Bucks don't maintain.
                show_responsibility_error("#js-not-bucks-road");
            }
        },

        not_found: function(layer) {
            // If a feature wasn't found at the location they've clicked, it's
            // probably a field or something. Show an error to that effect.
            show_responsibility_error("#js-not-a-road");
        }
    },
    usrn: {
        attribute: 'site_code',
        field: 'site_code'
    },
    filter_key: 'feature_ty',
    filter_value: types_to_show,
}));

fixmystreet.assets.add(fixmystreet.roadworks.layer_future);
fixmystreet.assets.add(fixmystreet.roadworks.layer_planned);

})();
