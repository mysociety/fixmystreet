(function(){

if (!fixmystreet.maps) {
    return;
}

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

$(function() {
    function update_category_group_label() {
        var group = $("#report_inspect_form select#category option:selected").closest("optgroup").attr('label');
        var $label = $("#report_inspect_form select#category").closest("p").find("label");
        if (group) {
            $label.text("Category (" + group + ")");
        } else {
            $label.text("Category");
        }
    }
    $(document).on('change', "#report_inspect_form select#category", update_category_group_label);
    $(fixmystreet).on('display:report', update_category_group_label);
    update_category_group_label();
});

})();
