(function(){

if (!fixmystreet.maps) {
    return;
}

var wfs_host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';
var tilma_url = "https://" + wfs_host + "/mapserver/oxfordshire";
var proxy_base_url = "https://" + wfs_host + "/proxy/occ/";

var lighting_categories = [
    "Cover Hanging",
    "Door Missing",
    "Flashing Lamp",
    "Vehicle/ Accident Damage",
    "Knocked Down Bollard",
    "Lamp Appears Dim",
    "Lamp On During Day",
    "Lamp Out of Light",
    "Other",
    "Twisted Lantern"
];
var road_categories = lighting_categories.concat([
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
    "Traffic Lights (permanent only)",
    "Trees"
]);

var defaults = {
    wfs_url: tilma_url,
    asset_type: 'spot',
    max_resolution: 4.777314267158508,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "Oxfordshire County Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var asset_fillColor = fixmystreet.cobrand === "oxfordshire" ? "#007258" : "#FFFF00";

var occ_default = $.extend({}, fixmystreet.assets.style_default.defaultStyle, {
    fillColor: asset_fillColor
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

var occ_ownernames = [
    "LocalAuthority", "CountyCouncil", 'ODS'
];

function occ_owns_feature(f) {
    return f &&
           f.attributes &&
           f.attributes.maintained_by &&
           OpenLayers.Util.indexOf(occ_ownernames, f.attributes.maintained_by) > -1;
}

function occ_does_not_own_feature(f) {
    return !occ_owns_feature(f);
}

var owned_default_style = new OpenLayers.Style({
    fillColor: "#868686",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.6,
    strokeWidth: 2,
    pointRadius: 4,
    title: 'Not maintained by Oxfordshire County Council. Maintained by ${maintained_by}.'
});

var rule_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: occ_owns_feature
    }),
    symbolizer: {
        fillColor: asset_fillColor,
        pointRadius: 6,
        title: ''
    }
});

var rule_not_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: occ_does_not_own_feature
    })
});

owned_default_style.addRules([rule_owned, rule_not_owned]);

var owned_stylemap = new OpenLayers.StyleMap({
    'default': owned_default_style,
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
    select_action: true,
    stylemap: occ_stylemap,
    wfs_feature: "Traffic_Lights",
    asset_id_field: 'Site',
    attributes: {
        feature_id: 'Site'
    },
    asset_category: ["Traffic Lights (permanent only)"],
    asset_item: 'traffic light',
    feature_code: 'Site',
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

var owned_base = $.extend({}, defaults, {
    select_action: true,
    srsName: "EPSG:27700",
    actions: {
        asset_found: function(asset) {
          var is_occ = this.fixmystreet.owns_function(asset);
          if (!is_occ) {
              fixmystreet.message_controller.asset_not_found.call(this);
          } else {
              fixmystreet.message_controller.asset_found.call(this);
          }
        },
        // Not a typo, asset selection is not mandatory
        asset_not_found: fixmystreet.message_controller.asset_found
    }
});

var owned_defaults = $.extend({}, owned_base, {
    stylemap: owned_stylemap,
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
    asset_id_field: 'id',
    attributes: {
        feature_id: 'id'
    },
    owns_function: occ_owns_feature
});

fixmystreet.assets.add(owned_defaults, {
    http_options: {
        url: proxy_base_url + 'drains/wfs',
        params: {
            TYPENAME: "junctions"
        }
    },
    asset_category: ["Gully and Catchpits", 'Drainage'],
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

// Bridges

function occ_owns_bridge(f) {
    return f &&
           f.attributes &&
           f.attributes.MAINTENANCE_AUTHORITY_UID &&
           f.attributes.MAINTENANCE_AUTHORITY_UID == 1;
}

function occ_does_not_own_bridge(f) {
    return !occ_owns_bridge(f);
}

var bridge_default_style = new OpenLayers.Style({
    fillColor: "#868686",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.6,
    strokeWidth: 2,
    pointRadius: 4,
    title: 'Not maintained by Oxfordshire County Council.'
});

var rule_bridge_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: occ_owns_bridge
    }),
    symbolizer: {
        fillColor: asset_fillColor,
        pointRadius: 6,
        title: ''
    }
});

var rule_bridge_not_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: occ_does_not_own_bridge
    })
});

bridge_default_style.addRules([rule_bridge_owned, rule_bridge_not_owned]);

var bridge_stylemap = new OpenLayers.StyleMap({
    'default': bridge_default_style,
    'select': fixmystreet.assets.style_default_select,
    'hover': occ_hover
});

