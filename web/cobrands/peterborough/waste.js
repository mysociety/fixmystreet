$(function() {
    // Ticking certain checkboxes should untick & disable others
    function setup_checkbox_toggles(selector, $other_checkboxes) {
        $(selector).on('change', function() {
            var checked = this.checked;
            $other_checkboxes.each(function() {
                // If this checkbox was disabled in the original page HTML,
                // we never want to enable it as a result of another checkbox
                // changing state.
                if ($(this).data("defaultDisabled") === undefined) {
                    $(this).data("defaultDisabled", this.disabled);
                }
                if ($(this).data("defaultDisabled")) {
                    return;
                }

                this.disabled = checked;
                if (checked) {
                    this.checked = false;
                }
                $(this).trigger('change');
            });
        });
    }

    setup_checkbox_toggles('#container-425-0', $('input[name|=container][type=checkbox]').not("#container-425-0"));
    setup_checkbox_toggles('#service-420-0', $('#service-537-0, #service-540-0'));
    setup_checkbox_toggles('#service-419-0', $('#service-538-0, #service-541-0'));
});
