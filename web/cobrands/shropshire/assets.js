(function(){

if (!fixmystreet.maps) {
    return;
}

var wfs_host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';
var tilma_url = "https://" + wfs_host + "/mapserver/shropshire";

var defaults = {
    http_options: {
        url: tilma_url,
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    asset_type: 'spot',
    asset_id_field: 'CentralAssetId',
    attributes: {
        central_asset_id: 'CentralAssetId',
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    body: "Shropshire Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var highways_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#5555FF",
    strokeOpacity: 0.1,
    strokeWidth: 7
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Street_Gazetteer"
        }
    },
    stylemap: new OpenLayers.StyleMap({
         'default': highways_style
     }),
    usrn: {
        attribute: 'USRN',
        field: 'site_code'
    },
    road: true,
    asset_item: 'road',
    asset_type: 'road',
    no_asset_msg_id: '#js-not-a-road',
    no_asset_msgs_class: '.js-roads-shropshire',
    always_visible: true,
    non_interactive: true,
    all_categories: true,
    actions: {
        found: function(layer, asset) {
            fixmystreet.message_controller.road_found(layer, asset.attributes.SITE_CLASS, function(name) {
                if (name == 'PUB' || name === 'PUPI') { return 1; }
                else { return 0; }
            }, "#js-not-council-road");
        },
        not_found: function(layer) {
              fixmystreet.message_controller.road_not_found(layer);
        }
    }
});

// Only parish rows have an owner
function shropshire_light(f) {
    return f &&
           f.attributes &&
           !f.attributes.OWNER;
}
function shropshire_parish_light(f) {
    return !shropshire_light(f);
}

var light_default_style = new OpenLayers.Style({
    fillColor: "#868686",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.6,
    strokeWidth: 2,
    pointRadius: 4
});
var rule_light_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: shropshire_light
    }),
    symbolizer: {
        fillColor: "#FFFF00",
        pointRadius: 6
    }
});
var rule_light_not_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: shropshire_parish_light
    })
});
light_default_style.addRules([ rule_light_owned, rule_light_not_owned ]);

var sc_hover = new OpenLayers.Style({
    pointRadius: 8,
    cursor: 'pointer'
});
var streetlight_stylemap = new OpenLayers.StyleMap({
    'default': light_default_style,
    'select': fixmystreet.assets.style_default_select,
    'hover': sc_hover
});

fixmystreet.assets.add(defaults, {
    stylemap: streetlight_stylemap,
    http_options: {
        params: {
            TYPENAME: "Lights_Union"
        }
    },
    asset_group: "Streetlights",
    asset_item: 'streetlight',
    asset_id_field: 'ASSET_ID',
    attributes: {
        central_asset_id: 'ASSET_ID',
    },
    select_action: true,
    actions: {
        asset_found: function(asset) {
          var controller_fn = shropshire_light(asset) ? 'asset_found' : 'asset_not_found';
          fixmystreet.message_controller[controller_fn].call(this);
          fixmystreet.assets.named_select_action_found.call(this, asset);
        },
        asset_not_found: function(asset) {
            fixmystreet.message_controller.asset_not_found.call(this);
            fixmystreet.assets.named_select_action_not_found.call(this);
        }
    },
    construct_selected_asset_message: function(asset) {
        var out = 'You have selected streetlight <b>' + asset.attributes.FEAT_LABEL + '</b>.';
        if (asset.attributes.PART_NIGHT === "YES") {
            out += "<br>This light is switched off from 12am until 5.30am.";
        }
        if (asset.attributes.OWNER) {
            out += " This light is the responsibility of " + asset.attributes.OWNER + " and should be reported to them, please see <a href='https://shropshire.gov.uk/committee-services/mgParishCouncilDetails.aspx?bcr=1'>the list of parish councils</a>.";
        }
        return out;
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Traffic_Signal_Areas"
        }
    },
    asset_id_field: 'ASSET_ID',
    attributes: {
        central_asset_id: 'ASSET_ID',
    },
    asset_group: 'Traffic Signals & Crossings',
    asset_item: 'traffic signal'
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Illuminated_Bollards"
        }
    },
    asset_group: 'Illuminated signs',
    asset_item: 'bollard',
    asset_id_field: 'ASSET_ID',
    attributes: {
        central_asset_id: 'ASSET_ID',
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Grit_Bins"
        }
    },
    asset_category: ["Salt bins replenish"],
    asset_item: 'salt bin'
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Cattle_Grids"
        }
    },
    asset_category: ["Cattle Grid"],
    asset_item: 'cattle grid'
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Bridges"
        }
    },
    asset_category: ["Bridge"],
    asset_item: 'bridge'
});

})();
