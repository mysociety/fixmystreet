(function(){

if (!fixmystreet.maps) {
    return;
}

if (fixmystreet.cobrand == 'isleofwight') {
    // We want the cobranded site to always display "Island Roads"
    // as the destination for reports in the "Public details" section.
    // This is OK because the cobranded site only shows categories which
    // Island Roads actually handle.
    // Replacing this function with a no-op stops the changes made
    // to the cobranded councils_text_all.html from being clobbered and
    // the 'correct' (according to bodies set up within FMS) body names
    // being shown.
    fixmystreet.update_public_councils_text = function() {};
}

var org_id = '1062';
var body = "Isle of Wight Council";
fixmystreet.assets.add(fixmystreet.roadworks.layer_future, {
    http_options: { params: { organisation_id: org_id } },
    body: body
});
fixmystreet.assets.add(fixmystreet.roadworks.layer_planned, {
    http_options: { params: { organisation_id: org_id } },
    body: body
});

})();
