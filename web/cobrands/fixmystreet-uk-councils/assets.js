(function(){

if (!fixmystreet.maps) {
    return;
}

/* Bath & NE Somerset */

fixmystreet.assets.banes = {};
fixmystreet.assets.banes.park_asset_details = function() {
    var a = this.attributes;
    return a.description + " " + a.assetid;
};

/* Street lights are included/styled according to their owner. */

var banes_ownernames = [
    "B&NES CAR PARKS",
    "B&NES PARKS",
    "B&NES PROPERTY",
    "B&NES HIGHWAYS"
];

// Some are excluded from the map entirely
var banes_exclude_ownernames = [
    "EXCEPTIONS"
];

function banes_include_feature(f) {
    return f &&
           f.attributes &&
           f.attributes.ownername &&
           OpenLayers.Util.indexOf(banes_exclude_ownernames, f.attributes.ownername) == -1;
}

function banes_owns_feature(f) {
    return f &&
           f.attributes &&
           f.attributes.ownername &&
           OpenLayers.Util.indexOf(banes_ownernames, f.attributes.ownername) > -1 &&
           banes_include_feature(f);
}

function banes_does_not_own_feature(f) {
    return !banes_owns_feature(f) &&
           banes_include_feature(f);
}

var banes_lighting_default_style = new OpenLayers.Style({
    fillColor: "#868686",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.6,
    strokeWidth: 2,
    pointRadius: 4,
    title: '${unitdescription} ${unitno}\r\nNot owned by B&NES. Owned by ${ownername}.'
});

var banes_rule_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: banes_owns_feature
    }),
    symbolizer: {
        fillColor: "#FFFF00",
        pointRadius: 6,
        title: '${unitdescription} ${unitno}',
    }
});

var banes_rule_not_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: banes_does_not_own_feature
    })
});
banes_lighting_default_style.addRules([banes_rule_owned, banes_rule_not_owned]);

fixmystreet.assets.banes.lighting_stylemap = new OpenLayers.StyleMap({
    'default': banes_lighting_default_style,
    'select': fixmystreet.assets.style_default_select,
    'hover': new OpenLayers.Style({
        pointRadius: 8,
        cursor: 'pointer'
    })
});

fixmystreet.assets.banes.lighting_asset_details = function() {
    var a = this.attributes;
    return "street: " + a.street + "\n" +
           "owner: " + a.ownername + "\n" +
           "unitno: " + a.unitno + "\n" +
           "lamp: " + a.lamp + "\n" +
           "lampclass: " + a.lampclass + "\n" +
           "description: " + a.unitdescription;
};

fixmystreet.assets.banes.road_not_found = function(layer) {
    var cat = fixmystreet.reporting.selectedCategory().category;
    var asset_item = layer.fixmystreet.cat_map[cat];
    if (asset_item) {
        layer.fixmystreet.asset_item = asset_item;
        fixmystreet.message_controller.road_not_found(layer);
    } else {
        fixmystreet.message_controller.road_found(layer);
    }
};

// List of categories which are Curo Group's responsibility
var curo_categories = [
    'Allotment issue',
    'Dead animals',
    'Dog fouling',
    'Excessive or dangerous littering',
    'Litter bin damaged',
    'Litter bin full',
    'Needles',
    'Obstructive vegetation',
    'Play area safety issue',
    'Trees and woodland'
];

fixmystreet.assets.banes.curo_found = function(layer) {
    var category = fixmystreet.reporting.selectedCategory().category;
    if (curo_categories.indexOf(category) === -1) {
        fixmystreet.message_controller.road_found(layer);
        return;
    }

    fixmystreet.message_controller.road_not_found(layer);
    $('#js-roads-responsibility > strong').hide();

    var domain = 'curo-group.co.uk';
    var email = 'estates@' + domain;
    var email_string = $(layer.fixmystreet.no_asset_msg_id).find('.js-roads-asset');
    if (email_string) {
        email_string.html('<a href="mailto:' + email + '">' + email + '</a>');
    }
};
fixmystreet.assets.banes.curo_not_found = function(layer) {
    $('#js-roads-responsibility > strong').show();
    fixmystreet.message_controller.road_found(layer);
};

/* Bexley */

fixmystreet.assets.bexley = {};
fixmystreet.assets.bexley.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${Unit_No}")
});

/* Bristol */

fixmystreet.assets.bristol = {};
fixmystreet.assets.bristol.park_stylemap = new OpenLayers.StyleMap({
    default: new OpenLayers.Style({
        fill: true,
        fillColor: "#1be547",
        fillOpacity: "0.25"
    })
});

/* Bromley */

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

/* Central Bedfordshire */

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

/* Cheshire East */

fixmystreet.assets.cheshireeast = {};
fixmystreet.assets.cheshireeast.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${asset_id}")
});

/* East Sussex */

OpenLayers.Format.EastSussex = OpenLayers.Class(OpenLayers.Format.JSON, {
    read: function(json, type, filter) {
        var obj = json;
        if (typeof json == "string") {
            obj = OpenLayers.Format.JSON.prototype.read.apply(this,
                                                              [json, filter]);
        }

        var results = [];
        for (var i=0, len=obj.length; i<len; i++) {
            var item = obj[i];
            var geom = new OpenLayers.Geometry.Point(item.Mid_Location__c.longitude, item.Mid_Location__c.latitude);
            var vec = new OpenLayers.Feature.Vector(geom, item);
            results.push(vec);
        }

        return results;
    },
    CLASS_NAME: "OpenLayers.Format.EastSussex"
});

