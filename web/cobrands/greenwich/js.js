(function(){

if (!fixmystreet.maps) {
    return;
}

$(fixmystreet.add_assets({
    wfs_url: "https://warm-bastion-39610.herokuapp.com/wfs",
    wfs_feature: "streetlights",
    asset_category: "Street lighting",
    asset_item: 'street light',
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'Unit_Numbe',
    propertyNames: [ 'Unit_Numbe', 'the_geom' ],
    attributes: {
        column_id: 'Unit_Numbe'
    },
    geometryName: 'the_geom'
}));

})();
