(function(){

if (!fixmystreet.maps) {
    return;
}

var layers = [
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
  "max_resolution": 0.5971642833948135
},
{
  "categories": [ "Grit Bin - damaged/replacement", "Grit Bin - empty/refill" ],
  "item_name": "grit bin",
  "layer_name": "GritBins"
},
{
  "categories": [ "Highway Bridges - Damaged/Unsafe" ],
  "item_name": 'bridge',
  "layer_name": "Structures"
},
{
  "categories": [ "Damaged / Missing / Facing Wrong Way", "Obscured by vegetation or Dirty" ],
  "item_name": "sign",
  "layer_name": "Sign"
},
{
  "categories": [ "Shelter Damaged", "Sign/Pole Damaged" ],
  "layer_name": "Bus_Stop"
},
{
  "categories": [
      "Fallen Tree",
      "Restricted Visibility / Overgrown / Overhanging",
      "Restricted Visibility"
  ],
  "layer_name": "Tree",
  "snap_threshold": 0
},
{
  "categories": [ "Safety Bollard - Damaged/Missing" ],
  "layer_name": "Safety_Bollard"
},
{
  "categories": [ "Bridge-Damaged/ Missing" ],
  "item_name": "bridge or right of way",
  "layer_name": "Bridges"
},
{
  "categories": [ "Gate - Damaged/ Missing" ],
  "item_name": "gate or right of way",
  "layer_name": "Gates"
},
{
  "categories": [ "Stile-Damaged/Missing" ],
  "item_name": "stile or right of way",
  "layer_name": "Stile"
},
{
  "categories": [ "Sign/Waymarking - Damaged/Missing" ],
  "item_name": "waymarking or right of way",
  "layer_name": "Waymarker"
},
{
  "categories": [
// Old
    "Lamp/Bulb Failure",
    "Signal Failure",
    "Signal Failure all out",
    "Signal Stuck",
    "Signal Head Failure",
    "Damaged Control box",
    "Signal Failure/Damaged - Toucan/Pelican",
// New
    "All Traffic Signals OUT (Not Working)",
    "Damaged/Exposed Wiring / Vandalised",
    "Lamp Failure",
    "Pushbutton Not Working",
    "Request Timing Review",
    "Signal Stuck / Not Changing"
  ],
  "item_name": "signal or crossing",
  "layer_name": "Traffic_Signal_Junction"
},
{
  "categories": [ "Pedestrian Barriers - Damaged / Missing" ],
  "item_name": "pedestrian barrier",
  "layer_name": "Pedestrian_Barrier"
}
];

// default options for northants assets include
// a) checking for multiple assets in same location
// b) preventing submission unless an asset is selected
var northants_defaults = {
  wfs_url: fixmystreet.staging ? "https://tilma.staging.mysociety.org/mapserver/northamptonshire" : "https://tilma.mysociety.org/mapserver/northamptonshire",
  geometryName: 'msGeometry',
  srsName: "EPSG:3857",
  non_interactive: false,
  body: "Northamptonshire Highways",
  attributes: {
    asset_resource_id: "asset_id"
  },
  select_action: true,
  actions: {
    asset_found: function(asset) {
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
    },
    asset_not_found: function() {
      $("#overlapping_features_msg").addClass('hidden');
      if (this.fixmystreet.snap_threshold === 0) {
          // Not a typo, asset selection is not mandatory
          fixmystreet.message_controller.asset_found.call(this);
      } else {
          fixmystreet.message_controller.asset_not_found.call(this);
      }
    }
  }
};

$.each(layers, function(_index, layer) {
  if (!layer.item_name) {
    layer.item_name = layer.layer_name.replace(/_/g, ' ').toLowerCase();
  }
  var options = $.extend(true, {}, northants_defaults, {
    // Declare the class here rather than in the defaults above so it doesn't
    // affect the road defaults below, which can use the default roads class.
    class: OpenLayers.Layer.VectorAssetMove,
    wfs_feature: layer.layer_name,
    asset_category: layer.categories,
    asset_item: layer.item_name
  });
  fixmystreet.assets.add(options, layer);
});

// NCC roads layers which prevent report submission unless we have selected
// an asset.
var northants_road_defaults = $.extend(true, {}, northants_defaults, {
    road: true,
    always_visible: false,
    non_interactive: true,
    no_asset_msg_id: '#js-not-a-road',
    usrn: {
        attribute: 'asset_id',
        field: 'asset_resource_id'
    },
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: fixmystreet.message_controller.road_not_found
    }
});

fixmystreet.assets.add(northants_road_defaults, {
    wfs_feature: "Traffic_Calming",
    no_asset_msg_id: '#js-not-an-asset',
    asset_item: 'speed hump',
    asset_type: "area",
    asset_category: [
        "Damaged Speed Humps"
    ]
});

var highways_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#111111",
    strokeOpacity: 0.1,
    strokeWidth: 7
});

fixmystreet.assets.add(northants_road_defaults, {
    wfs_feature: "Carriageway",
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

var prow_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#115511",
    strokeOpacity: 0.8,
    strokeWidth: 7
});

fixmystreet.assets.add(northants_road_defaults, {
    wfs_feature: "PRoW_Network",
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
