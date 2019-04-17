(function(){

if (!fixmystreet.maps) {
    return;
}

var org_id = '1089';
var body = "Northamptonshire County Council";

fixmystreet.assets.add(fixmystreet.roadworks.layer_future, {
    http_options: { params: { organisation_id: org_id } },
    body: body
});
fixmystreet.assets.add(fixmystreet.roadworks.layer_planned, {
    http_options: { params: { organisation_id: org_id } },
    body: body
});

})();
