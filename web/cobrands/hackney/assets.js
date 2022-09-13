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
    "layerid": "designs_streetLights"
  },
  {
    "categories": ["Illuminated Bollards", "Non-illuminated Bollards"],
    "item_name": "bollard",
    "layerid": "designs_bollards"
  },
  {
    "categories": ["Benches"],
    "item_name": "bench",
    "layerid": "designs_bench1000793_5d31996bfe2ad80354bb9f25"
  },
  {
    "categories": ["Potholes"],
    "item_name": "road",
    "layerid": "designs_carriageway_5d53cc6afe2ad80fc4572c23"
  },
  {
    "categories": ["Road Markings / Lines"],
    "item_name": "road",
    "layerid": "designs_markings"
  },
  {
    "categories": ["Pavement"],
    "item_name": "pavement",
    "layerid": "designs_footways"
  },
  {
    "categories": ["Cycle Tracks"],
    "item_name": "cycle track",
    "layerid": "designs_cycleTracks"
  },
  {
    "categories": ["Drains and gutters"],
    "item_name": "drain",
    "layerid": "designs_gullies"
  },
  {
    "categories": ["Verges"],
    "item_name": "verge",
    "layerid": "designs_verges"
  },
  {
    "categories": ["Road Hump Fault / Damage"],
    "item_name": "road hump",
    "layerid": "designs_trafficCalmings"
  },
  {
    "categories": ["Broken or Faulty Barrier Gates"],
    "item_name": "barrier gate",
    "layerid": "designs_gates"
  },
  {
    "categories": ["Belisha Beacon"],
    "item_name": "beacon",
    "layerid": "designs_belishaBeacons"
  },
  {
    "categories": ["Loose or Damaged Kerb Stones"],
    "item_name": "kerb",
    "layerid": "designs_kerbs"
  },
  {
    "host": 'https://hackney-env.assets',
    "categories": ["Gully"],
    "item_name": "gully",
    "layerid": "designs_gullies"
  }
];

var tilma_host = fixmystreet.staging ? "https://tilma.staging.mysociety.org" : "https://tilma.mysociety.org";
var tilma_url = tilma_host + "/alloy/layer.php?url=";

var hackney_defaults = $.extend(true, {}, {
  format_class: OpenLayers.Format.GeoJSON,
  srsName: "EPSG:4326",
  class: OpenLayers.Layer.VectorAssetMove,
  strategy_class: OpenLayers.Strategy.FixMyStreet,
  non_interactive: false,
  body: "Hackney Council",
  attributes: {
    asset_resource_id: "itemId"
  }
});

$.each(layers, function(_index, layer) {
  var host = layer.host ? layer.host : 'https://hackney.assets';
  var options = $.extend(true, {}, hackney_defaults, {
    http_options: {
      url: tilma_url + host + '&layer=' + layer.layerid
    },
    asset_category: layer.categories,
    asset_item: layer.item_name
  });
  fixmystreet.assets.add(options, layer);
});

})();
