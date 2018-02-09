(function(){

if (!fixmystreet.maps) {
    return;
}

var options = {
    wfs_url: "https://maps.bristol.gov.uk/arcgis/services/ext/FixMyStreetSupportData/MapServer/WFSServer",
    wfs_feature: "COD_ASSETS_POINT",
    max_resolution: 0.33072982812632296,
    min_resolution: 0.00001,
    asset_id_field: 'COD_ASSET_ID',
    asset_type: 'spot',
    propertyNames: [ 'COD_ASSET_ID', 'COD_USRN' ],
    attributes: {
        asset_id: 'COD_ASSET_ID',
        usrn: 'COD_USRN'
    },
    geometryName: 'SHAPE'
};

fixmystreet.assets.add($.extend({}, options, {
    wfs_feature: "COD_ASSETS_AREA",
    asset_type: 'area',
    asset_category: "Bridges/Subways",
    asset_item: 'bridge/subway'
}));

fixmystreet.assets.add($.extend({}, options, {
    asset_category: "Gully/Drainage",
    asset_item: 'gully',
    filter_key: 'COD_ASSET_TYPE',
    filter_value: 'GULLY'
}));

fixmystreet.assets.add($.extend({}, options, {
    asset_category: "Grit Bins",
    asset_item: 'grit bin',
    filter_key: 'COD_ASSET_TYPE',
    filter_value: 'GRITBIN'
}));

fixmystreet.assets.add($.extend({}, options, {
    asset_category: "Street Lighting",
    asset_item: 'street light',
    filter_key: 'COD_ASSET_TYPE',
    filter_value: 'SL'
}));

})();
