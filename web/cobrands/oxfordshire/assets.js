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
    asset_id_field: 'UNITID',
    attributes: {
        feature_id: 'UNITID',
        column_no: 'UNITNO'
    },
    asset_category: ["Street lighting"],
    asset_item: 'street light',
    feature_code: 'UNITNO',
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

var owned_defaults = $.extend({}, defaults, {
    stylemap: occ_stylemap,
    // have to do this by hand rather than using wfs_* options
    // as the server does not like being POSTed xml with application/xml
    // as the Content-Type which is what using those options results in.
    http_options: {
        headers: {
            'Content-Type': 'text/plain'
        },
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700",
            propertyName: 'id,maintained_by,msGeometry'
        }
    },
    srsName: "EPSG:27700",
    asset_id_field: 'id',
    attributes: {
        feature_id: 'id'
    }
});

fixmystreet.assets.add(owned_defaults, {
    http_options: {
        url: proxy_base_url + 'drains/wfs',
        params: {
            TYPENAME: "junctions"
        }
    },
    asset_category: ["Gully and Catchpits"],
    asset_item: 'drain'
});

fixmystreet.assets.add(owned_defaults, {
    http_options: {
        url: proxy_base_url + 'grit/wfs',
        params: {
            TYPENAME: "Grit_bins"
        }
    },
    asset_category: ["Ice/Snow"],
    asset_item: 'grit bin'
});

var road_occ_maintainable = 'Maintainable at Public Expense';

function road_owned(f) {
    return f &&
           f.attributes &&
           f.attributes.STREET_MAINTENANCE_RESPONSIBILITY_NAME &&
           f.attributes.STREET_MAINTENANCE_RESPONSIBILITY_NAME.lastIndexOf(road_occ_maintainable, 0) === 0;
}

fixmystreet.assets.add(defaults, {
    stylemap: fixmystreet.assets.stylemap_invisible,
    wfs_url: proxy_base_url + 'nsg/',
    wfs_feature: "WFS_STREETS_CLASSIFIED_ROADS_INTERESTS",
    propertyNames: ['TYPE1_2_USRN', 'STREET_MAINTENANCE_RESPONSIBILITY_NAME', 'SHAPE_GEOMETRY'],
    srsName: "EPSG:27700",
    geometryName: null,
    usrn: {
        attribute: 'TYPE1_2_USRN',
        field: 'usrn'
    },
    non_interactive: true,
    road: true,
    no_asset_msg_id: '#js-not-a-road',
    asset_item: 'road',
    asset_type: 'road',
    actions: {
        found: function(layer, feature) {
            fixmystreet.message_controller.road_found(layer, feature, road_owned, '#js-not-a-road');
        },
        not_found: fixmystreet.message_controller.road_not_found
    },
    asset_category: [
        "Bridges",
        "Carriageway Defect",
        "Current Roadworks",
        "Drainage",
        "Gully and Catchpits",
        "Highway Schemes",
        "Ice/Snow",
        "Manhole",
        "Pavements",
        "Pothole",
        "Road Traffic Signs and Road Markings",
        "Roads/highways",
        "Street lighting",
        "Traffic Lights (permanent only)",
        "Trees"
    ]
});

})();
