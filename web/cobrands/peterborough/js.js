(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.mysociety.org/mapserver/peterborough",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    max_resolution: 4.777314267158508,
    min_resolution: 0.00001,
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

fixmystreet.assets.add(defaults, {
    http_options: {
        url: "https://tilma.staging.mysociety.org/mapserver/peterborough",
        params: {
            TYPENAME: "tree_groups"
        }
    },
    asset_id_field: 'TREE_CODE',
    attributes: {
        tree_code: 'TREE_CODE'
    },
    asset_type: 'area',
    asset_group: 'Trees',
    asset_item: 'tree group'
});

var NEW_TREE_CATEGORY_NAME = 'Request for tree to be planted';

fixmystreet.assets.add(defaults, {
    http_options: {
        url: "https://tilma.staging.mysociety.org/mapserver/peterborough",
        params: {
            TYPENAME: "tree_points"
        }
    },
    asset_id_field: 'TREE_CODE',
    attributes: {
        tree_code: 'TREE_CODE'
    },
    asset_type: 'spot',
    asset_group: 'Trees',
    asset_item: 'tree',
    relevant: function(options) {
        return options.group === 'Trees' && options.category !== NEW_TREE_CATEGORY_NAME;
    }
});

// We don't want to plant trees where the existing trees are, so add a
// separate layer with pin-snapping disabled for new tree requests.
// The new tree request category is disabled in the other tree point layer.
fixmystreet.assets.add(defaults, {
    http_options: {
        url: "https://tilma.staging.mysociety.org/mapserver/peterborough",
        params: {
            TYPENAME: "tree_points"
        }
    },
    asset_id_field: 'TREE_CODE',
    asset_type: 'spot',
    asset_category: NEW_TREE_CATEGORY_NAME,
    asset_item: 'tree',
    disable_pin_snapping: true
});

})();
