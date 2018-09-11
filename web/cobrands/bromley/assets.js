(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.staging.mysociety.org/mapserver/bromley_wfs",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    format_class: OpenLayers.Format.GML.v3.MultiCurveFix,
    asset_type: 'spot',
    max_resolution: 4.777314267158508,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'CENTRAL_AS',
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "Bromley Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Streetlights"
        }
    },
    asset_id_field: 'FEATURE_ID',
    attributes: {
        feature_id: 'FEATURE_ID'
    },
    asset_category: ["Street Lighting and Road Signs"],
    asset_item: 'street light'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Bins"
        }
    },
    asset_category: ["Parks and Greenspace", "Street Cleansing"],
    asset_item: 'park bin',
    asset_item_message: 'For our parks, pick a <b class="asset-spot">bin</b> from the map &raquo;'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Street_Trees"
        }
    },
    asset_category: ["Public Trees"],
    asset_item: 'tree'
}));

var highways_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        stroke: false
    })
});

var bromley_to_tfl = {
    'Enforcement': ['Nuisance Signs', 'Obstruction to Highway', 'Overhanging Vegetation from private land', 'Unlicenced skip/materials on Highway'],
    'Graffiti and Flyposting': ['Nuisance Signs'],
    'Parks and Greenspace': ['Blocked Drain', 'Floral Display', 'Grass needs cutting'],
    'Street Cleansing': ['Blocked Drain'],
    'Road and Pavement Issues': true,
    'Street Lighting and Road Signs': true,
    'Public Trees': true
};
var tfl_asset_categories = Object.keys(bromley_to_tfl);

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "TFL_Red_Route"
        }
    },
    stylemap: highways_stylemap,
    always_visible: true,

    asset_category: tfl_asset_categories,
    non_interactive: true,
    road: true,
    body: 'Bromley Council',
    actions: {
        found: function(layer, feature) {
            if (fixmystreet.assets.selectedFeature()) {
                return;
            }
            var category = $('select#form_category').val(),
                subcategory = $('#form_service_sub_code').val(),
                subcategories = bromley_to_tfl[category];
            if (subcategories === true || (subcategory && OpenLayers.Util.indexOf(subcategories, subcategory))) {
                fixmystreet.body_overrides.only_send('TfL');
            }
        },
        not_found: function(layer) {
            fixmystreet.body_overrides.remove_only_send();
        }
    }
}));

var prow_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        fillOpacity: 0,
        strokeColor: "#660099",
        strokeOpacity: 0.5,
        strokeWidth: 6
    })
});

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "PROW"
        }
    },
    stylemap: prow_stylemap,
    always_visible: true,
    non_interactive: true,
    road: true,
    all_categories: true,
    actions: {
        found: function(layer, feature) {
            $('#form_prow_reference').val(feature.attributes.PROW_REFER);
        },
        not_found: function(layer) {
            $('#form_prow_reference').val('');
        }
    }
}));

})();
