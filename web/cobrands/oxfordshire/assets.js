(function(){

if (!fixmystreet.maps) {
    return;
}

var tilma_url = "https://tilma.staging.mysociety.org/mapserver/oxfordshire";
var proxy_base_url = "https://tilma.staging.mysociety.org/proxy/occ/";
if ( location.hostname === 'www.fixmystreet.com' || location.hostname == 'fixmystreet.oxfordshire.gov.uk' ) {
    tilma_url = "https://tilma.mysociety.org/mapserver/oxfordshire";
    proxy_base_url = "https://tilma.mysociety.org/proxy/occ/";
}

var defaults = {
    wfs_url: tilma_url,
    asset_type: 'spot',
    max_resolution: 4.777314267158508,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "Oxfordshire County Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add(defaults, {
    wfs_feature: "Trees",
    asset_id_field: 'Ref',
    attributes: {
        feature_id: 'Ref'
    },
    asset_category: ["Trees"],
    asset_item: 'tree'
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "Traffic_Lights",
    asset_id_field: 'Site',
    attributes: {
        feature_id: 'Site'
    },
    asset_category: ["Traffic Lights (permanent only)"],
    asset_item: 'traffic light'
});

var streetlight_select = $.extend({
    label: "${UNITNO}",
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

fixmystreet.assets.add(defaults, {
    select_action: true,
    stylemap: streetlight_stylemap,
    wfs_feature: "Street_Lights",
    asset_id_field: 'OBJECTID',
    attributes: {
        feature_id: 'OBJECTID',
        column_no: 'UNITNO'
    },
    asset_category: ["Street lighting"],
    asset_item: 'street light',
    actions: {
        asset_found: function(asset) {
          var id = asset.attributes.UNITNO || '';
          if (id !== '') {
              $('.category_meta_message').html('You have selected ' + this.fixmystreet.asset_item + ' <b>' + id + '</b>');
          } else {
              $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
          }
        },
        asset_not_found: function() {
           $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
        }
    }
});

fixmystreet.assets.add(defaults, {
    // have to do this by hand rather than using wfs_* options
    // as the server does not like being POSTed xml with application/xml
    // as the Content-Type which is what using those options results in.
    http_options: {
        headers: {
            'Content-Type': 'text/plain'
        },
        url: proxy_base_url + 'drains/wfs',
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700",
            TYPENAME: "junctions"
        }
    },
    srsName: "EPSG:27700",
    asset_id_field: 'id',
    attributes: {
        feature_id: 'id'
    },
    asset_category: ["Gully and Catchpits"],
    asset_item: 'drain'
});

})();
