(function(){

if (!fixmystreet.maps) {
    return;
}

var org_id = '1015';
var body = "Bristol City Council";
fixmystreet.assets.add(fixmystreet.roadworks.layer_future, {
    http_options: { params: { organisation_id: org_id } },
    body: body
});
fixmystreet.assets.add(fixmystreet.roadworks.layer_planned, {
    http_options: { params: { organisation_id: org_id } },
    body: body
});

fixmystreet.roadworks.config = {
    summary_heading_text: 'Location',
    extra_dates_text: '<small>Please note that dates are updated by the contractor carrying out the works and the finish date may be incorrect in cases of unauthorised or overrunning works</small>',
    skip_delays: true
};

})();