fixmystreet.assets.add(owned_base, {
    stylemap: bridge_stylemap,
    wfs_url: proxy_base_url + 'nsg/',
    wfs_feature: 'BRIDESFMS1',
    geometryName: 'SHAPE_GEOMETRY',
    propertyNames: ['ALL_STRUCTURES_CODE', 'MAINTENANCE_AUTHORITY_UID', 'SHAPE_GEOMETRY'],
    filter_key: 'MAINTENANCE_AUTHORITY_UID',
    filter_value: [1, 21],
    asset_category: ['Bridges'],
    asset_item: 'bridge',
    asset_id_field: 'ALL_STRUCTURES_CODE',
    attributes: {
        feature_id: 'ALL_STRUCTURES_CODE'
    },
    no_asset_msg_id: '#js-occ-prow-bridge',
    owns_function: occ_owns_bridge
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
    wfs_feature: "OCCRoads",
    propertyNames: ['TYPE1_2_USRN', 'STREET_MAINTENANCE_RESPONSIBILITY_NAME', 'msGeometry'],
    srsName: "EPSG:27700",
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
    asset_category: road_categories
});

// Track open popup for defect pins
var defect_popup;

function show_defect_popup(feature) {
    defect_popup = new OpenLayers.Popup.FramedCloud(
        "occDefects",
        feature.geometry.getBounds().getCenterLonLat(),
        null,
        feature.attributes.title.replace("\n", "<br />"),
        { size: new OpenLayers.Size(0, 0), offset: new OpenLayers.Pixel(6, -46) },
        true,
        close_defect_popup
    );
    fixmystreet.map.addPopup(defect_popup);
}

function close_defect_popup() {
    if (!!defect_popup) {
        fixmystreet.map.removePopup(defect_popup);
        defect_popup.destroy();
        defect_popup = null;
    }
}

// Handle clicks on defect pins when showing duplicates
function setup_defect_popup() {
    var select_defect = new OpenLayers.Control.SelectFeature(
        fixmystreet.markers,
        {
            hover: true,
            clickFeature: function (feature) {
                close_defect_popup();
                if (feature.attributes.colour !== 'defects') {
                    // We're only interested in defects
                    return;
                }
                show_defect_popup(feature);
            }
        }
    );
    fixmystreet.map.addControl(select_defect);
    select_defect.activate();
}

function handle_marker_click(e, feature) {
    close_defect_popup();

    // Show popups for defects, which have negative fake IDs
    if (feature.attributes.id < 0) {
        show_defect_popup(feature);
    }
}

$(fixmystreet).on('maps:render_duplicates', setup_defect_popup);
$(fixmystreet).on('maps:marker_click', handle_marker_click);
$(fixmystreet).on('maps:click', close_defect_popup);

$(function() {
    if (fixmystreet.page == 'reports') {
        // Refresh markers on page load so that defects are loaded in over AJAX.
        fixmystreet.markers.events.triggerEvent('refresh');
    }
});

// Alloy street lighting stuff from here
// TODO: Further reduce duplicate between here & Northamptonshire

var streetlight_select = $.extend({
    label: "${title}",
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

var street_lighting_layer = 'layers_streetLightingAssets';
var base_url = fixmystreet.staging ?
      "https://tilma.staging.mysociety.org/resource-proxy/proxy.php?https://oxfordshire.staging/${layerid}/${x}/${y}/${z}/cluster" :
      "https://tilma.mysociety.org/resource-proxy/proxy.php?https://oxfordshire.assets/${layerid}/${x}/${y}/${z}/cluster";

var url_with_style = base_url + '?styleIds=${styleid}';

var layers = [
    {
        categories: lighting_categories,
        item_name: "street light",
        layer_name: "Street Lights",
        styleid: '5e0e0edfca31500efc379151',
    }
];

// default options for these assets include
// a) checking for multiple assets in same location
// b) preventing submission unless an asset is selected
var oxfordshire_defaults = $.extend(true, {}, fixmystreet.alloyv2_defaults, {
  stylemap: streetlight_stylemap,
  class: OpenLayers.Layer.AlloyVectorAsset,
  protocol_class: OpenLayers.Protocol.AlloyV2,
  http_options: {
      base: url_with_style,
      layerid: street_lighting_layer
  },
  non_interactive: false,
  body: "Oxfordshire County Council",
  attributes: {
    // feature_id
    unit_number: "title",
    asset_resource_id: function() {
      return this.fid;
    }
  },
  select_action: true,
  feature_code: 'title',
  asset_id_field: 'itemId',
  actions: {
    asset_found: function(asset) {
      if (fixmystreet.message_controller.asset_found.call(this)) {
          return;
      }
      fixmystreet.assets.named_select_action_found.call(this, asset);
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
      fixmystreet.message_controller.asset_not_found.call(this);
      fixmystreet.assets.named_select_action_not_found.call(this);
    }
  }
});

fixmystreet.alloy_add_layers(oxfordshire_defaults, layers);

})();
