(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    max_resolution: 4.777314267158508,
    srsName: "EPSG:27700",
    body: "Merton Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var tilma_host = fixmystreet.staging ? "https://tilma.staging.mysociety.org/" : "https://tilma.mysociety.org/";

var tilma_defaults = $.extend(true, {}, defaults, {
    srsName: "EPSG:3857",
    geometryName: 'geometry'
});

fixmystreet.assets.add(tilma_defaults, {
    wfs_url: tilma_host + "mapserver/openusrn",
    wfs_feature: "usrn",
    filter_key: "street_type",
    filter_value: ["Designated Street Name", "Officially Described Street", "Unofficial Street Name"],
    nearest_radius: 50,
    stylemap: fixmystreet.assets.stylemap_invisible,
    non_interactive: true,
    always_visible: true,
    usrn: {
        attribute: 'usrn',
        field: 'usrn'
    },
    name: "usrn"
});

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'hover': fixmystreet.assets.style_default_hover,
  'select': fixmystreet.assets.construct_named_select_style("${UnitNumber}")
});

var labeled_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    stylemap: streetlight_stylemap,
    feature_code: 'UnitNumber',
    asset_type: 'spot',
    asset_id_field: 'UnitID',
    attributes: {
        UnitNumber: 'UnitNumber',
        UnitID: 'UnitID'
    },
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(labeled_defaults, {
    max_resolution: 1.194328566789627,
    http_options: {
        url: tilma_host + "mayrise.php?type=M"
    },
    format_class: OpenLayers.Format.GeoJSON,
    asset_group: ["Street light problems", "Street Light Problems"],
    asset_item: "street light"
});

fixmystreet.assets.add(labeled_defaults, {
    max_resolution: 1.194328566789627,
    http_options: {
        url: tilma_host + "mayrise.php?type=X"
    },
    format_class: OpenLayers.Format.GeoJSON,
    asset_category: "Faulty Christmas Lights",
    asset_item: "Christmas light"
});

})();
