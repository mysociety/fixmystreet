(function(){

if (!fixmystreet.maps) {
    return;
}

/* utility functions */
function show_responsibility_error(id, asset_item, asset_type) {
    hide_responsibility_errors();
    $("#js-roads-responsibility").removeClass("hidden");
    $("#js-roads-responsibility .js-responsibility-message").addClass("hidden");
    if (asset_item) {
        $('#js-roads-asset').html('a <b class="asset-' + asset_type + '">' + asset_item + '</b>');
    } else {
        $('#js-roads-asset').html('an item');
    }
    $(id).removeClass("hidden");
}

function hide_responsibility_errors() {
    $("#js-roads-responsibility").addClass("hidden");
    $("#js-roads-responsibility .js-responsibility-message").addClass("hidden");
}

function enable_report_form() {
    $(".js-hide-if-invalid-category").show();
}

function disable_report_form() {
    $(".js-hide-if-invalid-category").hide();
}

var is_live = false;
if ( location.hostname === 'www.fixmystreet.com' || location.hostname == 'fixmystreet.northamptonshire.gov.uk' ) {
    is_live = true;
}

var layers = [
  /*
{
  "layer_name": "Street Lights",
  "layer": 5,
  "version": "5.4-9.6-"
},
{
  "layer_name": "Street Lighting Nightscape",
  "layer": 9,
  "version": "9.6-"
},
{
  "layer_name": "Carriageways",
  "layer": 20,
  "version": "20.54-"
},
{
  "layer_name": "Road Heirarchy",
  "layer": 39,
  "version": "39.53-"
},
{
  "layer_name": "Posts",
  "layer": 59,
  "version": "59.133-"
},
{
  "layer_name": "Grips",
  "layer": 61,
  "version": "61.1-"
},
{
  "layer_name": "Traffic Monitoring",
  "layer": 62,
  "version": "62.2-"
},
{
  "layer_name": "Special Treatment",
  "layer": 64,
  "version": "64.1-"
},
{
  "layer_name": "Gully",
  "layer": 66,
  "version": "66.9-"
},
{
  "layer_name": "Channel",
  "layer": 68,
  "version": "68.2-"
},
{
  "layer_name": "Comms Cabinet",
  "layer": 69,
  "version": "69.1-"
},
{
  "layer_name": "Steps",
  "layer": 70,
  "version": "70.1-"
},
{
  "layer_name": "Step Handrail",
  "layer": 71,
  "version": "71.1-"
},
{
  "layer_name": "Tree Group",
  "layer": 74,
  "version": "74.1-"
},
{
  "layer_name": "Defects Ancillary Items",
  "layer": 171,
  "version": "171.33-"
},
{
  "layer_name": "Speed Limit",
  "layer": 172,
  "version": "172.33-"
},
{
  "layer_name": "PRoW Network",
  "layer": 173,
  "version": "173.1-"
},
{
  "layer_name": "Footway Schemes",
  "layer": 174,
  "version": "174.1-"
},
{
  "layer_name": "FINGER POST",
  "layer": 178,
  "version": "178.39-"
},
{
  "layer_name": "GAPS",
  "layer": 179,
  "version": "179.1-"
},
{
  "layer_name": "OBSTRUCTIONS",
  "layer": 182,
  "version": "182.2-"
},
{
  "layer_name": "STEPS",
  "layer": 184,
  "version": "184.2-"
},
{
  "layer_name": "Gate Types",
  "layer": 191,
  "version": "191.2-"
},
{
  "layer_name": "Gate Condition",
  "layer": 192,
  "version": "192.2-"
},
{
  "layer_name": "Bridge Type",
  "layer": 193,
  "version": "193.17-"
},
{
  "layer_name": "Bridge Condition",
  "layer": 194,
  "version": "194.17-"
},
{
  "layer_name": "PRoW Net By Type",
  "layer": 201,
  "version": "201.1-"
},
{
  "layer_name": "Finger Post Condition",
  "layer": 209,
  "version": "209.39-"
},
{
  "layer_name": "F Post Path Type",
  "layer": 210,
  "version": "210.39-"
},
{
  "layer_name": "AW_Sewer",
  "layer": 215,
  "version": "215.1-"
},
{
  "layer_name": "CCTV",
  "layer": 218,
  "version": "218.1-"
},
{
  "layer_name": "VMS",
  "layer": 219,
  "version": "219.1-"
},
{
  "layer_name": "Warning Signs",
  "layer": 220,
  "version": "220.1-"
},
{
  "layer_name": "Traffic Calming",
  "layer": 221,
  "version": "221.1-"
},
{
  "layer_name": "Bluetooth Counter",
  "layer": 222,
  "version": "222.1-"
},
{
  "layer_name": "Midblock",
  "layer": 223,
  "version": "223.1-"
},
{
  "layer_name": "Over Height",
  "layer": 224,
  "version": "224.1-"
},
{
  "layer_name": "RTI Display",
  "layer": 226,
  "version": "226.1-"
},
{
  "layer_name": "System Links",
  "layer": 227,
  "version": "227.1-"
},
{
  "layer_name": "CULVERTS (PRoW)",
  "layer": 229,
  "version": "229.1-"
},
{
  "layer_name": "PEDESTRIAN GUARDRAIL",
  "layer": 230,
  "version": "230.1-"
},
{
  "layer_name": "Traffic Signal Controller",
  "layer": 231,
  "version": "231.1-"
},
{
  "layer_name": "Traffic Signal Posts",
  "layer": 232,
  "version": "232.1-"
},
  */
{
  "categories": [ "Grit Bin - damaged/replacement", "Grit Bin - empty/refill" ],
  "item_name": "grit bin",
  "layer_name": "Grit Bins",
  "layer": 13,
  "version": "13.7-"
},
{
  "categories": [ "Highway Bridges - Damaged/Unsafe" ],
  "asset_type": 'area',
  "item_name": 'bridge',
  "layer_name": "Structures",
  "layer": 14,
  "version": "14.3-"
},
{
  "categories": [ "Damaged / Missing / Facing Wrong Way", "Obscured by vegetation or Dirty" ],
  "item_name": "sign",
  "layer_name": "Signs",
  "layer": is_live ? 60 : 303,
  "version": is_live ? "60.2113-" : "303.1-"
},
{
  "categories": [ "Shelter Damaged", "Sign/Pole Damaged" ],
  "layer_name": "Bus Stop",
  "layer": 72,
  "version": "72.8-"
},
{
  "categories": [ "Bridge-Damaged/ Missing" ],
  "item_name": "bridge",
  "layer_name": "BRIDGES",
  "layer": 177,
  "version": "177.18-"
},
{
  "categories": [ "Gate - Damaged/ Missing" ],
  "layer_name": "GATE",
  "layer": 181,
  "version": "181.3-"
},
{
  "categories": [ "Stile-Damaged/Missing" ],
  "layer_name": "STILE",
  "layer": 185,
  "version": "185.3-"
},
{
  "categories": [ "Sign/Waymarking - Damaged/Missing" ],
  "item_name": "waymarking",
  "layer_name": "WAYMARK POST",
  "layer": 187,
  "version": "187.3-"
},
{
  "categories": [
    "Damaged/Exposed Wiring / Vandalised",
    "Lamp/Bulb Failure",
    "Signal Failure",
    "Signal Failure all out",
    "Signal Stuck",
    "Signal Head Failure",
    "Request Timing Review",
    "Damaged Control box",
    "Signal Failure/Damaged - Toucan/Pelican",
  ],
  "item_name": "signal or crossing",
  "layer_name": "TL Junction",
  "layer": 225,
  "version": "225.5-"
},
{
  "categories": [
    "Fallen Tree",
  ],
  "layer_name": "Tree",
  "layer": is_live ? 307 : 228,
  "version": is_live ? "307.1-" : "228.24-"
},
{
  "categories": [ "Safety Bollard - Damaged/Missing" ],
  "layer_name": "Safety Bollard",
  "layer": 233,
  "version": "233.27-"
},
];

// make sure we fire the code to check if an asset is selected if
// we change options in the Highways England message
$(fixmystreet).on('report_new:highways_change', function() {
    if (fixmystreet.body_overrides.get_only_send() === 'Highways England') {
        hide_responsibility_errors();
        enable_report_form();
        $('#ncc_streetlights').remove();
    } else {
        $(fixmystreet).trigger('report_new:category_change', [ $('#form_category') ]);
    }
});

// This is required so that the found/not found actions are fired on category
// select and pin move rather than just on asset select/not select.
OpenLayers.Layer.NCCVectorAsset = OpenLayers.Class(OpenLayers.Layer.VectorAsset, {
    initialize: function(name, options) {
        OpenLayers.Layer.VectorAsset.prototype.initialize.apply(this, arguments);
        $(fixmystreet).on('maps:update_pin', this.checkSelected.bind(this));
        $(fixmystreet).on('report_new:category_change', this.checkSelected.bind(this));
    },

    CLASS_NAME: 'OpenLayers.Layer.NCCVectorAsset'
});

// default options for northants assets include
// a) checking for multiple assets in same location
// b) preventing submission unless an asset is selected
var northants_defaults = $.extend(true, {}, fixmystreet.assets.alloy_defaults, {
  class: OpenLayers.Layer.NCCVectorAsset,
  protocol_class: OpenLayers.Protocol.Alloy,
  http_options: {
      environment: is_live ? 26 : 28
  },
  non_interactive: false,
  body: "Northamptonshire County Council",
  attributes: {
    asset_resource_id: function() {
      return this.fid;
    }
  },
  select_action: true,
  actions: {
    asset_found: function(asset) {
      var emergency_state = ncc_is_emergency_category();
      if (emergency_state.relevant && !emergency_state.body) {
          return;
      }
      hide_responsibility_errors();
      enable_report_form();
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
              $p.prependTo('#js-post-category-messages');
          }
          $p.find(".overlapping_item_name").text(this.fixmystreet.asset_item);
          $p.removeClass('hidden');
      } else {
          $("#overlapping_features_msg").addClass('hidden');
      }

    },
    asset_not_found: function() {
      $("#overlapping_features_msg").addClass('hidden');
      var emergency_state = ncc_is_emergency_category();

      disable_report_form();
      if ((!emergency_state.relevant || emergency_state.body) && this.visibility) {
          show_responsibility_error('#js-not-an-asset', this.fixmystreet.asset_item, this.fixmystreet.asset_type);
      } else {
          hide_responsibility_errors();
      }
    }
  }
});

