$(function() {
    // Ticking certain checkboxes should untick & disable others
    function setup_checkbox_toggles(selector, $other_checkboxes) {
        $(selector).on('change', function() {
            var checked = this.checked;
            $other_checkboxes.each(function() {
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
