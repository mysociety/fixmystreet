(function(){

if (!fixmystreet.maps) {
    return;
}

// Assets are served from two different WFS feeds; one for lighting and one
// for everything else. They have some options in common:
var common_options = {
    max_resolution: {
        'bristol': 0.33072982812632296,
        'fixmystreet': 4.777314267158508
    },
    min_resolution: 0.00001,
    asset_type: 'spot',
    body: "Bristol City Council",
    srsName: "EPSG:27700",
    geometryName: 'SHAPE'
};


var options = $.extend({}, common_options, {
    wfs_url: "https://maps.bristol.gov.uk/arcgis/services/ext/FixMyStreetSupportData/MapServer/WFSServer",
    wfs_feature: "COD_ASSETS_POINT",
    asset_id_field: 'COD_ASSET_ID',
    propertyNames: [ 'COD_ASSET_ID', 'COD_USRN', 'COD_ASSET_TYPE' ],
    attributes: {
        asset_id: 'COD_ASSET_ID',
        usrn: 'COD_USRN'
    }
});

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


var lighting_options = $.extend({}, common_options, {
    wfs_url: "https://maps.bristol.gov.uk/arcgis/services/ext/datagov/MapServer/WFSServer",
    wfs_feature: "Streetlights",
    asset_id_field: 'Unit_ID',
    propertyNames: [ 'USRN', 'Unit_ID', 'Unit_type_description' ],
    attributes: {
        asset_id: function() {
            if (this.attributes && this.attributes.Unit_ID) {
                if (this.attributes.Unit_ID.match(/^SL/)) {
                    // Just in case they ever start prefixing it in the WFS...
                    return this.attributes.Unit_ID;
                } else {
                    return "SL" + this.attributes.Unit_ID;
                }
            } else {
                return "";
            }
        },
        usrn: 'USRN'
    },
    filter_key: 'Unit_type_description'
});

fixmystreet.assets.add($.extend({}, lighting_options, {
    asset_category: "Street Light",
    asset_item: 'street light',
    filter_value: [
        'SL: Street Light',
        'SL: Silverspring CMS',
        'SL: Philips CMS',
        'SL: Feature Fld.Lgt',
        'SL: Gas Light',
        'SL: High Mast',
        'SL: Refuge Column',
        'SL: Subway'
    ]
}));

fixmystreet.assets.add($.extend({}, lighting_options, {
    asset_category: "Zebra Crossing Light",
    asset_item: 'light',
    filter_value: 'SL: Zebra'
}));

fixmystreet.assets.add($.extend({}, lighting_options, {
    asset_category: "Iluminated Bollard",
    asset_item: 'bollard',
    filter_value: 'SL: Bollard'
}));

// NB there's a typo in BCC's ‘Iluminated Bollard’ category so this repeats
// the above (without the typo) just in case they fix it.
fixmystreet.assets.add($.extend({}, lighting_options, {
    asset_category: "Illuminated Bollard",
    asset_item: 'bollard',
    filter_value: 'SL: Bollard'
}));

fixmystreet.assets.add($.extend({}, lighting_options, {
    asset_category: "Illuminated Sign",
    asset_item: 'sign',
    filter_value: 'SL: Sign'
}));

})();
