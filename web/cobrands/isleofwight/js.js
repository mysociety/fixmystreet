(function(){

if (!fixmystreet.maps) {
    return;
}

if (fixmystreet.cobrand == 'isleofwight') {
    // We want the cobranded site to always display "Island Roads"
    // as the destination for reports in the "Public details" section.
    // This is OK because the cobranded site only shows categories which
    // Island Roads actually handle.
    // To achieve this we ignore the passed list of bodies and always
    // use "Island Roads" when calling the original function.
    // NB calling the original function is required so that private categories
    // cause the correct text to be shown in the UI.
    var original_update_public_councils_text = fixmystreet.update_public_councils_text;
    fixmystreet.update_public_councils_text = function(text, bodies) {
        original_update_public_councils_text.call(this, text, ['Island Roads']);
    };
}

})();
