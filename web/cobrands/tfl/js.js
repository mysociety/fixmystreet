(function(){

if (!fixmystreet.maps) {
    return;
}

var org_id = '1250';
var body = "TfL";
fixmystreet.assets.add(fixmystreet.roadworks.layer_future, {
    http_options: { params: { organisation_id: org_id } },
    body: body
});
fixmystreet.assets.add(fixmystreet.roadworks.layer_planned, {
    http_options: { params: { organisation_id: org_id } },
    body: body
});

if (fixmystreet.cobrand == 'tfl') {
    // We want the cobranded site to always display "TfL"
    // as the destination for reports in the "Public details" section.
    // This is OK because the cobranded site only shows categories which
    // TfL actually handle.
    // To achieve this we ignore the passed list of bodies and always
    // use "TfL" when calling the original function.
    // NB calling the original function is required so that any private categories
    // cause the correct text to be shown in the UI.
    var original_update_public_councils_text = fixmystreet.update_public_councils_text;
    fixmystreet.update_public_councils_text = function(text, bodies) {
        original_update_public_councils_text.call(this, text, ['TfL']);
    };
}

})();
