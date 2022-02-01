(function(){

if (!fixmystreet.maps) {
    return;
}

var base_options = {
    max_resolution: {
        'bristol': 0.33072982812632296,
        'fixmystreet': 4.777314267158508
    },
    body: "Bristol City Council",
    geometryName: 'SHAPE'
};

var park_style = new OpenLayers.Style({
    fill: true,
    fillColor: "#1be547",
    fillOpacity: "0.25"
});

var park_style_map = new OpenLayers.StyleMap({
    default: park_style
});

// Assets are served from two different WFS feeds; one for lighting and one
// for everything else. They have some options in common:
var options = $.extend(true, {}, base_options, {
    asset_type: 'spot',
    srsName: "EPSG:27700",
    wfs_url: "https://maps.bristol.gov.uk/arcgis/services/ext/FixMyStreetSupportData/MapServer/WFSServer",
    wfs_feature: "COD_ASSETS_POINT",
    asset_id_field: 'COD_ASSET_ID',
    propertyNames: [ 'COD_ASSET_ID', 'COD_USRN', 'SHAPE' ],
    filter_key: 'COD_ASSET_TYPE',
    attributes: {
        asset_id: 'COD_ASSET_ID',
        usrn: 'COD_USRN'
    }
});

var parkOptions = $.extend(true, {}, base_options, {
    wfs_url: 'https://tilma.staging.mysociety.org/mapserver/bristol',
    wfs_feature: "parks",
    asset_type: 'area',
    asset_id_field: 'SITE_CODE',
    srsName: "EPSG:3857",
    stylemap: park_style_map,
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    road: true,
    non_interactive: true,
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: fixmystreet.message_controller.road_not_found
    }
});

fixmystreet.assets.add(parkOptions, {
    asset_category: ["Abandoned vehicle in park/open space",
                     "General litter",
                     "Graffiti issue",
                     "Flyposter removal",
                     "Grass cutting",
                     "Path cleaning",
                     "Hedge cutting",
                     "Vegetation clearance",
                     "Pothole/Trip hazard",
                     "Toilet issue/damage",
                     "Building damage",
                     "Wall/Fence/Gate damage",
                     "Lighting (park facilities)",
                     "Shrub/Rose maintenance"],
    asset_item: 'park'
});

fixmystreet.assets.add(options, {
    filter_key: '',
    wfs_feature: "COD_ASSETS_AREA",
    asset_type: 'area',
    asset_category: "Bridges/Subways",
    asset_item: 'bridge/subway'
});

fixmystreet.assets.add(options, {
    asset_category: "Grit bins",
    asset_item: 'grit bin',
    filter_value: 'GRITBIN'
});

fixmystreet.assets.add(options, {
    asset_category: "Street light",
    asset_item: 'street light',
    filter_value: [ 'S070', 'S080', 'S100', 'S110', 'S120', 'S170', 'S220', 'S230' ]
});

fixmystreet.assets.add(options, {
    asset_category: "Zebra crossing light",
    asset_item: 'light',
    filter_value: 'S260'
});

fixmystreet.assets.add(options, {
    asset_category: [ "Illuminated bollard" ],
    asset_item: 'bollard',
    filter_value: 'S020'
});

fixmystreet.assets.add(options, {
    asset_category: "Illuminated sign",
    asset_item: 'sign',
    filter_value: 'S180'
});

fixmystreet.assets.add(options, {
    asset_group: "Bus stops",
    asset_item: 'bus stop',
    filter_value: ['PT01', 'PT02', 'PT03']
});

fixmystreet.assets.add(options, {
    asset_category: "Flooding/Gully/Drainage",
    asset_item: 'gully or drain',
    filter_value: ['GULLY', 'FR02', 'FR03', 'FR07', 'FR18', 'FR10', 'FR16', 'FR14', 'FR13', 'FR06', 'FR09', 'FR12', 'FR15', 'FR08', 'FR11', 'FR20', 'FR19', 'FR05']
});

fixmystreet.assets.add(options, {
    asset_group: "Trees",
    asset_item: 'tree',
    filter_value: 'TR'
});

fixmystreet.assets.add(options, {
    asset_category: ["Bin full", "Bin/Seat damage"],
    asset_item: 'bin',
    filter_value: 'PF'
});

fixmystreet.assets.add(options, {
    asset_category: "Noticeboard/Signs",
    asset_item: 'sign',
    filter_value: 'PS'
});

})();
