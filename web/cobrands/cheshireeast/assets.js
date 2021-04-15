(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    wfs_url: "https://tilma.mysociety.org/mapserver/cheshireeast",
    max_resolution: {
        fixmystreet: 4.777314267158508,
        cheshireeast: 1.4000028000056002
    },
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'site_code'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    body: "Cheshire East Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${feature_id}")
});

var labeled_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    stylemap: streetlight_stylemap,
    asset_type: 'spot',
    asset_id_field: 'central_as',
    feature_code: 'feature_id',
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(labeled_defaults, {
    wfs_feature: 'StreetLights',
    filter_key: 'feature_gr',
    filter_value: 'LCOL',
    asset_group: 'Street lights',
    asset_item: 'street light'
});

var cleaning_cats = [
  'Dead Animals',
  'Dog Fouling',
  'Fly Posting',
  'Fly Tipping',
  'Graffiti',
  'Litter and Bins',
  'Needles, Syringes or Glass',
  'Play Area Safety Issue',
  'Street Sweeping',
  'Abandoned Vehicles - Not Taxed',
  'Abandoned Vehicles - Taxed'
];

fixmystreet.assets.add(defaults, {
    stylemap: fixmystreet.assets.stylemap_invisible,
    always_visible: true,
    non_interactive: true,
    wfs_feature: 'AdoptedRoads',
    usrn: {
        attribute: 'site_code',
        field: 'site_code'
    },
    road: true,
    no_asset_msg_id: '#js-not-a-road',
    asset_item: 'road',
    asset_type: 'road',
    all_categories: true,
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: function(layer) {
            var cat = $('select#form_category').val();
            if (OpenLayers.Util.indexOf(cleaning_cats, cat) != -1) {
              fixmystreet.message_controller.road_found(layer);
            } else {
              fixmystreet.message_controller.road_not_found(layer);
            }
        }
    }
});

})();