OpenLayers.Protocol.EastSussex = OpenLayers.Class(OpenLayers.Protocol.HTTP, {
    read: function(options) {
        OpenLayers.Protocol.prototype.read.apply(this, arguments);
        options = options || {};
        options.params = OpenLayers.Util.applyDefaults(
            options.params, this.options.params);
        options = OpenLayers.Util.applyDefaults(options, this.options);
        var types = options.types.join('&types=');
        var coords = fixmystreet.map.getCenterWGS84();
        options.url = options.url + '?longitude=' + coords.lat + '&latitude=' + coords.lon + '&types=' + types;
        var resp = new OpenLayers.Protocol.Response({requestType: "read"});
        resp.priv = OpenLayers.Request.GET({
            url: options.url,
            callback: this.createCallback(this.handleRead, resp, options),
            params: options.params,
            headers: options.headers
        });
    },
    CLASS_NAME: "OpenLayers.Protocol.EastSussex"
});

// can have multiple group
$(function(){
    $("#problem_form").on("change.category", function() {
        var group = '';
        if (OpenLayers.Util.indexOf(fixmystreet.bodies, 'East Sussex County Council') != -1 ) {
          group = fixmystreet.reporting.selectedCategory().group;
        }
        $('#form_group').val(group);
    });
});

fixmystreet.assets.eastsussex = {};
fixmystreet.assets.eastsussex.construct_selected_asset_message = function(asset) {
    var last_clean = asset.attributes.Gully_Last_Clean_Date__c || '';
    var next_clean = asset.attributes.Gully_Next_Clean_Date__c || '';
    if (last_clean !== '' || next_clean !== '') {
        var message = '';
        if (last_clean) { message += '<b>Last Cleaned</b>: ' + last_clean; }
        if (next_clean) { message += ' <b>Next Clean</b>: ' + next_clean; }
        return message;
    }
};

/* Hounslow */

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

/* Isle of Wight */

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

/* Lincolnshire */

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

/* Merton */

fixmystreet.assets.merton = {};
fixmystreet.assets.merton.streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${UnitNumber}")
});

/* Shropshire */

fixmystreet.assets.shropshire = {};

fixmystreet.assets.shropshire.street_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        strokeColor: "#5555FF",
        strokeOpacity: 0.1,
        strokeWidth: 7
    })
});

fixmystreet.assets.shropshire.street_found = function(layer, asset) {
    fixmystreet.message_controller.road_found(layer, asset.attributes.SITE_CLASS, function(name) {
        if (name == 'PUB' || name === 'PUPI') { return 1; }
        else { return 0; }
    }, "#js-not-council-road");
};
fixmystreet.assets.shropshire.street_not_found = function(layer) {
      fixmystreet.message_controller.road_not_found(layer);
};

// Only parish rows have an owner
function shropshire_light(f) {
    return f &&
           f.attributes &&
           !f.attributes.OWNER;
}
function shropshire_parish_light(f) {
    return !shropshire_light(f);
}

var shropshire_light_default_style = new OpenLayers.Style({
    fillColor: "#868686",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.6,
    strokeWidth: 2,
    pointRadius: 4
});
var shropshire_rule_light_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: shropshire_light
    }),
    symbolizer: {
        fillColor: "#FFFF00",
        pointRadius: 6
    }
});
var shropshire_rule_light_not_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: shropshire_parish_light
    })
});
shropshire_light_default_style.addRules([ shropshire_rule_light_owned, shropshire_rule_light_not_owned ]);

fixmystreet.assets.shropshire.streetlight_stylemap = new OpenLayers.StyleMap({
    'default': shropshire_light_default_style,
    'select': fixmystreet.assets.style_default_select,
    'hover': new OpenLayers.Style({
        pointRadius: 8,
        cursor: 'pointer'
    })
});

fixmystreet.assets.shropshire.streetlight_found = function(asset) {
    var controller_fn = shropshire_light(asset) ? 'asset_found' : 'asset_not_found';
    fixmystreet.message_controller[controller_fn].call(this);
    fixmystreet.assets.named_select_action_found.call(this, asset);
};
fixmystreet.assets.shropshire.streetlight_not_found = function(asset) {
    fixmystreet.message_controller.asset_not_found.call(this);
    fixmystreet.assets.named_select_action_not_found.call(this);
};

fixmystreet.assets.shropshire.streetlight_asset_message = function(asset) {
    var out = 'You have selected streetlight <b>' + asset.attributes.FEAT_LABEL + '</b>.';
    if (asset.attributes.PART_NIGHT === "YES") {
        out += "<br>This light is switched off from 12am until 5.30am.";
    }
    if (asset.attributes.OWNER) {
        out += " This light is the responsibility of " + asset.attributes.OWNER + " and should be reported to them, please see <a href='https://shropshire.gov.uk/committee-services/mgParishCouncilDetails.aspx?bcr=1'>the list of parish councils</a>.";
    }
    return out;
};

})();
