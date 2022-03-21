(function(){

if (!fixmystreet.maps) {
    return;
}

var domain = fixmystreet.staging ? "https://tilma.staging.mysociety.org" : "https://tilma.mysociety.org";
var defaults = {
    http_options: {
        url: domain + "/mapserver/bromley_wfs",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    asset_type: 'spot',
    max_resolution: 4.777314267158508,
    asset_id_field: 'CENTRAL_AS',
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "Bromley Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Streetlights"
        }
    },
    asset_id_field: 'FEATURE_ID',
    attributes: {
        feature_id: 'FEATURE_ID'
    },
    asset_category: ["Lamp Column Damaged", "Light Not Working", "Light On All Day", "Light blocked by vegetation"],
    asset_item: 'street light'
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Bins"
        }
    },
    asset_category: ["Overflowing litter/dog bin", "Public Litter Bin"],
    asset_item: 'park bin',
    asset_item_message: 'For our parks, pick a <b class="asset-spot">bin</b> from the map &raquo;'
});

var parks_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillColor: "#C3D9A2",
        fillOpacity: 0.6,
        strokeWidth: 2,
        strokeColor: '#90A66F'
    })
});

var parks_defaults = $.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: 'Parks_Open_Spaces'
        }
    },
    stylemap: parks_stylemap,
    asset_type: 'area',
    asset_item: 'park',
    non_interactive: true
});
fixmystreet.assets.add(parks_defaults, {
    asset_group: ["Parks and Greenspace"],
});
fixmystreet.assets.add(parks_defaults, {
    asset_category: ["Park Security OOH"]
});

var prow_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        fillOpacity: 0,
        strokeColor: "#660099",
        strokeOpacity: 0.5,
        strokeWidth: 6
    })
});

fixmystreet.assets.add(defaults, {
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
});

fixmystreet.assets.add(defaults, {
    http_options: { params: { TYPENAME: "Drains" } },
    asset_id_field: 'node_id',
    attributes: {
        feature_id: 'node_id'
    },
    asset_category: ["Blocked Drain"],
    asset_item: 'drain'
});

})();
