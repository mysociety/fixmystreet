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
    // To achieve this we ignore the passed list of bodies and always
    // use "Hounslow Highways" when calling the original function.
    // NB calling the original function is required so that private categories
    // cause the correct text to be shown in the UI.
    var original_update_public_councils_text = fixmystreet.update_public_councils_text;
    fixmystreet.update_public_councils_text = function(text, bodies) {
        original_update_public_councils_text.call(this, text, ['Hounslow Highways']);
    };
}

})();
