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

var pin_prefix = fixmystreet.pin_prefix || document.getElementById('js-map-data').getAttribute('data-pin_prefix');

var streetlight_default = {
    fillColor: "#FFFF00",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.8,
    strokeWidth: 2,
    pointRadius: 6
};

var streetlight_select = {
    externalGraphic: pin_prefix + "pin-spot.png",
    fillColor: "#55BB00",
    graphicWidth: 48,
    graphicHeight: 64,
    graphicXOffset: -24,
    graphicYOffset: -56,
    backgroundGraphic: pin_prefix + "pin-shadow.png",
    backgroundWidth: 60,
    backgroundHeight: 30,
    backgroundXOffset: -7,
    backgroundYOffset: -22,
    popupYOffset: -40,
    graphicOpacity: 1.0,

    label: "${feature_id}",
    labelOutlineColor: "white",
    labelOutlineWidth: 3,
    labelYOffset: 65,
    fontSize: '15px',
    fontWeight: 'bold'
};

var streetlight_select_alt = $.extend(true, {}, streetlight_select, {
  label: "${asset_no}"
});

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': new OpenLayers.Style(streetlight_default),
  'select': new OpenLayers.Style(streetlight_select)
});

var streetlight_stylemap_alt = new OpenLayers.StyleMap({
  'default': new OpenLayers.Style(streetlight_default),
  'select': new OpenLayers.Style(streetlight_select_alt)
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
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'site_code'
    },
    feature_code: 'feature_id',
    actions: {
        asset_found: function(asset, config) {
          var id = asset.attributes[config.feature_code] || '';
          if (id !== '') {
              var code = id.replace(/[0-9]/g, '');
              var asset_name = streetlight_code_to_type[code] || config.asset_item;
              $('.category_meta_message').html('You have selected ' + asset_name + ' <b>' + id + '</b>');
          } else {
              $('.category_meta_message').html('You can pick a <b class="asset-spot">' + config.asset_item + '</b> from the map &raquo;');
          }
        },
        asset_not_found: function(config) {
           $('.category_meta_message').html('You can pick a <b class="asset-spot">' + config.asset_item + '</b> from the map &raquo;');
        }
    }
});

fixmystreet.assets.add($.extend(true, {}, labeled_defaults, {
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
}));

fixmystreet.assets.add($.extend(true, {}, labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "IlluminatedBollards"
        }
    },
    asset_category: ["Bollard light not working"],
    asset_item: 'bollard'
}));

fixmystreet.assets.add($.extend(true, {}, labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "Bollards"
        }
    },
    asset_category: ["Bollards or railings"],
    asset_item: 'bollard'
}));

fixmystreet.assets.add($.extend(true, {}, labeled_defaults, {
    stylemap: streetlight_stylemap,
    http_options: {
        params: {
            TYPENAME: "Beacons"
        }
    },
    attributes: {
        central_asset_id: 'central_as',
    },
    asset_category: [
          'Belisha Beacon broken',
        ],
    asset_item: 'belisha beacon'
}));

fixmystreet.assets.add($.extend(true, {}, labeled_defaults, {
    stylemap: streetlight_stylemap,
    http_options: {
        params: {
            TYPENAME: "Beacon_Column"
        }
    },
    attributes: {
        central_asset_id: 'central_as',
    },
    asset_category: [
          'Belisha Beacon broken',
        ],
    asset_item: 'belisha beacon'
}));

fixmystreet.assets.add($.extend(true, {}, labeled_defaults, {
    stylemap: streetlight_stylemap_alt,
    http_options: {
        params: {
            TYPENAME: "Crossings"
        }
    },
    attributes: {
        central_asset_id: 'central_as',
    },
    feature_code: 'asset_no',
    asset_category: [
          'Traffic lights & crossings problems with buttons, beep or lamps',
          'Traffic lights & crossings problems with timings',
        ],
    asset_item: 'crossing'
}));

fixmystreet.assets.add($.extend(true, {}, labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "Signs_Union"
        }
    },
    attributes: {
        central_asset_id: 'central_as',
    },
    asset_category: [
          'Sign light not working',
          'Sign problem',
        ],
    asset_item: 'sign'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Gullies"
        }
    },
    attributes: {
        central_asset_id: 'central_as',
    },
    asset_category: [
        'Blocked drain'
        ],
    asset_item: 'drain'
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
    $('.js-update-coordinates').attr('href', function(i, href) {
        if (href.indexOf('?') != -1) {
            href = href.substring(0, href.indexOf('?'));
        }
        href += '?' + OpenLayers.Util.getParameterString({
            latitude: $('#fixmystreet\\.latitude').val(),
            longitude: $('#fixmystreet\\.longitude').val()
        });
        return href;
    });
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

$(fixmystreet).on('report_new:highways_change', function() {
    if (fixmystreet.body_overrides.get_only_send() === 'Highways England') {
        hide_responsibility_errors();
        enable_report_form();
        $('#bucks_dangerous_msg').hide();
    } else {
        $('#bucks_dangerous_msg').show();
        $(fixmystreet).trigger('report_new:category_change', [ $('#form_category') ]);
    }
});


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
            } else {
                // User has clicked a road that Bucks don't maintain.

                var map = {
                    "HE": '#js-not-council-road-he',
                    "HWOA": '#js-not-council-road-other'
                };

                fixmystreet.body_overrides.do_not_send(layer.fixmystreet.body);
                if (is_only_body(layer.fixmystreet.body)) {
                    var id = map[feature.attributes.feature_ty] || '#js-not-council-road';
                    show_responsibility_error(id);
                    disable_report_form();
                }
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
