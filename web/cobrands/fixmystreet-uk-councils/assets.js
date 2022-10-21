(function(){

if (!fixmystreet.maps) {
    return;
}

fixmystreet.assets.bexley = {};
fixmystreet.assets.bexley.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${Unit_No}")
});

fixmystreet.assets.bristol = {};
fixmystreet.assets.bristol.park_stylemap = new OpenLayers.StyleMap({
    default: new OpenLayers.Style({
        fill: true,
        fillColor: "#1be547",
        fillOpacity: "0.25"
    })
});

fixmystreet.assets.bromley = {};
fixmystreet.assets.bromley.parks_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillColor: "#C3D9A2",
        fillOpacity: 0.6,
        strokeWidth: 2,
        strokeColor: '#90A66F'
    })
});
fixmystreet.assets.bromley.prow_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        fillOpacity: 0,
        strokeColor: "#660099",
        strokeOpacity: 0.5,
        strokeWidth: 6
    })
});

fixmystreet.assets.centralbedfordshire = {};
fixmystreet.assets.centralbedfordshire.streetlight_stylemap = new OpenLayers.StyleMap({
    'default': fixmystreet.assets.style_default,
    'hover': fixmystreet.assets.style_default_hover,
    'select': fixmystreet.assets.construct_named_select_style("${lighting_c}")
});

var centralbeds_types = [
    "CBC",
    "Fw",
];

function cb_likely_trees_report() {
    // Ensure the user can select anywhere on the map if they want to
    // make a report in the "Trees" category. This means we don't show the
    // "not found" message if no category/group has yet been selected
    // or if only the group containing the "Trees" category has been
    // selected.
    var selected = fixmystreet.reporting.selectedCategory();
    return selected.category === "Trees" ||
            (selected.group === "Grass, Trees, Verges and Weeds" && !selected.category) ||
            (!selected.group && !selected.category);
}

function cb_show_non_stopper_message() {
    // For reports about trees on private roads, Central Beds want the
    // "not our road" message to be shown and also for the report to be
    // able to be made.
    // The existing stopper message code doesn't allow for this situation, so
    // this function is used to show a custom DOM element that contains the
    // message.
    if ($('html').hasClass('mobile')) {
        var msg = $("#js-custom-not-council-road").html();
        $div = $('<div class="js-mobile-not-an-asset"></div>').html(msg);
        $div.appendTo('#map_box');
    } else {
        $("#js-custom-roads-responsibility").removeClass("hidden");
    }
}

function cb_hide_non_stopper_message() {
    $('.js-mobile-not-an-asset').remove();
    $("#js-custom-roads-responsibility").addClass("hidden");
}

fixmystreet.assets.centralbedfordshire.found = function(layer, feature) {
    fixmystreet.message_controller.road_found(layer, feature, function(feature) {
        cb_hide_non_stopper_message();
        if (OpenLayers.Util.indexOf(centralbeds_types, feature.attributes.adoption) != -1) {
            return true;
        }
        if (cb_likely_trees_report()) {
            cb_show_non_stopper_message();
            return true;
        }
        return false;
    }, "#js-not-council-road");
};
fixmystreet.assets.centralbedfordshire.not_found = function(layer) {
    cb_hide_non_stopper_message();
    if (cb_likely_trees_report()) {
        fixmystreet.message_controller.road_found(layer);
    } else {
        fixmystreet.message_controller.road_not_found(layer);
    }
};

fixmystreet.assets.cheshireeast = {};
fixmystreet.assets.cheshireeast.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${feature_id}")
});

fixmystreet.assets.hounslow = {};

// The label for street light markers should be everything after the final
// '/' in the feature's FeatureId attribute.
// This seems to be the easiest way to perform custom processing
// on style attributes in OpenLayers...
var hounslow_select_style = fixmystreet.assets.construct_named_select_style("${FeatureId}");
hounslow_select_style.createLiterals = function() {
    var literals = Object.getPrototypeOf(this).createLiterals.apply(this, arguments);
    if (literals.label && literals.label.split) {
        literals.label = literals.label.split("/").slice(-1)[0];
    }
    return literals;
};

fixmystreet.assets.hounslow.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': hounslow_select_style
});

fixmystreet.assets.hounslow.construct_asset_name = function(id) {
    if (id.split) {
        var code = id.split("/").slice(-1)[0];
        return {id: code, name: 'column'};
    }
};

fixmystreet.assets.isleofwight = {};
fixmystreet.assets.isleofwight.streets_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        strokeColor: "#5555FF",
        strokeOpacity: 0.1,
        strokeWidth: 7
    })
});

fixmystreet.assets.isleofwight.not_found_msg_update = function() {
    $('.category_meta_message').html('Please select an item or a road/pavement/path on the map &raquo;');
    $('.category_meta_message').removeClass('meta-highlight');
    $("input[name=asset_details]").val('');
};

fixmystreet.assets.isleofwight.found_item = function(asset) {
  var id = asset.attributes.central_asset_id || '';
  if (id !== '') {
      var attrib = asset.attributes;
      var asset_name = attrib.feature_type_name + '; ' + attrib.site_name + '; ' + attrib.feature_location;
      $('.category_meta_message').html('You have selected ' + asset_name);
      $('.category_meta_message').addClass('meta-highlight');
      $("input[name=asset_details]").val(asset_name);
  } else {
      fixmystreet.assets.isleofwight.not_found_msg_update();
  }
};

fixmystreet.assets.isleofwight.line_found_item = function(layer, feature) {
    if ( fixmystreet.assets.selectedFeature() ) {
        return;
    }
    fixmystreet.assets.isleofwight.found_item(feature);
};
fixmystreet.assets.isleofwight.line_not_found_msg_update = function(layer) {
    if ( fixmystreet.assets.selectedFeature() ) {
        return;
    }
    fixmystreet.assets.isleofwight.not_found_msg_update();
};

fixmystreet.assets.lincolnshire = {};
fixmystreet.assets.lincolnshire.barrier_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        strokeColor: "#000000",
        strokeOpacity: 0.9,
        strokeWidth: 4
    }),
    'select': new OpenLayers.Style({
        strokeColor: "#55BB00",
        strokeOpacity: 1,
        strokeWidth: 8
    }),
    'hover': new OpenLayers.Style({
        strokeWidth: 6,
        strokeOpacity: 1,
        strokeColor: "#FFFF00",
        cursor: 'pointer'
    })
});
fixmystreet.assets.lincolnshire.llpg_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillOpacity: 0,
        strokeColor: "#000000",
        strokeOpacity: 0.25,
        strokeWidth: 2,
        pointRadius: 10,

        label: "${label}",
        labelOutlineColor: "white",
        labelOutlineWidth: 2,
        fontSize: '11px',
        fontWeight: 'bold'
    })
});

fixmystreet.assets.merton = {};
fixmystreet.assets.merton.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${UnitNumber}")
});

})();
