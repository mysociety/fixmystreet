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
    "Other Lighting Issue",
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
    body: "Oxfordshire County Council"
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

// Drainage

var drain_defaults = $.extend(true, {}, owned_defaults, {
    http_options: {
        url: proxy_base_url + 'drains/wfs',
    },
    asset_category: ['Drainage', "Gully and Catchpits"]
});
var drain_inspection_defaults = $.extend({}, drain_defaults, {
    stylemap: fixmystreet.assets.stylemap_invisible,
    non_interactive: true
});
var drain_asset_defaults = $.extend(true, {}, drain_defaults, {
    http_options: {
        params: {
            propertyName: 'id,msGeometry,maintained_by,asset_id,created,last_inspected',
        }
    },
    select_action: true,
    construct_selected_asset_message: function(asset) {
        var type = this.fixmystreet.http_options.params.TYPENAME.slice(0, -1);
        var junctionInspectionLayer = window.fixmystreet.assets.layers.filter(function(elem) {
            return elem.fixmystreet.body == "Oxfordshire County Council" &&
            elem.fixmystreet.http_options &&
            elem.fixmystreet.http_options.format.featureType == type + '_inspections';
        });
        var inspection;
        if (junctionInspectionLayer[0]) {
            inspection = junctionInspectionLayer[0].features.filter(function(elem) {
                return elem.attributes.asset_id == asset.attributes.asset_id &&
                format_date(elem.attributes.created) == format_date(asset.attributes.last_inspected);
            });
        }
        var last_clean = '';
        var message = ' ';
        if (inspection && inspection[0]) {
            if (asset.attributes.last_inspected && (inspection[0].attributes.junction_cleaned === 'true' || inspection[0].attributes.channel_cleaned === 'true')) {
                last_clean = format_date(asset.attributes.last_inspected);
                message = 'This gully was last cleaned on ' + last_clean;
            }
        }
        return message;
    },
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

function format_date(date_field) {
    var regExDate = /([0-9]{4})-([0-9]{2})-([0-9]{2})/;
    var myMatch = regExDate.exec(date_field);
    if (myMatch) {
        return myMatch[3] + '/' + myMatch[2] + '/' + myMatch[1];
    } else {
        return '';
    }
}

// Junction/channel inspection layers (not shown on the map, but used by the layers below)

// When the auto-asset selection of a layer occurs, the data for inspections
// may not have loaded. So make sure we poke for a check when the data comes
// in.
function inspection_layer_loadend() {
    var type = this.fixmystreet.http_options.params.TYPENAME.replace('_inspections', 's');
    var layer = fixmystreet.assets.layers.filter(function(elem) {
        return elem.fixmystreet.body == "Oxfordshire County Council" &&
        elem.fixmystreet.http_options &&
        elem.fixmystreet.http_options.params &&
        elem.fixmystreet.http_options.params.TYPENAME == type;
    });
    layer[0].checkSelected();
}

var layer;
layer = fixmystreet.assets.add(drain_inspection_defaults, {
    http_options: {
        params: {
            propertyName: 'id,msGeometry,asset_id,created,junction_cleaned',
            TYPENAME: "junction_inspections"
        }
    },
    asset_item: 'drain'
});
layer.events.register( 'loadend', layer, inspection_layer_loadend);

layer = fixmystreet.assets.add(drain_inspection_defaults, {
    http_options: {
        params: {
            propertyName: 'id,msGeometry,asset_id,created,channel_cleaned',
            TYPENAME: "channel_inspections"
        }
    },
    asset_item: 'gully'
});
layer.events.register( 'loadend', layer, inspection_layer_loadend);

fixmystreet.assets.add(drain_asset_defaults, {
    http_options: { params: { TYPENAME: "channels" } },
    asset_item: 'gully'
});
fixmystreet.assets.add(drain_asset_defaults, {
    http_options: { params: { TYPENAME: "junctions" } },
    asset_item: 'drain',
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

fixmystreet.assets.add(defaults, {
    stylemap: fixmystreet.assets.stylemap_invisible,
    wfs_url: proxy_base_url + 'nsg/',
    wfs_feature: 'MAINTAINABLE_AT_PUBLIC_EXPENSE_FMS',
    geometryName: 'SHAPE_GEOMETRY',
    propertyNames: ['UNIQUE_STREET_REFERENCE_NUMBER', 'SHAPE_GEOMETRY'],
    srsName: "EPSG:27700",
    usrn: {
        attribute: 'UNIQUE_STREET_REFERENCE_NUMBER',
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

var streetlight_select = $.extend({
    label: "${title}",
    fontColor: "#FFD800",
    labelOutlineColor: "black",
    labelOutlineWidth: 3,
    labelYOffset: 69,
    fontSize: '18px',
    fontWeight: 'bold'
}, fixmystreet.assets.style_default_select.defaultStyle);

function oxfordshire_light(f) {
    return f && f.attributes && !f.attributes.private;
}
function oxfordshire_light_not(f) {
    return !oxfordshire_light(f);
}

var light_default_style = new OpenLayers.Style(occ_default);
var rule_light_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: oxfordshire_light
    })
});
var rule_light_not_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: oxfordshire_light_not
    }),
    symbolizer: {
        fillColor: "#868686",
        strokeWidth: 1,
        pointRadius: 4
    }
});
light_default_style.addRules([ rule_light_owned, rule_light_not_owned ]);

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': light_default_style,
  'select': new OpenLayers.Style(streetlight_select),
  'hover': occ_hover
});

var base_host = fixmystreet.staging ?  "https://tilma.staging.mysociety.org" : "https://tilma.mysociety.org";
var base_proxy_url = fixmystreet.staging ? "https://oxfordshire.staging" : "https://oxfordshire.assets";
var base_light_url = base_host + "/alloy/oxfordshire-lights.php?url=" + base_proxy_url;

// default options for these assets include
// a) checking for multiple assets in same location
// b) preventing submission unless an asset is selected
var oxfordshire_defaults = {
  format_class: OpenLayers.Format.GeoJSON,
  srsName: "EPSG:4326",
  class: OpenLayers.Layer.VectorAssetMove,
  non_interactive: false,
  body: "Oxfordshire County Council",
  attributes: {
    // feature_id
    unit_number: "title",
    unit_type: "unit_type",
    asset_resource_id: "itemId"
  },
  select_action: true,
  feature_code: 'title',
  asset_id_field: 'itemId',
  construct_selected_asset_message: function(asset) {
      var out = 'You have selected ';
      out += asset.attributes.unit_type || "street light";
      out += " <b>" + asset.attributes.title + '</b>.';
      if (asset.attributes.private) {
          out += " This private street light asset is not under the responsibility of Oxfordshire County Council and therefore we are unable to accept reports for the asset.";
      }
      return out;
  },
  actions: {
    asset_found: function(asset) {
      fixmystreet.assets.named_select_action_found.call(this, asset);
      if (asset.attributes.private) {
          fixmystreet.message_controller.asset_not_found.call(this);
          return;
      } else if (fixmystreet.message_controller.asset_found.call(this)) {
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
};

fixmystreet.assets.add(oxfordshire_defaults, {
  http_options: { url: base_light_url },
  stylemap: streetlight_stylemap,
  asset_category: lighting_categories,
  max_resolution: 1.194328566789627,
  asset_item: "street light",
  asset_type: "spot"
});

})();
