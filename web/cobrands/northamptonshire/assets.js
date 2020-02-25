(function(){

if (!fixmystreet.maps) {
    return;
}

var is_live = !fixmystreet.staging;

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
  "categories": [
        "Loose / Raised/Sunken",
        "Broken / Missing",
        "Blocked - flooding private property",
        "Blocked - flooding road/path",
        "Blocked/Damaged",
  ],
  "item_name": "drain",
  "layer_name": "Gully",
  "layer": 66,
  "version": "66.80-",
  "max_resolution": 0.5971642833948135
},
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
  "version": "14.7-"
},
{
  "categories": [ "Damaged / Missing / Facing Wrong Way", "Obscured by vegetation or Dirty" ],
  "item_name": "sign",
  "layer_name": "Signs",
  "layer": is_live ? 60 : 303,
  "version": is_live ? "60.2172-" : "303.1-"
},
{
  "categories": [ "Shelter Damaged", "Sign/Pole Damaged" ],
  "layer_name": "Bus Stop",
  "layer": 72,
  "version": "72.14-"
},
{
  "categories": [ "Bridge-Damaged/ Missing" ],
  "item_name": "bridge or right of way",
  "layer_name": "BRIDGES",
  "layer": 177,
  "version": "177.40-"
},
{
  "categories": [ "Gate - Damaged/ Missing" ],
  "item_name": "gate or right of way",
  "layer_name": "GATE",
  "layer": 181,
  "version": "181.14-"
},
{
  "categories": [ "Stile-Damaged/Missing" ],
  "item_name": "stile or right of way",
  "layer_name": "STILE",
  "layer": 185,
  "version": "185.10-"
},
{
  "categories": [ "Sign/Waymarking - Damaged/Missing" ],
  "item_name": "waymarking or right of way",
  "layer_name": "WAYMARK POST",
  "layer": 187,
  "version": "187.10-"
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
    "Signal Failure/Damaged - Toucan/Pelican"
  ],
  "item_name": "signal or crossing",
  "layer_name": "Midblock",
  "layer": 223,
  "version": "223.2-"
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
    "Signal Failure/Damaged - Toucan/Pelican"
  ],
  "item_name": "signal or crossing",
  "layer_name": "TL Junction",
  "layer": 225,
  "version": "225.5-"
},
{
  "categories": [
      "Fallen Tree",
      "Restricted Visibility / Overgrown / Overhanging",
      "Restricted Visibility"
  ],
  "layer_name": "Tree",
  "layer": 307,
  "version": "307.7-",
  "snap_threshold": 0,
},
{
  "categories": [ "Safety Bollard - Damaged/Missing" ],
  "layer_name": "Safety Bollard",
  "layer": 233,
  "version": "233.28-"
},
];

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

OpenLayers.Layer.NCCVectorNearest = OpenLayers.Class(OpenLayers.Layer.VectorNearest, {
    feature_table: {},
    initialize: function(name, options) {
        OpenLayers.Layer.VectorNearest.prototype.initialize.apply(this, arguments);
        this.events.register('beforefeatureadded', this, this.checkCanAddFeature);
    },

    destroyFeatures: function(features, options) {
        OpenLayers.Layer.VectorNearest.prototype.destroyFeatures.apply(this, arguments);
        this.feature_table = {};
    },

    checkCanAddFeature: function(obj) {
      if (this.feature_table[obj.feature.fid]) {
        return false;
      }

      this.feature_table[obj.feature.fid] = 1;
    },

    CLASS_NAME: 'OpenLayers.Layer.NCCVectorNearest'
});

// default options for northants assets include
// a) checking for multiple assets in same location
// b) preventing submission unless an asset is selected
var northants_defaults = $.extend(true, {}, fixmystreet.alloy_defaults, {
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
      if (fixmystreet.message_controller.asset_found()) {
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
      fixmystreet.message_controller.asset_not_found.call(this);
    }
  }
});

