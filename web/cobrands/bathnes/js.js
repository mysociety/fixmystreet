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
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'feature_no',
    attributes: null,
    geometryName: 'msGeometry',
    srsName: "EPSG:27700"
};


fixmystreet.assets.add($.extend(true, {}, fixmystreet.maps.banes_defaults, {
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
}));

fixmystreet.assets.add($.extend(true, {}, fixmystreet.maps.banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "ParksOpenSpaces"
        }
    },
    asset_category: [
        'Play area safety issue',
        'Obstructive vegetation',
        'Damaged infrastructure (e.g. broken benches)',
        'Allotment issue'
    ],
    asset_item: "park",
    disable_pin_snapping: true,
    stylemap: new OpenLayers.StyleMap({
        'default': new OpenLayers.Style({
            fill: false,
            stroke: false
        })
    }),
    attributes: {
        asset_details: function() {
            var a = this.attributes;
            return a.site_code + " " + a.site_name;
        }
    },
    name: "Parks and Grounds"
}));



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
           exclude_ownernames.indexOf(f.attributes.ownername) == -1;
}

function banes_owns_feature(f) {
    return f &&
           f.attributes &&
           f.attributes.ownername &&
           banes_ownernames.indexOf(f.attributes.ownername) > -1 &&
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

// XXX fixmystreet.pin_prefix isn't always available here (e.g. on /report/new),
// so get it from the DOM directly
var pin_prefix = fixmystreet.pin_prefix || document.getElementById('js-map-data').getAttribute('data-pin_prefix');

var lighting_stylemap = new OpenLayers.StyleMap({
    'default': lighting_default_style,
    'select': new OpenLayers.Style({
        externalGraphic: pin_prefix + "pin-spot.png",
        fillColor: "#55BB00",
        graphicWidth: 48,
        graphicHeight: 64,
        graphicXOffset: -24,
        graphicYOffset: -56,
        backgroundGraphic: pin_prefix + "pin-shadow.png",
        backgroundWidth: 60,
        backgroundHeight: 30,
        backgroundXOffset: -7,
        backgroundYOffset: -22,
        popupYOffset: -40,
        graphicOpacity: 1.0
    }),
    'hover': new OpenLayers.Style({
        pointRadius: 8,
        cursor: 'pointer'
    })

});


fixmystreet.assets.add($.extend(true, {}, fixmystreet.maps.banes_defaults, {
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
}));


var highways_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        stroke: false
    })
});

fixmystreet.assets.add($.extend(true, {}, fixmystreet.maps.banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "AdoptedHighways"
        }
    },
    stylemap: highways_stylemap,
    non_interactive: true,
    always_visible: true,
    usrn: {
        attribute: 'usrn',
        field: 'site_code'
    },
    name: "Adopted Highways",
    attribution: " © Crown Copyright. All rights reserved. 1000233344"
}));


})();