$.each(layers, function(index, layer) {
    if ( layer.categories ) {
        fixmystreet.assets.add($.extend(true, {}, northants_defaults, {
            http_options: {
              layerid: layer.layer,
              layerVersion: layer.version,
            },
            asset_type: layer.asset_type || 'spot',
            asset_category: layer.categories,
            asset_item: layer.item_name || layer.layer_name.toLowerCase(),
        }));
    }
});

// NCC roads layers which prevent report submission unless we have selected
// an asset.
var northants_road_defaults = $.extend(true, {}, fixmystreet.assets.alloy_defaults, {
    protocol_class: OpenLayers.Protocol.Alloy,
    http_options: {
        environment: is_live ? 26 : 28
    },
    body: "Northamptonshire County Council",
    road: true,
    always_visible: false,
    non_interactive: true,
    no_asset_msg_id: '#js-not-a-road',
    usrn: {
        attribute: 'fid',
        field: 'asset_resource_id'
    },
    getUSRN: function(feature) {
      return feature.fid;
    },
    actions: {
        found: function(layer, feature) {
            var emergency_state = ncc_is_emergency_category();
            if (!emergency_state.relevant || emergency_state.body) {
                enable_report_form();
            }
            hide_responsibility_errors();
        },
        not_found: function(layer) {
            // don't show the message if clicking on a highways england road
            var emergency_state = ncc_is_emergency_category();
            if (fixmystreet.body_overrides.get_only_send() == 'Highways England' || !layer.visibility) {
                if (!emergency_state.relevant || emergency_state.body) {
                    enable_report_form();
                }
                hide_responsibility_errors();
            } else {
                disable_report_form();
                if (!emergency_state.relevant || emergency_state.body) {
                    show_responsibility_error(layer.fixmystreet.no_asset_msg_id);
                } else {
                    hide_responsibility_errors();
                }
            }
        },
    }
});


