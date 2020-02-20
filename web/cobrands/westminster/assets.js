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
            subcategory = $(this.fixmystreet.subcategory_id).val(),
            relevant_sub = OpenLayers.Util.indexOf(subcategories, subcategory) > -1;
        return relevant && relevant_sub;
    },
    CLASS_NAME: 'SubcatMixin'
});
OpenLayers.Layer.VectorAssetWestminsterSubcat = OpenLayers.Class(OpenLayers.Layer.VectorAsset, SubcatMixin, {
    CLASS_NAME: 'OpenLayers.Layer.VectorAssetWestminsterSubcat'
});

// This is required so that the found/not found actions are fired on category
// select and pin move rather than just on asset select/not select.
function uprn_init(name, options) {
    OpenLayers.Layer.VectorAsset.prototype.initialize.apply(this, arguments);
    $(fixmystreet).on('report_new:category_change', this.checkSelected.bind(this));
}
OpenLayers.Layer.VectorAssetWestminsterUPRN = OpenLayers.Class(OpenLayers.Layer.VectorAsset, {
    initialize: function(name, options) { uprn_init.apply(this, arguments); },
    CLASS_NAME: 'OpenLayers.Layer.VectorAssetWestminsterUPRN'
});
OpenLayers.Layer.VectorAssetWestminsterSubcatUPRN = OpenLayers.Class(OpenLayers.Layer.VectorAsset, SubcatMixin, {
    cls: OpenLayers.Layer.VectorAsset,
    initialize: function(name, options) { uprn_init.apply(this, arguments); },
    CLASS_NAME: 'OpenLayers.Layer.VectorAssetWestminsterSubcatUPRN'
});

var url_base = 'https://tilma.mysociety.org/resource-proxy/proxy.php?https://westminster.assets/';

var defaults = {
    http_options: {
        params: {
            inSR: '4326',
            f: 'geojson'
        }
    },
    asset_type: 'spot',
    max_resolution: 4.777314267158508,
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

var layer_data = [
    { category: [ 'Food safety/hygiene' ] },
    { category: 'Damaged, dirty, or missing bin', subcategories: [ '1', '4' ], subcategory_id: '#form_bin_type' },
    { category: 'Noise', subcategories: [ '1', '3', '4', '7', '8', '9', '10' ] },
    { category: 'Smoke and odours' },
];

function uprn_sort(a, b) {
    a = a.attributes.ADDRESS;
    b = b.attributes.ADDRESS;
    var a_flat = a.match(/^(Flat|Unit)s? (\d+)/);
    var b_flat = b.match(/^(Flat|Unit)s? (\d+)/);
    if (a_flat && b_flat && a_flat[1] === b_flat[1]) {
        return a_flat[2] - b_flat[2];
    }
    return a.localeCompare(b);
}

var old_uprn;

function add_to_uprn_select($select, assets) {
    assets.sort(uprn_sort);
    $.each(assets, function(i, f) {
        $select.append('<option value="' + f.attributes.UPRN + '">' + f.attributes.ADDRESS + '</option>');
    });
    if (old_uprn && $select.find('option[value=\"' + old_uprn + '\"]').length) {
        $select.val(old_uprn);
    }
}

function construct_uprn_select(assets, has_children) {
    old_uprn = $('#uprn').val();
    $("#uprn_select").remove();
    $('.category_meta_message').html('');
    var $div = $('<div class="extra-category-questions" id="uprn_select">');
    if (assets.length > 1 || has_children) {
        $div.append('<label for="uprn">Please choose a property:</label>');
        var $select = $('<select id="uprn" class="form-control" name="UPRN" required>');
        $select.append('<option value="">---</option>');
        add_to_uprn_select($select, assets);
        $div.append($select);
    } else {
        $div.html('You have selected <b>' + assets[0].attributes.ADDRESS + '</b>');
    }
    $div.appendTo('#js-post-category-messages');
}

$.each(layer_data, function(i, o) {
    var params = {
        class: OpenLayers.Layer.VectorAssetWestminsterUPRN,
        asset_category: o.category,
        asset_item: 'property',
        http_options: {
            url: url_base + '25/query?',
            params: {
                where: "PARENTUPRN='XXXX' AND PROPERTYTYPE NOT IN ('Pay Phone','Street Record')",
                outFields: 'UPRN,Address,ParentChild'
            }
        },
        max_resolution: 0.5971642833948135,
        select_action: true,
        attributes: {
            'UPRN': 'UPRN'
        },
        actions: {
            asset_found: function(asset) {
                if (fixmystreet.message_controller.asset_found()) {
                    return;
                }
                var lonlat = asset.geometry.getBounds().getCenterLonLat();
                var overlap_threshold = 1; // Features considered overlapping if within 1m of each other
                var overlapping_features = this.getFeaturesWithinDistance(
                    new OpenLayers.Geometry.Point(lonlat.lon, lonlat.lat),
                    overlap_threshold
                );

                var parent_uprns = [];
                $.each(overlapping_features, function(i, f) {
                    if (f.attributes.PARENTCHILD === 'Parent') {
                        parent_uprns.push("PARENTUPRN='" + f.attributes.UPRN + "'");
                    }
                });
                parent_uprns = parent_uprns.join(' OR ');

                if (parent_uprns) {
                    var url = url_base + '25/query?' + OpenLayers.Util.getParameterString({
                        inSR: 4326,
                        f: 'geojson',
                        outFields: 'UPRN,Address',
                        where: parent_uprns
                    });
                    $.getJSON(url, function(data) {
                        var features = [];
                        $.each(data.features, function(i, f) {
                            features.push({ attributes: f.properties });
                        });
                        add_to_uprn_select($('#uprn'), features);
                    });
                }
                construct_uprn_select(overlapping_features, parent_uprns);
            },
            asset_not_found: function() {
                $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
                $("#uprn_select").remove();
                fixmystreet.message_controller.asset_not_found.call(this);
            }
        }
    };

    if (o.subcategories) {
        params.class = OpenLayers.Layer.VectorAssetWestminsterSubcatUPRN;
        params.subcategories = o.subcategories;
        params.subcategory_id = o.subcategory_id || '#form_type';
    }

    fixmystreet.assets.add(defaults, params);
});

layer_data = [
    { group: 'Street lights', item: 'street light', layers: [ 18, 50, 60 ] },
    { category: 'Pavement damage', layers: [ 14 ], road: true },
    { category: 'Pothole', layers: [ 11, 44 ], road: true },
    { group: 'Drains', item: 'drain', layers: [ 16 ] },

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
        params.subcategory_id = o.subcategory_id || '#form_type';
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
    $("#problem_form").on("change.category", "#form_type, #form_featuretypecode, #form_bin_type", function() {
        $(fixmystreet).trigger('report_new:category_change');
    });
});

})();
