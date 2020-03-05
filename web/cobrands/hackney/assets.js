(function(){

if (!fixmystreet.maps) {
    return;
}

var layers = [
  {
    "categories": ["Street Lighting"],
    "item_name": "street light",
    "layer_name": "Street Lights",
    "styleid": '5d308d57fe2ad8046c67cdb5',
  },
];

var hackney_defaults = $.extend(true, {}, fixmystreet.alloyv2_defaults, {
  class: OpenLayers.Layer.NCCVectorAsset,
  protocol_class: OpenLayers.Protocol.AlloyV2,
  http_options: {
      layerid: 'layers_streetLightingAssets'
  },
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
            base: "https://tilma.staging.mysociety.org/resource-proxy/proxy.php?https://hackney.assets/api/layer/${layerid}/${x}/${y}/${z}/cluster?styleIds=${styleid}",
            styleid: layer.styleid,
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
        fixmystreet.assets.add(hackney_defaults, options);
    }
});

})();
