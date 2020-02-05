(function(){

if (!fixmystreet.maps) {
    return;
}

var wfs_host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';
var tilma_url = "https://" + wfs_host + "/mapserver/oxfordshire";
var proxy_base_url = "https://" + wfs_host + "/proxy/occ/";

var defaults = {
    wfs_url: tilma_url,
    asset_type: 'spot',
    max_resolution: 4.777314267158508,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "Oxfordshire County Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var occ_default = $.extend({}, fixmystreet.assets.style_default.defaultStyle, {
    fillColor: "#007258"
});

var occ_hover = new OpenLayers.Style({
    pointRadius: 8,
    cursor: 'pointer'
});

var occ_stylemap = new OpenLayers.StyleMap({
    'default': occ_default,
    'select': fixmystreet.assets.style_default_select,
    'hover': occ_hover
});

fixmystreet.assets.add(defaults, {
    stylemap: occ_stylemap,
    wfs_feature: "Trees",
    asset_id_field: 'Ref',
    attributes: {
        feature_id: 'Ref'
    },
    asset_category: ["Trees"],
    asset_item: 'tree'
});

fixmystreet.assets.add(defaults, {
    stylemap: occ_stylemap,
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
    fontColor: "#FFD800",
    labelOutlineColor: "black",
    labelOutlineWidth: 3,
    labelYOffset: 69,
    fontSize: '18px',
    fontWeight: 'bold'
}, fixmystreet.assets.style_default_select.defaultStyle);

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': occ_default,
  'select': new OpenLayers.Style(streetlight_select),
  'hover': occ_hover
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
    stylemap: occ_stylemap,
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

fixmystreet.assets.add(defaults, {
    stylemap: occ_stylemap,
    // have to do this by hand rather than using wfs_* options
    // as the server does not like being POSTed xml with application/xml
    // as the Content-Type which is what using those options results in.
    http_options: {
        headers: {
            'Content-Type': 'text/plain',
        },
        url: proxy_base_url + 'grit/wfs',
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700",
            TYPENAME: "Gritbins"
        }
    },
    srsName: "EPSG:27700",
    asset_id_field: 'id',
    attributes: {
        feature_id: 'id'
    },
    asset_category: ["Ice/Snow"],
    asset_item: 'grit bin'
});

var highways_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#5555FF",
    strokeOpacity: 0.1,
    strokeWidth: 7
});

fixmystreet.assets.add(defaults, {
    stylemap: new OpenLayers.StyleMap({
        'default': highways_style
    }),
    wfs_url: proxy_base_url + 'nsg/',
    wfs_feature: "WFS_LIST_OF_STREETS",
    srsName: "EPSG:27700",
    geometryName: null,
    usrn: {
        attribute: 'USRN',
        field: 'usrn'
    },
    non_interactive: true,
    road: true,
    no_asset_msg_id: '#js-not-a-road',
    asset_item: 'road',
    asset_type: 'road',
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: fixmystreet.message_controller.road_not_found
    },
    asset_category: ["Carriageway Defect", "Pavements", "Pothole"],
});

})();