fixmystreet.assets.add($.extend(true, {}, northants_road_defaults, {
    http_options: {
      layerid: 221,
      layerVersion: '221.4-',
    },
    no_asset_msg_id: '#js-not-a-speedhump',
    asset_type: "area",
    asset_category: [
        "Damaged Speed Humps",
    ]
}));

var barrier_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#555555",
    strokeOpacity: 1,
    strokeWidth: 4
});

fixmystreet.assets.add($.extend(true, {}, northants_road_defaults, {
    http_options: {
      layerid: 230,
      layerVersion: '230.3-',
    },
    stylemap: new OpenLayers.StyleMap({
        'default': barrier_style
    }),
    no_asset_msg_id: '#js-not-a-ped-barrier',
    asset_category: [
        "Pedestrian Barriers - Damaged / Missing",
    ]
}));

var highways_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#111111",
    strokeOpacity: 0.1,
    strokeWidth: 7
});

fixmystreet.assets.add($.extend(true, {}, northants_road_defaults, {
    protocol_class: OpenLayers.Protocol.Alloy,
    http_options: {
      layerid: is_live ? 20 : 308,
      layerVersion: is_live ? '20.123-' : '308.8-',
    },
    stylemap: new OpenLayers.StyleMap({
        'default': highways_style
    }),
    asset_category: [
        "Loose / Raised/Sunken",
        "Broken / Missing",
        "Blocked - flooding private property",
        "Blocked - flooding road/path",
        "Blocked/Damaged",
        "Blocked Ditch",
        "Blocked Ditch Causing Flooding",
        "Obstruction (Not Vegetation)",
        "Pothole / Failed Reinstatement",
        "Slabs - Uneven / Damaged / Cracked",
        "Slabs - Missing",
        "Damaged/Loose",
        "Missing",
        "Crash Barriers - Damaged / Missing",
        "Road Markings - Worn/Faded",
        "Flooding",
        "Mud on Road",
        "Potholes / Highway Condition",
        "Spill - Oil/Diesel",
        "Damaged/Missing",
        "Weeds",
        "Verges - Damaged by Vehicles",
        "Icy Footpath",
        "Icy Road",
        "Missed published Gritted Route",
        "Restricted Visibility / Overgrown / Overhanging",
        "Restricted Visibility",
    ]
}));


