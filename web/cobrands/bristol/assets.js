(function(){

if (!fixmystreet.maps) {
    return;
}

// Assets are served from two different WFS feeds; one for lighting and one
// for everything else. They have some options in common:
var options = {
    max_resolution: {
        'bristol': 0.33072982812632296,
        'fixmystreet': 4.777314267158508
    },
    asset_type: 'spot',
    body: "Bristol City Council",
    srsName: "EPSG:27700",
    geometryName: 'SHAPE',
    wfs_url: "https://maps.bristol.gov.uk/arcgis/services/ext/FixMyStreetSupportData/MapServer/WFSServer",
    wfs_feature: "COD_ASSETS_POINT",
    asset_id_field: 'COD_ASSET_ID',
    propertyNames: [ 'COD_ASSET_ID', 'COD_USRN', 'SHAPE' ],
    filter_key: 'COD_ASSET_TYPE',
    attributes: {
        asset_id: 'COD_ASSET_ID',
        usrn: 'COD_USRN'
    }
};

fixmystreet.assets.add(options, {
    filter_key: '',
    wfs_feature: "COD_ASSETS_AREA",
    asset_type: 'area',
    asset_category: "Bridges/Subways",
    asset_item: 'bridge/subway'
});

fixmystreet.assets.add(options, {
    asset_category: "Gully/Drainage",
    asset_item: 'gully',
    filter_value: 'GULLY'
});

fixmystreet.assets.add(options, {
    asset_category: "Grit Bins",
    asset_item: 'grit bin',
    filter_value: 'GRITBIN'
});

fixmystreet.assets.add(options, {
    asset_category: "Flooding",
    asset_item: 'flood risk structure',
    filter_value: 'FRST'
});

fixmystreet.assets.add(options, {
    asset_category: "Street Light",
    asset_item: 'street light',
    filter_value: [ 'S070', 'S080', 'S100', 'S110', 'S120', 'S170', 'S220', 'S230' ]
});

fixmystreet.assets.add(options, {
    asset_category: "Zebra Crossing Light",
    asset_item: 'light',
    filter_value: 'S260'
});

// NB there's a typo in BCC's ‘Iluminated Bollard’ category so this
// includes the correct spelling just in case they fix it.
fixmystreet.assets.add(options, {
    asset_category: [ "Iluminated Bollard", "Illuminated Bollard" ],
    asset_item: 'bollard',
    filter_value: 'S020'
});

fixmystreet.assets.add(options, {
    asset_category: "Illuminated Sign",
    asset_item: 'sign',
    filter_value: 'S180'
});

})();
