fixmystreet.maps.tile_base = [ [ "", "a-" ], "https://{S}fix.bromley.gov.uk/tilma" ];

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
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'CENTRAL_AS',
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
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
    asset_category: ["Faulty street light"],
    asset_item: 'street light'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Bins"
        }
    },
    asset_category: ["Overflowing litter bin"],
    asset_item: 'park bin',
    asset_item_message: 'For our parks, pick a <b class="asset-spot">bin</b> from the map &raquo;'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Street_Trees"
        }
    },
    asset_category: ["Public Tree related issue"],
    asset_item: 'tree'
}));

var highways_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        stroke: false
    })
});

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "TFL_Red_Route"
        }
    },
    stylemap: highways_stylemap,
    always_visible: true,
    asset_category: ["Blocked drains", "Faulty street light", 'Faulty street sign', 'Floral displays', 'Grass needs cutting', 'Obstructions (skips, A boards)', 'Overhanging vegetation from private land', 'Pavement defect', 'Public Tree related issue', "Road defect"],
    non_interactive: true,
    road: true,
    actions: {
        found: function(layer) {
            if (fixmystreet.assets.selectedFeature()) {
                $('#road-warning').remove();
                return;
            }
            var msg = 'The location selected is a Transport for London Red Route. TfL are responsible for the reported category and can be alerted to issues via: <a href="https://tfl.gov.uk/help-and-contact/contact-us-about-streets-and-other-road-issues">Street issues</a>';
            if ( $('#road-warning').length ) {
                $('#road-warning').html(msg);
            } else {
                $('.change_location').after('<div class="box-warning" id="road-warning">' + msg + '</div>');
            }
            $('#single_body_only').val(layer.fixmystreet.body_found);
        },

        not_found: function(layer) {
            if ( $('#road-warning').length ) {
                $('#road-warning').remove();
            }
            $('#single_body_only').val(layer.fixmystreet.body_council);
        }
    },
    body_found: 'TfL',
    body_council: 'Bromley Council'
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
