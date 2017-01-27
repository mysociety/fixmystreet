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

    $('.row-link').hover(function(){
        $(this).toggleClass("active");
    }).click(function(){
        window.location = this.getElementsByTagName('a')[0];
    }).find('td:last').hide();

    $('th.edit').hide();

    // Map copy for printing

    if ($('.admin-report-edit--interact').length) {
        $('#map_box .noscript').clone().removeClass('noscript').addClass('map_clone print-only').prependTo('.admin-report-edit--interact');
    }

    // Response templates

    $('.js-template-name').change(function() {
        var $this = $(this);
        $('#' + $this.data('for')).val($this.val());
    });

    // Report editing

    var form_fields_changed = false;

    $('#form_time_spent').spinner({
        spin: function (e, ui) {
            if (ui.value < 0) { return false; }
            form_fields_changed = true;
        }
    });

    setTimeout(function(){
        $('.message-updated').fadeOut(250, function(){
            $(this).remove();
        });
    }, 5000);

    // When the user changes a select box, this bit of code
    // makes the labels for the other two select boxes grey.
    $('.assignation__select, .assignation select').change(function(){
        if (this.value === "") {
            $('.assignation').css('color', '#000');
        } else {
            var a = $(this).closest('li').css('color', '#000');
            $('.assignation select').not(this).val("");
            $('.assignation').not(a).css('color', '#999');
        }
    });

    $('form#report_edit #state').change(function(){
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
            if ((state === 'closed') || (state === 'investigating')) {
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

    }).change();

    $("form#report_edit input[type=submit]").click(function() {
        $("form#report_edit").data("clicked_button", $(this).attr("name"));
    });

    $("form#report_edit").submit(function() {
        // Make sure the external body field has a value if it's visible
        // and the form is submitted as a 'save' action (i.e. not a rotate
        // photo).
        var clicked = $(this).data("clicked_button");
        if (clicked == "publish_response" || clicked == "Submit changes") {
            var visible = $("select#body_external:visible").length > 0;
            var val = parseInt($("select#body_external").val(), 10);
            if (visible && isNaN(val)) {
                $("#assignation__external .error").removeClass("hidden");
                $("select#body_external").focus().get(0).scrollIntoView();
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

    $("form#report_edit").find("input, select, textarea").change(function() {
        form_fields_changed = true;
    });
});
