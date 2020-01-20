(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.mysociety.org/mapserver/bromley_wfs",
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

OpenLayers.Layer.VectorAssetBromley = OpenLayers.Class(OpenLayers.Layer.VectorAsset, {
    relevant: function() {
        var relevant = OpenLayers.Layer.VectorAsset.prototype.relevant.apply(this, arguments),
            subcategories = this.fixmystreet.subcategories,
            subcategory = $('#form_service_sub_code').val(),
            relevant_sub = OpenLayers.Util.indexOf(subcategories, subcategory) > -1;
        return relevant && relevant_sub;
    },

    CLASS_NAME: 'OpenLayers.Layer.VectorAssetBromley'
});

fixmystreet.assets.add(defaults, {
    class: OpenLayers.Layer.VectorAssetBromley,
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
    subcategories: [ 'SL_LAMP', 'SL_NOT_WORK', 'SL_ON_DAY', 'SL_BLOCK_VEG' ],
    asset_item: 'street light'
});

fixmystreet.assets.add(defaults, {
    class: OpenLayers.Layer.VectorAssetBromley,
    http_options: {
        params: {
            TYPENAME: "Bins"
        }
    },
    asset_category: ["Parks and Greenspace", "Street Cleansing"],
    subcategories: ['PG_OFLOW_DOG', 'SC_LIT_BIN'],
    asset_item: 'park bin',
    asset_item_message: 'For our parks, pick a <b class="asset-spot">bin</b> from the map &raquo;'
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Street_Trees"
        }
    },
    asset_category: ["Public Trees"],
    asset_item: 'tree'
});

$(function(){
    $("#problem_form").on("change.category", "#form_service_sub_code", function() {
        $(fixmystreet).trigger('report_new:category_change');
    });
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

})();
