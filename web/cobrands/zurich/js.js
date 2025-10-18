$(function() {
    // Front page

    $( "#pc" ).autocomplete({
        minLength: 3,
        source: "/ajax/geocode"
    });

    /*
     * Admin things
     */

    // Row highlighting/clicking

    $('.row-link').on('mouseenter mouseleave', function(){
        $(this).toggleClass("active");
    }).on('click', function(){
        window.location = this.getElementsByTagName('a')[0];
    }).find('td:last-child').hide();

    $('th.edit').hide();

    // Map copy for printing

    if ($('.admin-report-edit--interact').length) {
        $('#map_box .noscript').clone().removeClass('noscript').addClass('map_clone print-only').prependTo('.admin-report-edit--interact');
    }

    // Response templates

    $('.js-template-name').on('change', function() {
        var $this = $(this);
        $('#' + $this.data('for')).val($this.val());
    });

    // Report editing

    var form_fields_changed = false;

    setTimeout(function(){
        $('.message-updated').fadeOut(250, function(){
            $(this).remove();
        });
    }, 5000);

    // When the user changes a select box, this bit of code
    // makes the labels for the other two select boxes grey.
    $('.assignation__select, .assignation select').on('change', function(){
        if (this.value === "") {
            $('.assignation').css('color', '#000');
        } else {
            var a = $(this).closest('li').css('color', '#000');
            $('.assignation select').not(this).val("");
            $('.assignation').not(a).css('color', '#999');
        }
    });

    $('form#report_edit #state').on('change', function(){
        // Show or hide the automatic reply field
        var state = $(this).val();

        // show or disable assignation, templates, public_response, publish if
        // same or different state to the one we started on
        if (state === $(this).data('pstate')) {
            $('input[name=publish_response]').show();
            $('.js-template-name').show();
            $('#status_update_container').show();

            if (state === 'confirmed') {
                $('#assignation__category').show();
                $('#assignation__subdivision').show();
            }
            if ((state === 'external') || (state === 'wish')) {
                $('#assignation__external').show();
            } else {
                $('#assignation__external').hide();
            }
        }
        else {
            $('input[name=publish_response]').hide();
            $('.js-template-name').hide();
            $('#status_update_container').hide();

            $('#assignation__category').hide();
            $('#assignation__subdivision').hide();
            $('#assignation__category select').val('');
            $('#assignation__subdivision select').val('');

            $('#assignation__external select').val('');
            $('#assignation__external').hide();
            $('#external_body').hide();
            $('#third_personal, label[for=third_personal]').hide();
        }

    }).trigger('change');

    $("form#report_edit input[type=submit]").on('click', function() {
        $("form#report_edit").data("clicked_button", $(this).attr("name"));
    });

    $("form#report_edit").on('submit', function() {
        // Make sure the external body field has a value if it's visible
        // and the form is submitted as a 'save' action (i.e. not a rotate
        // photo).
        var clicked = $(this).data("clicked_button");
        if (clicked == "publish_response" || clicked == "Submit changes") {
            var visible = $("select#body_external:visible").length > 0;
            var val = parseInt($("select#body_external").val(), 10);
            if (visible && isNaN(val)) {
                $("#assignation__external .error").removeClass("hidden");
                $("select#body_external").trigger('focus').get(0).scrollIntoView();
                return false;
            }
        }
        // If the user has clicked to rotate a photo and has edited other
        // fields, ask for confirmation before submitting the form
        if (/rotate_photo/.test(clicked) && form_fields_changed) {
            var message = $(this).find("input[name="+clicked+"]").parent().data('confirmMsg');
            if (!confirm(message)) {
                return false;
            }
        }
    });

    $("form#report_edit").find("input, select, textarea").on('change', function() {
        form_fields_changed = true;
    });

    /*
     * Hierarchical Attributes functionality
     */

    var $geschaftsbereichSelect = $('#hierarchical_Geschäftsbereich');
    var $objektSelect = $('#hierarchical_Objekt');
    var $kategorieSelect = $('#hierarchical_Kategorie');

    if ($geschaftsbereichSelect.length && $objektSelect.length && $kategorieSelect.length) {

        // Initially disable the second and third dropdowns
        $objektSelect.prop('disabled', true);
        $kategorieSelect.prop('disabled', true);

        // Filter options by parent ID
        var filterOptions = function($selectElement, parentId) {
            var $options = $selectElement.find('option[data-parent]');
            var hasVisibleOptions = false;

            $options.each(function() {
                var $option = $(this);
                var optionParentId = $option.data('parent').toString();

                if (parentId === '' || optionParentId === parentId) {
                    $option.show();
                    hasVisibleOptions = true;
                } else {
                    $option.hide();
                    if ($option.prop('selected')) {
                        $option.prop('selected', false);
                    }
                }
            });

            return hasVisibleOptions;
        };

        // Reset and disable dependent dropdowns when Geschäftsbereich changes
        var resetDependentDropdowns = function($selectElement) {
            $selectElement.val('').prop('disabled', true);
            $selectElement.find('option[data-parent]').hide();
        };

        // Handle Geschäftsbereich selection
        $geschaftsbereichSelect.on('change', function() {
            var selectedId = $(this).val();

            resetDependentDropdowns($objektSelect);
            resetDependentDropdowns($kategorieSelect);

            if (selectedId) {
                if (filterOptions($objektSelect, selectedId)) {
                    $objektSelect.prop('disabled', false);
                }

                if (filterOptions($kategorieSelect, selectedId)) {
                    $kategorieSelect.prop('disabled', false);
                }
            }
        });

        // Initialize dropdowns based on current selections
        var selectedGeschaftsbereich = $geschaftsbereichSelect.val();
        if (selectedGeschaftsbereich) {
            if (filterOptions($objektSelect, selectedGeschaftsbereich)) {
                $objektSelect.prop('disabled', false);
            }
            if (filterOptions($kategorieSelect, selectedGeschaftsbereich)) {
                $kategorieSelect.prop('disabled', false);
            }
        }
    }
});
