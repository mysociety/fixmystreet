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
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    asset_type: 'spot',
    max_resolution: {
      'buckinghamshire': 2.116670900008467,
      'fixmystreet': 4.777314267158508
    },
    asset_id_field: 'central_as',
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'site_code'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    body: "Buckinghamshire County Council",
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

var streetlight_select = $.extend({
    label: "${feature_id}",
    labelOutlineColor: "white",
    labelOutlineWidth: 3,
    labelYOffset: 65,
    fontSize: '15px',
    fontWeight: 'bold'
}, fixmystreet.assets.style_default_select.defaultStyle);

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'select': new OpenLayers.Style(streetlight_select)
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
    stylemap: streetlight_stylemap,
    actions: {
        asset_found: function(asset) {
          var id = asset.attributes.feature_id || '';
          if (id !== '') {
              var code = id.replace(/[0-9]/g, '');
              var asset_name = streetlight_code_to_type[code] || this.fixmystreet.asset_item;
              $('.category_meta_message').html('You have selected ' + asset_name + ' <b>' + id + '</b>');
          } else {
              $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
          }
        },
        asset_not_found: function() {
           $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
        }
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
    asset_item: 'street light'
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
        params: {
            TYPENAME: "Gullies"
        }
    },
    asset_category: [
        'Blocked drain'
        ],
    asset_item: 'drain'
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
    if (fixmystreet.body_overrides.get_only_send() === 'Highways England') {
        $('#bucks_dangerous_msg').hide();
    } else {
        $('#bucks_dangerous_msg').show();
    }
});


fixmystreet.assets.add(defaults, {
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
                if (OpenLayers.Util.indexOf(bucks_types, feature.attributes.feature_ty) != -1) {
                    var cat = $('select#form_category').val();
                    if (cat === 'Flytipping') {
                        fixmystreet.body_overrides.only_send(layer.fixmystreet.body);
                    }
                    return true;
                } else {
                    return false;
                }
            }, msg_id);

            // Make sure Flytipping related things reset
            $('#category_meta').show();
            $('#form_road-placement').attr('required', '');
        },

        not_found: function(layer) {
            fixmystreet.body_overrides.do_not_send(layer.fixmystreet.body);
            fixmystreet.body_overrides.remove_only_send();
            fixmystreet.message_controller.road_not_found(layer);

            // If flytipping is picked, we don't want to ask the extra question
            var cat = $('select#form_category').val();
            if (cat === 'Flytipping') {
                $('#category_meta').hide();
                $('#form_road-placement').removeAttr('required');
            } else {
                $('#category_meta').show();
            }
        }
    },
    no_asset_msg_id: '#js-not-a-road',
    usrn: {
        attribute: 'site_code',
        field: 'site_code'
    },
    filter_key: 'feature_ty',
    filter_value: types_to_show,
});

// As with the road found/not_found above, we want to change the destination
// depending upon the answer to the extra question shown when on a road
$("#problem_form").on("change", "#form_road-placement", function() {
    if (this.value == 'road') {
        fixmystreet.body_overrides.allow_send(defaults.body);
        fixmystreet.body_overrides.only_send(defaults.body);
    } else if (this.value == 'off-road') {
        fixmystreet.body_overrides.do_not_send(defaults.body);
        fixmystreet.body_overrides.remove_only_send();
    }
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
            var $div = $("#category_meta .js-gritting-notice");
            if ($div.length) {
                $div.show();
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
                $div.prependTo("#category_meta");
            }
        },
        not_found: function() {
            $("#category_meta .js-gritting-notice").hide();
        }
    }
});

})();
