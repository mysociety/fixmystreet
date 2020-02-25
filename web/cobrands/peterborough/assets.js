(function(){

if (!fixmystreet.maps) {
    return;
}


var defaults = {
    http_options: {
        url: fixmystreet.staging ? "https://tilma.staging.mysociety.org/mapserver/peterborough" : "https://tilma.mysociety.org/mapserver/peterborough",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    max_resolution: 4.777314267158508,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "Peterborough City Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "highways"
        }
    },
    stylemap: fixmystreet.assets.stylemap_invisible,
    non_interactive: true,
    always_visible: true,
    usrn: {
        attribute: 'Usrn',
        field: 'site_code'
    },
    name: "Adopted Highways"
});

// This is required so that the found/not found actions are fired on category
// select and pin move rather than just on asset select/not select.
OpenLayers.Layer.PeterboroughVectorAsset = OpenLayers.Class(OpenLayers.Layer.VectorAsset, {
    initialize: function(name, options) {
        OpenLayers.Layer.VectorAsset.prototype.initialize.apply(this, arguments);
        $(fixmystreet).on('maps:update_pin', this.checkSelected.bind(this));
        $(fixmystreet).on('report_new:category_change', this.checkSelected.bind(this));
    },

    CLASS_NAME: 'OpenLayers.Layer.PeterboroughVectorAsset'
});

var NEW_TREE_CATEGORY_NAME = 'Request for tree to be planted';

var trees_defaults = $.extend(true, {}, defaults, {
    class: OpenLayers.Layer.PeterboroughVectorAsset,
    select_action: true,
    actions: {
        asset_found: fixmystreet.message_controller.asset_found,
        asset_not_found: fixmystreet.message_controller.asset_not_found
    },
    attributes: {
        tree_code: 'TREE_CODE'
    },
    asset_id_field: 'TREE_CODE',
    asset_group: 'Trees',
    relevant: function(options) {
        return options.group === 'Trees' && options.category !== NEW_TREE_CATEGORY_NAME;
    }
});

fixmystreet.assets.add(trees_defaults, {
    http_options: {
        params: {
            TYPENAME: "tree_groups"
        }
    },
    asset_type: 'area',
    asset_item: 'tree group'
});

fixmystreet.assets.add(trees_defaults, {
    http_options: {
        params: {
            TYPENAME: "tree_points"
        }
    },
    asset_type: 'spot',
    asset_item: 'tree'
});

// We don't want to plant trees where the existing trees are, so add a
// separate layer with pin-snapping disabled for new tree requests.
// The new tree request category is disabled in the other tree point layer.
fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "tree_points"
        }
    },
    asset_id_field: 'TREE_CODE',
    asset_type: 'spot',
    asset_category: NEW_TREE_CATEGORY_NAME,
    asset_item: 'tree',
    disable_pin_snapping: true,
    asset_item_message: ''
});

})();
