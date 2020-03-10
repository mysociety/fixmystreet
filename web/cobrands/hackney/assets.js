(function(){

if (!fixmystreet.maps) {
    return;
}

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
    "categories": ["Illuminated Bollards"],
    "item_name": "bollard",
    "layer_name": "Bollards",
    "styleid": "5d308d57fe2ad8046c67cdb9",
    "layerid": "layers_streetLightingAssets"
  },
  {
    "categories": ["Potholes"],
    "item_name": "road",
    "layer_name": "Carriageway",
    "styleid": "5d53d28bfe2ad80fc4573184",
    "layerid": "layers_carriageway_5d53cc74fe2ad80c3403b77d"
  },
  {
    "categories": ["Pavement"],
    "item_name": "pavement",
    "layer_name": "Footways",
    "styleid": "5d308dd6fe2ad8046c67da2a",
    "layerid": "layers_highwayAssets"
  },
  {
    "categories": ["Drains and gutters"],
    "item_name": "drain",
    "layer_name": "Gullies",
    "styleid": "5d308dd6fe2ad8046c67da2e",
    "layerid": "layers_highwayAssets"
  }
];

var hackney_defaults = $.extend(true, {}, fixmystreet.alloyv2_defaults, {
  class: OpenLayers.Layer.NCCVectorAsset,
  protocol_class: OpenLayers.Protocol.AlloyV2,
  http_options: {},
  non_interactive: false,
  body: "Hackney Council",
  attributes: {
    asset_resource_id: function() {
      return this.fid;
    }
  }
});

$.each(layers, function(index, layer) {
    if ( layer.categories && layer.styleid ) {
        var options = {
          http_options: {
            base: "https://tilma.staging.mysociety.org/resource-proxy/proxy.php?https://hackney.assets/${layerid}/${x}/${y}/${z}/cluster?styleIds=${styleid}",
            styleid: layer.styleid,
            layerid: layer.layerid,
          },
          asset_type: layer.asset_type || "spot",
          asset_category: layer.categories,
          asset_item: layer.item_name || layer.layer_name.toLowerCase(),
        };
        if (layer.max_resolution) {
          options.max_resolution = layer.max_resolution;
        }
        if (layer.snap_threshold || layer.snap_threshold === 0) {
          options.snap_threshold = layer.snap_threshold;
        }
        fixmystreet.assets.add(hackney_defaults, options);
    }
});

})();
