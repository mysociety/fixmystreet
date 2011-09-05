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

    // add in handling for html5 form types...
    // should be removed if/when jQuery supports these by default
    // NB: required alteration of validation plugin code also
    jQuery.event.add(this, "keypress.specialSubmit", function( e ) {
        var elem = e.target,
            type = elem.type;

        if ( ( type === "email" || type === "url" ) && jQuery( elem ).closest("form").length && e.keyCode === 13 ) {
            e.liveFired = undefined;
            return jQuery.fn.trigger( "submit", this, arguments );
        }
    });

    jQuery.expr.filters[ 'email' ] = function( elem ) {
                        return "email" === elem.type;
                };

    // FIXME - needs to use translated string
    jQuery.validator.addMethod('validCategory', function(value, element) {
        return this.optional(element) || value != '-- Pick a category --'; }, validation_strings['category'] );

    // TODO - test in older browsers
    jQuery.validator.addMethod('validName', function(value, element) {
        var validNamePat = /\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
        return this.optional(element) || value.length > 5 && value.match( /\S/ ) && !value.match( validNamePat ) }, validation_strings['category'] );

    $("#mapForm").validate({
        messages: validation_strings,
        onkeyup: false,
        errorElement: 'div',
        errorClass: 'form-error',
        errorPlacement: function( error, element ) {
            element.parent('div').before( error );
        },
        submitHandler: function(form) {
            if (form.submit_problem) {
                $('input[type=submit]', form).prop("disabled", true);
            }

            form.submit();
        }
    });

    /* set correct required status depending on what we submit */
    $('#submit_sign_in').click( function(e) { 
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').removeClass('required');
    } );

    $('#submit_register').click( function(e) { 
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').addClass('required');
    } );

    $('#problem_submit > input[type="submit"]').click( function(e) { 
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').addClass('required');
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

});
