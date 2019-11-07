(function(){

if (!fixmystreet.maps) {
    return;
}

var is_live = !fixmystreet.staging;

var layers = [
/*
{
  "name": "Posts",
  "id": "5d480a68fe2ad809d85a78cf"
}
{
  "name": "Grips",
  "id": "5d480aeefe2ad8059ce44c75"
}
{
  "name": "Special Treatment",
  "id": "5d480b39fe2ad809d85a78ec"
}
{
  "name": "Channel",
  "id": "5d480b66fe2ad809d85a78f0"
}
{
  "name": "Comms Cabinet",
  "id": "5d480c01fe2ad8059ce44cd4"
}
{
  "name": "Steps",
  "id": "5d480c3bfe2ad8059ce44cda"
}
{
  "name": "Steps Handrail",
  "id": "5d4812adfe2ad809d85a7a6e"
}
{
  "name": "Tree Group",
  "id": "5d481333fe2ad809d85a7a78"
}
{
  "name": "Traffic Calming",
  "id": "5d481403fe2ad8059ce44efd"
}

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
  "styleid": '5d480b8ffe2ad809d85a78ff',
  "max_resolution": 0.5971642833948135
},
{
  "categories": [ "Grit Bin - damaged/replacement", "Grit Bin - empty/refill" ],
  "item_name": "grit bin",
  "layer_name": "Grit Bins",
  "styleid": '5d480942fe2ad809d85a78ad',
},
{
  "categories": [ "Highway Bridges - Damaged/Unsafe" ],
  "asset_type": 'area',
  "item_name": 'bridge',
  "layer_name": "Structures",
  "styleid": '5d4809fffe2ad8059ce44bbe',
},
{
  "categories": [ "Damaged / Missing / Facing Wrong Way", "Obscured by vegetation or Dirty" ],
  "item_name": "sign",
  "layer_name": "Signs",
  "styleid": '5d480a8ffe2ad809d85a78d3',
},
{
  "categories": [ "Shelter Damaged", "Sign/Pole Damaged" ],
  "layer_name": "Bus Stop",
  "styleid": '5d4812dffe2ad809d85a7a72',
},
{
  "categories": [ "Bridge-Damaged/ Missing" ],
  "item_name": "bridge or right of way",
  "layer_name": "BRIDGES",
  "styleid": "5d48161ffe2ad809d85a7add"
},
{
  "categories": [ "Gate - Damaged/ Missing" ],
  "item_name": "gate or right of way",
  "layer_name": "GATE",
  "styleid": "5d481906fe2ad8059ce450b4",
},
{
  "categories": [ "Stile-Damaged/Missing" ],
  "item_name": "stile or right of way",
  "layer_name": "STILE",
  "styleid": "5d481a05fe2ad8059ce45121",
},
{
  "categories": [ "Sign/Waymarking - Damaged/Missing" ],
  "item_name": "waymarking or right of way",
  "layer_name": "WAYMARK POST",
  "styleid": "5d481a4ffe2ad809d85a7b90"
},
/*
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
},
*/
{
  "categories": [
      "Fallen Tree",
      "Restricted Visibility / Overgrown / Overhanging",
      "Restricted Visibility"
  ],
  "layer_name": "Tree",
  "styleid": '5d481376fe2ad8059ce44ef2',
},
{
  "categories": [ "Safety Bollard - Damaged/Missing" ],
  "layer_name": "Safety Bollard",
  "styleid": "5d481446fe2ad8059ce44f02",
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
var northants_defaults = $.extend(true, {}, fixmystreet.assets.alloyv2_defaults, {
  class: OpenLayers.Layer.NCCVectorAsset,
  protocol_class: OpenLayers.Protocol.AlloyV2,
  http_options: {
      layerid: is_live ? 26 : 'layers_highwayAssetsCustom_5d4806b0fe2ad809d85a774f'
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

fixmystreet.alloy_add_layers(northants_defaults, layers);

// NCC roads layers which prevent report submission unless we have selected
// an asset.
var northants_road_defaults = $.extend(true, {}, fixmystreet.assets.alloyv2_defaults, {
    protocol_class: OpenLayers.Protocol.AlloyV2,
    http_options: {
        layerid: is_live ? 26 : 'layers_highwayAssetsCustom_5d4806b0fe2ad809d85a774f'
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
      // Traffic Calming
      styleid: "5d481403fe2ad8059ce44efd",
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
    // Pedestrian Guardrail
    http_options: {
      styleid: "5d4813c1fe2ad8059ce44ef6",
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
    protocol_class: OpenLayers.Protocol.AlloyV2,
    // Carriageways
    http_options: {
      styleid: "5d480710fe2ad8059ce44a1d",
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
      // PRoW Network
      styleid: "5d4815ebfe2ad809d85a7ac9"
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
