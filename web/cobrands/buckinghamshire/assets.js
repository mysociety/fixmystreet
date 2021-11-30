(function(){

if (!fixmystreet.maps) {
    return;
}

var wfs_host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';
var tilma_url = "https://" + wfs_host + "/mapserver/bucks";
var proxy_base_url = "https://" + wfs_host + "/proxy/bcc/";

var defaults = {
    http_options: {
        url: tilma_url,
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    asset_type: 'spot',
    max_resolution: 4.777314267158508,
    asset_id_field: 'central_as',
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'site_code'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    body: "Buckinghamshire Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Grit_Bins"
        }
    },
    asset_category: ["Salt bin damaged", "Salt bin refill"],
    asset_item: 'grit bin'
});

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${feature_id}")
});

var streetlight_code_to_type = {
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

var labeled_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    feature_code: 'feature_id',
    stylemap: streetlight_stylemap,
    construct_asset_name: function(id) {
        var code = id.replace(/[O0-9]+[A-Z]*/g, '');
        return {id: id, name: streetlight_code_to_type[code] || 'street light'};
    },
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "StreetLights_Union"
        }
    },
    asset_category: [
        'Light on during the day',
        'Street light dim',
        'Street light intermittent',
        'Street light not working' ],
    asset_item: 'street light',
    asset_item_message: 'You can pick a <b class="asset-ITEM">ITEM</b> from the map &raquo;<br>If there is no yellow dot showing then this ITEM is not maintained by Transport for Buckinghamshire',
    construct_selected_asset_message: function(asset) {
        var id = asset.attributes[this.fixmystreet.feature_code] || '';
        if (id === '') {
            return;
        }
        var data = this.fixmystreet.construct_asset_name(id);
        var extra = '. Only ITEMs maintained by Transport for Buckinghamshire are displayed.';
        extra = extra.replace(/ITEM/g, data.name);
        return 'You have selected ' + data.name + ' <b>' + data.id + '</b>' + extra;
    }
});

fixmystreet.assets.add(labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "IlluminatedBollards"
        }
    },
    asset_category: ["Bollard light not working"],
    asset_item: 'bollard'
});

fixmystreet.assets.add(labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "Bollards"
        }
    },
    asset_category: ["Bollards or railings"],
    asset_item: 'bollard'
});

fixmystreet.assets.add(labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "Beacons"
        }
    },
    asset_category: [
          'Belisha Beacon broken',
        ],
    asset_item: 'belisha beacon'
});

fixmystreet.assets.add(labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "Beacon_Column"
        }
    },
    asset_category: [
          'Belisha Beacon broken',
        ],
    asset_item: 'belisha beacon'
});

fixmystreet.assets.add(labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "Crossings"
        }
    },
    asset_category: [
          'Traffic lights & crossings problems with buttons, beep or lamps',
          'Traffic lights & crossings problems with timings',
        ],
    asset_item: 'crossing'
});

fixmystreet.assets.add(labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "Signs_Union"
        }
    },
    asset_category: [
          'Sign light not working',
          'Sign problem',
        ],
    asset_item: 'sign'
});

fixmystreet.assets.add(defaults, {
    http_options: {
        url: proxy_base_url + 'drains/wfs',
        params: {
            propertyName: 'id,msGeometry,asset_id,created,junction_cleaned',
            TYPENAME: "junction_inspections"
        }
    },
    stylemap: fixmystreet.assets.stylemap_invisible,
    asset_category: ["Blocked drain"],
    asset_item: 'drain',
    non_interactive: true
});

