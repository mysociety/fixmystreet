/*
 * fixmystreet.js
 * FixMyStreet JavaScript
 */

$(function(){

    $('#pc').focus();

    $('input[type=submit]').removeAttr('disabled');
    /*
    $('#mapForm').submit(function() {
        if (this.submit_problem) {
            $('input[type=submit]', this).prop("disabled", true);
        }
        return true;
    });
    */

    if (!$('#been_fixed_no').prop('checked') && !$('#been_fixed_unknown').prop('checked')) {
        $('#another_qn').hide();
    }
    $('#been_fixed_no').click(function() {
        $('#another_qn').show('fast');
    });
    $('#been_fixed_unknown').click(function() {
        $('#another_qn').show('fast');
    });
    $('#been_fixed_yes').click(function() {
        $('#another_qn').hide('fast');
    });

    var timer;
    function email_alert_close() {
        $('#email_alert_box').hide('fast');
    }

    // FIXME - needs to use translated string
    jQuery.validator.addMethod('validCategory', function(value, element) {
        return this.optional(element) || value != '-- Pick a category --'; }, validation_strings['category'] );

    // TODO - test in older browsers
    jQuery.validator.addMethod('validName', function(value, element) {
        var validNamePat = /\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
        return this.optional(element) || value.length > 5 && value.match( /\S/ ) && !value.match( validNamePat ) }, validation_strings['category'] );

    var form_submitted = 0;

    $("form.validate").validate({
        messages: validation_strings,
        onkeyup: false,
        errorElement: 'div',
        errorClass: 'form-error',
        // we do this to stop things jumping around on blur
        success: function (err) { if ( form_submitted ) { err.addClass('label-valid').html( '&nbsp;' ); } else { err.addClass('label-valid-hidden'); } },
        errorPlacement: function( error, element ) {
            element.parent('div').before( error );
        },
        submitHandler: function(form) {
            if (form.submit_problem) {
                $('input[type=submit]', form).prop("disabled", true);
            }

            form.submit();
        },
    });

    $('input[type=submit]').click( function(e) { form_submitted = 1; } );

    /* set correct required status depending on what we submit */
    $('#submit_sign_in').click( function(e) {
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').removeClass();
    } );

    $('#submit_register').click( function(e) { 
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').addClass('required validName');
    } );

    $('#problem_submit > input[type="submit"]').click( function(e) { 
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').addClass('required validName');
    } );

    $('#update_post').click( function(e) { 
        $('#form_name').addClass('required').removeClass('valid');
    } );

    $('#email_alert').click(function(e) {
        if (!$('#email_alert_box').length)
            return true;
        e.preventDefault();
        if ($('#email_alert_box').is(':visible')) {
            email_alert_close();
        } else {
            var pos = $(this).position();
            $('#email_alert_box').css( { 'left': ( pos.left - 20 ) + 'px', 'top': ( pos.top + 20 ) + 'px' } );
            $('#email_alert_box').show('fast');
            $('#alert_rznvy').focus();
        }
    }).hover(function() {
        window.clearTimeout(timer);
    }, function() {
        timer = window.setTimeout(email_alert_close, 2000);
    });

    $('#email_alert_box').hover(function() {
        window.clearTimeout(timer);
    }, function() {
        timer = window.setTimeout(email_alert_close, 2000);
    });

    // Geolocation
    if (geo_position_js.init()) {
        $('#postcodeForm').append('<p id="geolocate_para">Or <a href="#" id="geolocate_link">locate me automatically</a>').css({ "padding-bottom": "0.5em" });
        $('#geolocate_link').click(function(e) {
            e.preventDefault();
            // Spinny thing!
            $('#geolocate_para').append(' <img src="/i/flower.gif" alt="" align="bottom">');
            geo_position_js.getCurrentPosition(function(pos) {
                $('#geolocate_para img').remove();
                var latitude = pos.coords.latitude;
                var longitude = pos.coords.longitude;
                location.href = '/around?latitude=' + latitude + ';longitude=' + longitude;
            }, function(err) {
                $('#geolocate_para img').remove();
                if (err.code == 1) { // User said no
                } else if (err.code == 2) { // No position
                    $('#geolocate_para').html("Could not look up location");
                } else if (err.code == 3) { // Too long
                    $('#geolocate_para').html("No result returned");
                } else { // Unknown
                    $('#geolocate_para').html("Unknown error");
                }
            }, {
                timeout: 10000
            });
        });
    }

});
