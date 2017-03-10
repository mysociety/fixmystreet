(function(){

if (!fixmystreet.maps) {
    return;
}

$(fixmystreet.add_assets({
    wfs_url: "http://royalaf3.miniserver.com:8080/geoserver/gis-shp/ows?service=WFS",
    wfs_feature: "gis-shp:Streetlights",
    asset_category: "Street lighting",
    asset_item: 'street light',
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'gml:id',
    attributes: {
        column_id: 'gml:id'
    },
    geometryName: 'the_geom'
}));

})();
