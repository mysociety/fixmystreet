(function(){

if (!fixmystreet.maps) {
    return;
}

fixmystreet.assets.add($.extend(true, {}, fixmystreet.roadworks.layer_future, {
    http_options: { params: { organisation_id: '1070' } },
    body: "Lincolnshire County Council"
}));
// NB Lincs don't want forward planning works displayed, so
// fixmystreet.roadworks.layer_planned is deliberately missing here.

})();
