(function () {

    if (!fixmystreet.maps) {
        return;
    }

    var domain = fixmystreet.staging ? "https://tilma.staging.mysociety.org" : "https://tilma.mysociety.org";
    var defaults = {
        http_wfs_url: domain + "/mapserver/camden",
        asset_type: 'spot',
        max_resolution: 9.554628534317017,
        geometryName: 'msGeometry',
        srsName: "EPSG:3857",
        body: "Camden Borough Council"
    };

    fixmystreet.assets.add(defaults, {
        wfs_feature: "Streets",
        stylemap: fixmystreet.assets.stylemap_invisible,
        non_interactive: true,
        always_visible: true,
        road: true,
        all_categories: true,
        usrn: {
            attribute: 'NSG_REF',
            field: 'NSGRef'
        },
        actions: {
            found: function (layer, feature) {
                console.log("found", layer, feature);
            },
            not_found: function (layer) {
                console.log("not found");
            }
        },
        asset_item: "road",
        asset_type: 'road',
        no_asset_msg_id: '#js-not-a-road',
        no_asset_msgs_class: '.js-roads-camden',
        name: "Streets"
    });

})();
