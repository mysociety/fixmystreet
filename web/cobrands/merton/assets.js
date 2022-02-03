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

var tilma_url = fixmystreet.staging ? "https://tilma.staging.mysociety.org/mapserver/openusrn" : "https://tilma.mysociety.org/mapserver/openusrn";
var tilma_defaults = $.extend(true, {}, defaults, {
    wfs_url: tilma_url,
    srsName: "EPSG:3857",
    geometryName: 'geometry'
});

fixmystreet.assets.add(tilma_defaults, {
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

})();
