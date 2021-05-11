(function(){

if (!fixmystreet.maps) {
    return;
}

/** These layers are from the Hackney WFS feed, for non-Alloy categories: */
var wfs_defaults = {
  http_options: {
    url: 'https://map2.hackney.gov.uk/geoserver/ows',
    params: {
        SERVICE: "WFS",
        VERSION: "1.1.0",
        REQUEST: "GetFeature",
        SRSNAME: "urn:ogc:def:crs:EPSG::27700"
    }
},
  asset_type: 'spot',
  max_resolution: 2.388657133579254,
  asset_id_field: 'id',
  attributes: {},
  geometryName: 'geom',
  srsName: "EPSG:27700",
  strategy_class: OpenLayers.Strategy.FixMyStreet,
  body: "Hackney Council",
  asset_item: "item"
};


fixmystreet.assets.add(wfs_defaults, {
  http_options: {
      params: {
          TYPENAME: "parking:inventory_pay_and_display_machine",
      }
  },
  asset_category: "Pay & Display Machines",
  attributes: {}
});

fixmystreet.assets.add(wfs_defaults, {
  http_options: {
      params: {
          TYPENAME: "transport:bike_hangar",
      }
  },
  asset_category: "Cycle Hangars",
  attributes: {}
});


/** These layers are served directly from Alloy: */

// View all layers with something like:
// curl https://tilma.staging.mysociety.org/resource-proxy/proxy.php\?https://hackney.assets/ | jq '.results[] | .layer.code, ( .layer.styles[] | { id, name } ) '
var layers = [
  {
    "categories": ["Street Lighting", "Lamposts"],
    "item_name": "street light",
    "layer_name": "Street Lights",
    "styleid": "5d308d57fe2ad8046c67cdb5",
    "layerid": "layers_streetLightingAssets"
  },
  {
    "categories": ["Illuminated Bollards", "Non-illuminated Bollards"],
    "item_name": "bollard",
    "layer_name": "Bollards",
    "styleid": "5d308d57fe2ad8046c67cdb9",
    "layerid": "layers_streetLightingAssets"
  },
  {
    "categories": ["Benches"],
    "item_name": "bench",
    "layer_name": "Bench",
    "styleid": "5e8b16f0ca31500f60b3f589",
    "layerid": "layers_bench_5e8b15f0ca31500f60b3f568"
  },
  {
    "categories": ["Potholes"],
    "item_name": "road",
    "layer_name": "Carriageway",
    "styleid": "5d53d28bfe2ad80fc4573184",
    "layerid": "layers_carriageway_5d53cc74fe2ad80c3403b77d"
  },
  {
    "categories": ["Road Markings / Lines"],
    "item_name": "road",
    "layer_name": "Markings",
    "styleid": "5d308dd7fe2ad8046c67da33",
    "layerid": "layers_highwayAssets"
  },
  {
    "categories": ["Pavement"],
    "item_name": "pavement",
    "layer_name": "Footways",
    "styleid": "5d308dd6fe2ad8046c67da2a",
    "layerid": "layers_highwayAssets"
  },
  {
    "categories": ["Cycle Tracks"],
    "item_name": "cycle track",
    "layer_name": "Cycle Tracks",
    "styleid": "5d308dd6fe2ad8046c67da29",
    "layerid": "layers_highwayAssets"
  },
  {
    "categories": ["Drains and gutters"],
    "item_name": "drain",
    "layer_name": "Gullies",
    "styleid": "5d308dd6fe2ad8046c67da2e",
    "layerid": "layers_highwayAssets"
  },
  {
    "categories": ["Verges"],
    "item_name": "verge",
    "layer_name": "Verges",
    "styleid": "5d308dd7fe2ad8046c67da36",
    "layerid": "layers_highwayAssets"
  },
  {
    "categories": ["Road Hump Fault / Damage"],
    "item_name": "road hump",
    "layer_name": "Traffic Calming",
    "styleid": "5d308dd7fe2ad8046c67da35",
    "layerid": "layers_highwayAssets"
  },
  {
    "categories": ["Broken or Faulty Barrier Gates"],
    "item_name": "barrier gate",
    "layer_name": "Gates",
    "styleid": "5d308dd6fe2ad8046c67da2c",
    "layerid": "layers_highwayAssets"
  },
  {
    "categories": ["Belisha Beacon"],
    "item_name": "beacon",
    "layer_name": "Belisha Beacon",
    "styleid": "5d308d57fe2ad8046c67cdb6",
    "layerid": "layers_streetLightingAssets"
  },
  {
    "categories": ["Loose or Damaged Kerb Stones"],
    "item_name": "kerb",
    "layer_name": "Kerbs",
    "styleid": "5d308dd6fe2ad8046c67da30",
    "layerid": "layers_highwayAssets"
  }
];

var base = fixmystreet.staging ? "https://tilma.staging.mysociety.org" : "https://tilma.mysociety.org";
var hackney_defaults = $.extend(true, {}, fixmystreet.alloyv2_defaults, {
  class: OpenLayers.Layer.AlloyVectorAsset,
  protocol_class: OpenLayers.Protocol.AlloyV2,
  http_options: {
    base: base + "/resource-proxy/proxy.php?https://hackney.assets/${layerid}/${x}/${y}/${z}/cluster?styleIds=${styleid}"
  },
  non_interactive: false,
  body: "Hackney Council",
  attributes: {
    asset_resource_id: function() {
      return this.fid;
    }
  }
});

fixmystreet.alloy_add_layers(hackney_defaults, layers);

})();
