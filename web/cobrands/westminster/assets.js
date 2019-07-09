(function(){

if (!fixmystreet.maps) {
    return;
}

/* First let us set up some necessary subclasses */

/* ArcGIS wants to receive the bounding box as a 'geometry' parameter, not 'bbox' */
var format = new OpenLayers.Format.QueryStringFilter();
OpenLayers.Protocol.Westminster = OpenLayers.Class(OpenLayers.Protocol.HTTP, {
    filterToParams: function(filter, params) {
        params = format.write(filter, params);
        params.geometry = params.bbox;
        delete params.bbox;
        return params;
    },
    CLASS_NAME: "OpenLayers.Protocol.Westminster"
});

/* This layer is relevant depending upon the category *and* the choice of the 'type' Open311 extra attribute question */
var SubcatMixin = OpenLayers.Class({
    relevant: function() {
        var relevant = OpenLayers.Layer.VectorAsset.prototype.relevant.apply(this, arguments),
            subcategories = this.fixmystreet.subcategories,
            subcategory = $('#form_type').val(),
            relevant_sub = OpenLayers.Util.indexOf(subcategories, subcategory) > -1;
        return relevant && relevant_sub;
    },
    CLASS_NAME: 'SubcatMixin'
});
OpenLayers.Layer.VectorAssetWestminsterSubcat = OpenLayers.Class(OpenLayers.Layer.VectorAsset, SubcatMixin, {
    CLASS_NAME: 'OpenLayers.Layer.VectorAssetWestminsterSubcat'
});

var url_base = 'https://tilma.staging.mysociety.org/resource-proxy/proxy.php?https://westminster.assets/';

var defaults = {
    http_options: {
        params: {
            inSR: '4326',
            f: 'geojson'
        }
    },
    asset_type: 'spot',
    max_resolution: 4.777314267158508,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'central_asset_id',
    srsName: "EPSG:4326",
    body: "Westminster City Council",
    format_class: OpenLayers.Format.GeoJSON,
    format_options: {ignoreExtraDims: true},
    protocol_class: OpenLayers.Protocol.Westminster,
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add(defaults, {
    http_options: {
        url: url_base + '40/query?',
        params: {
            outFields: 'USRN'
        }
    },
    all_categories: true,
    always_visible: true,
    non_interactive: true,
    stylemap: fixmystreet.assets.stylemap_invisible,
    nearest_radius: 100,
    usrn: {
        attribute: 'USRN',
        field: 'USRN'
    }
});

var tfl_categories = [ 'Pavement damage', 'Pothole', 'Road pavement damage', 'Road or pavement damage' ];

fixmystreet.assets.add(defaults, {
    http_options: {
        url: url_base + '2/query?'
    },
    asset_category: tfl_categories,
    non_interactive: true,
    road: true,
    nearest_radius: 25,
    stylemap: fixmystreet.assets.stylemap_invisible,
    actions: {
        found: function(layer, feature) {
            if (!fixmystreet.assets.selectedFeature()) {
                fixmystreet.body_overrides.only_send('TfL');
            } else {
                fixmystreet.body_overrides.remove_only_send();
            }
        },
        not_found: function(layer) {
            fixmystreet.body_overrides.remove_only_send();
        }
    }
});

var layer_data = [
    { group: 'Street lights', item: 'street light', layers: [ 18, 50, 60 ] },
    { category: 'Pavement damage', layers: [ 14 ], road: true },
    { category: 'Pothole', layers: [ 11, 44 ], road: true },
    { group: 'Drains', item: 'gully', layers: [ 16 ] },

    { category: 'Signs and bollards', subcategories: [ '1' ], subcategory_id: '#form_featuretypecode', item: 'bollard', layers: [ 42, 52 ] },
    { category: 'Signs and bollards', subcategories: [ 'PLFP' ], subcategory_id: '#form_featuretypecode', item: 'feeder pillar', layers: [ 56 ] },
    { category: 'Signs and bollards', subcategories: [ '3' ], subcategory_id: '#form_featuretypecode', item: 'sign', layers: [ 48, 58, 54 ] },
    { category: 'Signs and bollards', subcategories: [ '2' ], subcategory_id: '#form_featuretypecode', item: 'street nameplate', layers: [ 46 ] }
];

$.each(layer_data, function(i, o) {
    var layers_added = [];
    var attr = 'central_asset_id';
    var params = $.extend(true, {}, defaults, {
        asset_category: o.category,
        asset_item: o.item,
        http_options: {
            params: {
                outFields: attr
            }
        },
        attributes: {}
    });

    if (o.group) {
        params.asset_group = o.group;
    } else if (o.subcategories) {
        params.class = OpenLayers.Layer.VectorAssetWestminsterSubcat;
        params.subcategories = o.subcategories;
    }

    if (o.road) {
        params.non_interactive = true;
        params.nearest_radius = 100;
        params.stylemap = fixmystreet.assets.stylemap_invisible;
        params.usrn = {
            attribute: attr,
            field: attr
        };
    } else {
        params.attributes[attr] = attr;
    }

    $.each(o.layers, function(i, l) {
        var layer_url = { http_options: { url: url_base + l + '/query?' } };
        var options = $.extend(true, {}, params, layer_url);
        layers_added.push(fixmystreet.assets.add_layer(options));
    });
    fixmystreet.assets.add_controls(layers_added, params);
});

$(function(){
    $("#problem_form").on("change.category", "#form_type, #form_featuretypecode", function() {
        $(fixmystreet).trigger('report_new:category_change', [ $('#form_category') ]);
    });
});

fixmystreet.message_controller.register_category({
    body: defaults.body,
    category: 'Burst water main',
    message: 'To report a burst water main, please <a href="https://www.thameswater.co.uk/help-and-advice/Report-a-problem/Report-a-problem">contact Thames Water</a>'
});

})();