$.each(layers, function(index, layer) {
    if ( layer.categories ) {
        var options = {
          http_options: {
            layerid: layer.layer,
            layerVersion: layer.version,
          },
          asset_type: layer.asset_type || 'spot',
          asset_category: layer.categories,
          asset_item: layer.item_name || layer.layer_name.toLowerCase(),
        };
        if (layer.max_resolution) {
          options.max_resolution = layer.max_resolution;
        }
        if (layer.snap_threshold || layer.snap_threshold === 0) {
          options.snap_threshold = layer.snap_threshold;
        }
        fixmystreet.assets.add(northants_defaults, options);
    }
});

// NCC roads layers which prevent report submission unless we have selected
// an asset.
var northants_road_defaults = $.extend(true, {}, fixmystreet.alloy_defaults, {
    class: OpenLayers.Layer.NCCVectorNearest,
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
        field: 'asset_resource_id'
    },
    getUSRN: function(feature) {
      return feature.fid;
    },
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: fixmystreet.message_controller.road_not_found
    }
});


fixmystreet.assets.add(northants_road_defaults, {
    http_options: {
      layerid: 221,
      layerVersion: '221.4-',
    },
    no_asset_msg_id: '#js-not-an-asset',
    asset_item: 'speed hump',
    asset_type: "area",
    asset_category: [
        "Damaged Speed Humps"
    ]
});

var barrier_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#555555",
    strokeOpacity: 1,
    strokeWidth: 4
});

fixmystreet.assets.add(northants_road_defaults, {
    http_options: {
      layerid: is_live ? 1068 : 230,
      layerVersion: is_live ? '1068.1-' : '230.4-',
    },
    stylemap: new OpenLayers.StyleMap({
        'default': barrier_style
    }),
    no_asset_msg_id: '#js-not-an-asset',
    asset_item: 'pedestrian barrier',
    asset_type: 'area',
    asset_category: [
        "Pedestrian Barriers - Damaged / Missing"
    ]
});

var highways_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#111111",
    strokeOpacity: 0.1,
    strokeWidth: 7
});

fixmystreet.assets.add(northants_road_defaults, {
    protocol_class: OpenLayers.Protocol.Alloy,
    http_options: {
      layerid: 20,
      layerVersion: '20.249-',
    },
    stylemap: new OpenLayers.StyleMap({
        'default': highways_style
    }),
    asset_category: [
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
        "Fallen Tree",
        "Restricted Visibility / Overgrown / Overhanging",
        "Restricted Visibility"
    ]
});


function ncc_match_prow_type(f, styleId) {
    return f &&
           f.attributes &&
           f.attributes.layerStyleId &&
           f.attributes.layerStyleId == styleId;
}

function ncc_prow_is_fp(f) {
    return ncc_match_prow_type(f, is_live ? 6190 : 1454);
}

function ncc_prow_is_bw(f) {
    return ncc_match_prow_type(f, is_live ? 6192 : 1453);
}

function ncc_prow_is_boat(f) {
    return ncc_match_prow_type(f, is_live ? 6193: 1455);
}

var rule_footpath = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: ncc_prow_is_fp
    }),
    symbolizer: {
        strokeColor: "#800000",
    }
});
var rule_boat = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: ncc_prow_is_boat
    }),
    symbolizer: {
        strokeColor: "#964b00",
    }
});
var rule_bridleway = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: ncc_prow_is_bw
    }),
    symbolizer: {
        strokeColor: "#008000",
    }
});

var prow_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#115511",
    strokeOpacity: 0.8,
    strokeWidth: 7
});

prow_style.addRules([rule_footpath, rule_boat, rule_bridleway]);

fixmystreet.assets.add(northants_road_defaults, {
    http_options: {
      layerid: is_live ? 1110 : 310,
      layerVersion: is_live ? '1110.1-' : '310.1-',
    },
    stylemap: new OpenLayers.StyleMap({
        'default': prow_style
    }),
    no_asset_msg_id: "#js-not-a-road",
    asset_item: 'right of way',
    asset_category: [
      "Bridge-Damaged/ Missing",
      "Gate - Damaged/ Missing",
      "Livestock",
      "Passage-Obstructed/Overgrown",
      "Sign/Waymarking - Damaged/Missing",
      "Stile-Damaged/Missing"
    ]
});

fixmystreet.message_controller.add_ignored_body(northants_defaults.body);

})();
