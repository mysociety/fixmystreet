(function(){

if (!fixmystreet.maps) {
    return;
}

fixmystreet.maps.banes_defaults = {
    http_options: {
        url: "https://isharemaps.bathnes.gov.uk/getows.ashx",
        params: {
            mapsource: "BathNES/WFS",
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            TYPENAME: "",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700",
            outputFormat: 'application/json'
        }
    },
    format_class: OpenLayers.Format.GeoJSON,
    format_options: {ignoreExtraDims: true},
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    asset_category: "",
    asset_item: "asset",
    asset_type: 'spot',
    max_resolution: 4.777314267158508,
    asset_id_field: 'feature_no',
    attributes: null,
    geometryName: 'msGeometry',
    body: "Bath and North East Somerset Council",
    srsName: "EPSG:27700"
};


fixmystreet.assets.add(fixmystreet.maps.banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "Gritbins"
        }
    },
    asset_category: "Grit bin issue",
    asset_item: "grit bin",
    attributes: {
        asset_details: 'feature_location'
    }
});

fixmystreet.assets.add(fixmystreet.maps.banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "ParksOpenSpacesAssets"
        }
    },
    asset_category: [
        'Abandoned vehicles',
        'Dead animals',
        'Dog fouling',
        'Fly-tipping',
        'Graffiti',
        'Excessive or dangerous littering',
        'Needles',
        'Play area safety issue',
        'Damage to bins, benches, and infrastructure',
        'Allotment issue',
        'Trees and woodland',
        'Obstructive vegetation'
    ],
    asset_item: "park",
    disable_pin_snapping: true,
    stylemap: fixmystreet.assets.stylemap_invisible,
    attributes: {
        asset_details: function() {
            var a = this.attributes;
            return a.description + " " + a.assetid;
        }
    },
    filter_key: 'category',
    filter_value: [
        'Flower Beds',
        'Grass',
        'Hard',
        'Hedgerow',
        'Path',
        'Pitch',
        'Seats'
    ],
    name: "Parks and Grounds"
});



/*
 * Street lights are included/styled according to their owner.
 */

var banes_ownernames = [
    "B&NES CAR PARKS",
    "B&NES PARKS",
    "B&NES PROPERTY",
    "B&NES HIGHWAYS"
];

// Some are excluded from the map entirely
var exclude_ownernames = [
    "EXCEPTIONS"
];

function include_feature(f) {
    return f &&
           f.attributes &&
           f.attributes.ownername &&
           OpenLayers.Util.indexOf(exclude_ownernames, f.attributes.ownername) == -1;
}

function banes_owns_feature(f) {
    return f &&
           f.attributes &&
           f.attributes.ownername &&
           OpenLayers.Util.indexOf(banes_ownernames, f.attributes.ownername) > -1 &&
           include_feature(f);
}

function banes_does_not_own_feature(f) {
    return !banes_owns_feature(f) &&
           include_feature(f);
}

var lighting_default_style = new OpenLayers.Style({
    fillColor: "#868686",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.6,
    strokeWidth: 2,
    pointRadius: 4,
    title: '${unitdescription} ${unitno}\r\nNot owned by B&NES. Owned by ${ownername}.'
});

var rule_owned = new OpenLayers.Rule({
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

var rule_not_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: banes_does_not_own_feature
    })
});
lighting_default_style.addRules([rule_owned, rule_not_owned]);

var lighting_stylemap = new OpenLayers.StyleMap({
    'default': lighting_default_style,
    'select': fixmystreet.assets.style_default_select,
    'hover': new OpenLayers.Style({
        pointRadius: 8,
        cursor: 'pointer'
    })
});

fixmystreet.assets.add(fixmystreet.maps.banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "StreetLighting"
        }
    },
    asset_category: "Street Light Fault",
    asset_item: "street light",
    stylemap: lighting_stylemap,
    attributes: {
        unitid: "unitid",
        asset_details: function() {
            var a = this.attributes;
            return "street: " + a.street + "\n" +
                   "owner: " + a.ownername + "\n" +
                   "unitno: " + a.unitno + "\n" +
                   "lamp: " + a.lamp + "\n" +
                   "lampclass: " + a.lampclass + "\n" +
                   "description: " + a.unitdescription;
        }
    }
});

fixmystreet.assets.add(fixmystreet.maps.banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "AdoptedHighways"
        }
    },
    stylemap: fixmystreet.assets.stylemap_invisible,
    non_interactive: true,
    always_visible: true,
    usrn: {
        attribute: 'usrn',
        field: 'site_code'
    },
    road: true,
    asset_item: "road",
    asset_type: 'road',
    all_categories: true, // Not really, but want to allow on all but one, not stop
    no_asset_msg_id: '#js-not-a-road',
    cat_map: {
      'Blocked drain surface': 'road',
      'Blocked drain': 'road',
      'Damage to pavement': 'pavement',
      'Damage to road': 'road',
      'Damaged Railing, manhole, or drain cover': 'road',
      'Damaged bollard or post': 'road',
      'Damaged road sign': 'road',
      'Damaged street nameplate': 'road',
      'Faded road markings': 'road',
      'Flooding of a road or pavement': 'road'
    },
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: function(layer) {
            var cat = $('select#form_category').val();
            var asset_item = layer.fixmystreet.cat_map[cat];
            if (asset_item) {
                layer.fixmystreet.asset_item = asset_item;
                fixmystreet.message_controller.road_not_found(layer);
            } else {
                fixmystreet.message_controller.road_found(layer);
            }
        }
    },
    name: "Adopted Highways",
    attribution: " © Crown Copyright. All rights reserved. 1000233344"
});


})();