var prow_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#115511",
    strokeOpacity: 0.1,
    strokeWidth: 7
});

fixmystreet.assets.add($.extend(true, {}, northants_road_defaults, {
    http_options: {
      layerid: 173,
      layerVersion: '173.1-',
    },
    stylemap: new OpenLayers.StyleMap({
        'default': prow_style
    }),
    no_asset_msg_id: "#js-not-a-prow",
    asset_category: [
      "Livestock",
      "Passage-Obstructed/Overgrown"
    ]
}));

function ncc_is_emergency_category() {
    var relevant_body = OpenLayers.Util.indexOf(fixmystreet.bodies, northants_defaults.body) > -1;
    var relevant_cat = !!$('label[for=form_emergency]').length;
    var relevant = relevant_body && relevant_cat;
    var currently_shown = !!$('#northants-emergency-message').length;
    var body = $('#form_category').data('body');

    return {relevant: relevant, currently_shown: currently_shown, body: body};
}

// Hide form when emergency category used
function check_emergency() {
    var state = ncc_is_emergency_category();

    if (state.relevant === state.currently_shown || state.body || fixmystreet.body_overrides.get_only_send() == 'Highways England') {
        // Either should be shown and already is, or shouldn't be shown and isn't
        return;
    }

    if (!state.relevant) {
        $('#northants-emergency-message').remove();
        if ( !$('#js-roads-responsibility').is(':visible') ) {
            $('.js-hide-if-invalid-category').show();
        }
        return;
    }

    var $msg = $('<div class="box-warning" id="northants-emergency-message"></div>');
    $msg.html($('label[for=form_emergency]').html());
    $msg.insertBefore('#js-post-category-messages');
    $('.js-hide-if-invalid-category').hide();
}
$(fixmystreet).on('report_new:category_change', check_emergency);

function ncc_check_streetlights() {
    var relevant_body = OpenLayers.Util.indexOf(fixmystreet.bodies, northants_defaults.body) > -1;
    var relevant_cat = $('#form_category').val() == 'Street lighting';
    var relevant = relevant_body && relevant_cat;
    var currently_shown = !!$('#ncc_streetlights').length;

    if (relevant === currently_shown || fixmystreet.body_overrides.get_only_send() == 'Highways England') {
        return;
    }

    if (!relevant) {
        $('#ncc_streetlights').remove();
        return;
    }

    var $msg = $('<p id="ncc_streetlights" class="box-warning">Street lighting in Northamptonshire is maintained by Balfour Beatty on behalf of the County Council under a Street Lighting Private Finance Initiative (PFI) contract. Please view our <b><a href="https://www3.northamptonshire.gov.uk/councilservices/northamptonshire-highways/roads-and-streets/Pages/street-lighting.aspx">Street Lighting</a></b> page to report any issues.</p>');
    $msg.insertBefore('#js-post-category-messages');
    disable_report_form();
}
$(fixmystreet).on('report_new:category_change', ncc_check_streetlights);

})();
