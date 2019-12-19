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
    min_resolution: 0.5971642833948135,
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
    asset_item: 'tree'
});

})();
