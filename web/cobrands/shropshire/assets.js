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
    asset_id_field: 'central_as',
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'site_code'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    body: "Shropshire Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var streetlight_stylemap = new OpenLayers.StyleMap({
    'default': fixmystreet.assets.style_default,
    'hover': fixmystreet.assets.style_default_hover,
    'select': fixmystreet.assets.construct_named_select_style("${feature_id}")
  });

var labeled_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    feature_code: 'feature_id',
    stylemap: streetlight_stylemap,
    construct_asset_name: function(id) {
        var code = id.replace(/[O0-9]+[A-Z]*/g, '');
        return {id: id, name: streetlight_code_to_type[code] || 'street light'};
    },
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

var highways_style = new OpenLayers.Style({
    fill: false,
    strokeColor: "#5555FF",
    strokeOpacity: 0.1,
    strokeWidth: 7
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Street_Gazeteer"
        }
    },
    stylemap: new OpenLayers.StyleMap({
         'default': highways_style
     }),
    always_visible: true,
    non_interactive: true,
    road: true,
    asset_item: 'road',
    asset_type: 'road',
    all_categories: true,
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Street_Lights"
        }
    },
    asset_category: ["3+ Consecutive Lights Out", "Hanging Lantern", "Smoking/Sparking equipment",
    "Street Light Burning Red", "Street Light Damaged", "Street Light Day Burning",
    "Street Light Door Off", "Street Light Electrical Wiring", "Street Light Flash/Flickering",
    "Street Lighting Other", "Street Light Knocked Down", "Street Light Out", 
    "Water In Lantern Bowl"],
    asset_item: 'streetlight',
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Traffic_Signal_Areas"
        }
    },
    feature_code: 'FEATURE_ID',
    asset_category: [ 'Damaged equipment', 'Lamp(s) out', 'Temporary Traffic Light Fault',
    'Zebra Crossing Light Out', 'Zebra Crossing post Damaged','Total failure'],
    asset_item: 'traffic signal',
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Illuminated_Bollards"
        }
    },
    asset_category: [ 'Illuminated Bollard Top Missing', 'Illuminated Bollard Down',
		      'Illuminated Bollard Missing', 'Illuminated Bollard Out',
		      'Illuminated Sign Damaged', 'Illuminated Sign Knocked Down', 'Illuminated Sign Out'
		    ],
    feature_code: 'CentralAssetId',
    asset_item: 'bollard',
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Parish_Street_Lights"
        }
    },
    asset_category: ["3+ Consecutive Lights Out", "Hanging Lantern", "Smoking/Sparking equipment",
    "Street Light Burning Red", "Street Light Damaged", "Street Light Day Burning",
    "Street Light Door Off", "Street Light Electrical Wiring", "Street Light Flash/Flickering",
    "Street Lighting Other", "Street Light Knocked Down", "Street Light Out", 
    "Water In Lantern Bowl"],
    asset_item: 'streetlight',
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Grit_Bins"
        }
    },
    asset_category: ["Salt bins new", "Salt bins replenish"],
    asset_item: 'grit bin',
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(defaults, {
    // Don't seem to be any categories for this
    http_options: {
        params: {
            TYPENAME: "Cattle_Grids"
        }
    },
    asset_category: ["Cattle Grid"],
    asset_item: 'cattle grid',
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Bridge"
        }
    },
    asset_category: ["Bridge"],
    asset_item: 'bridge',
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

})();
