(function(){

if (!fixmystreet.maps) {
    return;
}

var org_id = '5540';
var body = "Hounslow Borough Council";
fixmystreet.assets.add($.extend(true, {}, fixmystreet.roadworks.layer_future, {
    http_options: { params: { organisation_id: org_id } },
    body: body
}));
fixmystreet.assets.add($.extend(true, {}, fixmystreet.roadworks.layer_planned, {
    http_options: { params: { organisation_id: org_id } },
    body: body
}));

if (fixmystreet.cobrand == 'hounslow') {
    // We want the cobranded site to always display "Hounslow Highways"
    // as the destination for reports in the "Public details" section.
    // This is OK because the cobranded site only shows categories which
    // Hounslow Highways actually handle.
    // Replacing this function with a no-op stops the changes made
    // to the cobranded councils_text_all.html from being clobbered and
    // the 'correct' (according to bodies set up within FMS) body names
    // being shown.
    fixmystreet.update_public_councils_text = function() {};
}

})();
