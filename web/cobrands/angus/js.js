(function(){

if (!fixmystreet.maps) {
    return;
}

$(fixmystreet.add_assets({
    wfs_url: "https://data.angus.gov.uk/geoserver/services/wfs",
    wfs_feature: "lighting_column_v",
    wfs_fault_feature: "lighting_faults_v",
    asset_category: "Street lighting",
    asset_item: 'street light',
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'n',
    attributes: {
        column_id: 'n'
    },
    geometryName: 'g'
}));

})();
