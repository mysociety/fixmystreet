(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    wfs_url: 'https://maps.cheshireeast.gov.uk/geoserver/CEFixMyStreet/wfs',
    max_resolution: {
        fixmystreet: 4.777314267158508,
        cheshireeast: 1.4000028000056002
    },
    attributes: {
        central_asset_id: 'central_asset_id',
        site_code: 'site_code'
    },
    geometryName: 'ogr_geometry',
    srsName: "EPSG:27700",
    body: "Cheshire East Council"
};

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${asset_id}")
});

var labeled_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    stylemap: streetlight_stylemap,
    asset_type: 'spot',
    asset_id_field: 'central_asset_id',
    feature_code: 'asset_id',
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(labeled_defaults, {
    wfs_feature: 'TN_S_CODStreetLights_POINT_CURRENT',
    propertyNames: ['central_asset_id', 'asset_id', 'site_code', 'ogr_geometry'],
    asset_group: 'Street lights',
    asset_item: 'street light'
});

fixmystreet.assets.add(defaults, {
    stylemap: fixmystreet.assets.stylemap_invisible,
    non_interactive: true,
    wfs_feature: 'TN_S_CODAdoptedStreetSections_LINE_CURRENT',
    propertyNames: ['site_code', 'ogr_geometry'],
    usrn: {
        attribute: 'site_code',
        field: 'site_code'
    },
    road: true,
    no_asset_msg_id: '#js-not-a-road',
    asset_item: 'road',
    asset_type: 'road',
    asset_group: [
        'Crossings',
        'Drainage',
        'Fencing or Walls',
        'Hedge, Trees and Verges',
        'Pavement (Footway)',
        'Road (Carriageway)',
        'Signs',
        'Street lights',
        'Winter'
    ],
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: fixmystreet.message_controller.road_not_found
    }
});

})();