fixmystreet.assets.add(defaults, {
    http_options: {
        url: proxy_base_url + 'drains/wfs',
        params: {
            propertyName: 'id,msGeometry,asset_id,created,last_inspected',
            TYPENAME: "junctions"
        }
    },
    asset_category: ["Blocked drain"],
    asset_item: 'drain',
    select_action: true,
    construct_selected_asset_message: function(asset) {
        var junctionInspectionLayer = window.fixmystreet.assets.layers.filter(function(elem) {
            return elem.fixmystreet.body == "Buckinghamshire Council" && 
            elem.fixmystreet.http_options.format.featureType == 'junction_inspections';
        });
        var inspection;
        if (junctionInspectionLayer[0]) {
            inspection = junctionInspectionLayer[0].features.filter(function(elem) {
                return elem.attributes.asset_id == asset.attributes.asset_id &&
                format_date(elem.attributes.created) == format_date(asset.attributes.last_inspected);
            });
        }
        var last_clean = '';
        var message = ' ';
        if (inspection && inspection[0]) {
            if (asset.attributes.last_inspected && inspection[0].attributes.junction_cleaned === 'true') {
                last_clean = format_date(asset.attributes.last_inspected);
                message = 'This gulley was last cleaned on ' + last_clean;
            }
        }
        return message;
    },
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

function format_date(date_field) {
    var regExDate = /([0-9]{4})-([0-9]{2})-([0-9]{2})/;
    var myMatch = regExDate.exec(date_field);
    if (myMatch) {
        return myMatch[3] + '/' + myMatch[2] + '/' + myMatch[1];
    } else {
        return '';
    }
}

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

// Since Buckinghamshire went unitary, if the user selects an ex-district
// category we shouldn't enforce the road asset selection.
var ex_district_categories = [
    "Abandoned vehicles",
    "Car Parks",
    "Dog fouling",
    "Flyposting",
    "Flytipping",
    "Graffiti",
    "Parks/landscapes",
    "Public toilets",
    "Rubbish (refuse and recycling)",
    "Street cleaning",
    "Street nameplates"
];

function category_unselected_or_ex_district() {
    var cat = fixmystreet.reporting.selectedCategory().category;
    if (OpenLayers.Util.indexOf(ex_district_categories, cat) != -1) {
        return true;
    }
    return false;
}

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

$(fixmystreet).on('report_new:highways_change', function() {
    if (fixmystreet.body_overrides.get_only_send() === 'National Highways') {
        $('#bucks_dangerous_msg').hide();
    } else {
        $('#bucks_dangerous_msg').show();
    }
});


fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            propertyName: 'msGeometry,site_code,feature_ty',
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
    asset_type: 'road',
    all_categories: true,
    actions: {
        found: function(layer, feature) {
            var map = {
                "HE": '#js-not-council-road-he',
                "HWOA": '#js-not-council-road-other'
            };
            var msg_id = map[feature.attributes.feature_ty] || '#js-not-council-road';

            fixmystreet.body_overrides.allow_send(layer.fixmystreet.body);
            fixmystreet.body_overrides.remove_only_send();
            fixmystreet.message_controller.road_found(layer, feature, function(feature) {
                // If an ex-district category is selected, always allow report
                // regardless of road ownership.
                if (category_unselected_or_ex_district()) {
                    return true;
                }
                if (OpenLayers.Util.indexOf(bucks_types, feature.attributes.feature_ty) != -1) {
                    return true;
                }
                return false;
            }, msg_id);
        },

        not_found: function(layer) {
            // If an ex-district category is selected, always allow report.
            fixmystreet.body_overrides.remove_only_send();
            if (category_unselected_or_ex_district()) {
                fixmystreet.body_overrides.allow_send(layer.fixmystreet.body);
            } else {
                fixmystreet.body_overrides.do_not_send(layer.fixmystreet.body);
                fixmystreet.message_controller.road_not_found(layer);
            }
        }
    },
    no_asset_msg_id: '#js-not-a-road',
    no_asset_msgs_class: '.js-roads-bucks',
    usrn: {
        attribute: 'site_code',
        field: 'site_code'
    },
    filter_key: 'feature_ty',
    filter_value: types_to_show,
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "WinterRoutes"
        }
    },
    asset_category: "Snow and ice problem/winter salting",
    asset_item: "road",
    asset_type: "road",
    non_interactive: true,
    road: true,
    actions: {
        found: function() {
            var $div = $(".js-reporting-page.js-gritting-notice");
            if ($div.length) {
                $div.removeClass('js-reporting-page--skip');
            } else {
                var msg = "<div class='box-warning js-gritting-notice'>" +
                            "<h1>Winter Gritting</h1>" +
                            "<p>The road you have selected is on a regular " +
                            "gritting route, and will be gritted according " +
                            "to the published " +
                            "<a href='https://www.buckscc.gov.uk/services/transport-and-roads/road-maintenance-and-repairs/winter-maintenance/'>" +
                            "policy</a>.</p>" +
                            "</div>";
                $div = $(msg);
                fixmystreet.pageController.addNextPage('gritting', $div);
            }
        },
        not_found: function() {
            $('.js-reporting-page.js-gritting-notice').addClass('js-reporting-page--skip');
        }
    }
});

})();
