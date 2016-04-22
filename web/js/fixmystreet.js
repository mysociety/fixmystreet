/*
 * fixmystreet.js
 * FixMyStreet JavaScript used by all cobrands.
 * With the JavaScript written more proper like.
 */

(function($){

/*
 Deal with changes to category by asking for details from the server.
 */
$(function(){

    var $html = $('html');

    // Add a class to the whole page saying JavaScript is enabled (for CSS and so on)
    $html.removeClass('no-js').addClass('js');

    // Preload the new report pin
    if ( typeof fixmystreet !== 'undefined' && typeof fixmystreet.pin_prefix !== 'undefined' ) {
        document.createElement('img').src = fixmystreet.pin_prefix + 'pin-green.png';
    } else {
        document.createElement('img').src = '/i/pin-green.png';
    }

    // Focus on postcode box on front page
    $('#pc').focus();

    // In case we've come here by clicking back to a form that disabled a submit button
    $('input[type=submit]').removeAttr('disabled');

    // Questionnaire hide/showings
    if (!$('#been_fixed_no').prop('checked') && !$('#been_fixed_unknown').prop('checked')) {
        $('.js-another-questionnaire').hide();
    }
    $('#been_fixed_no').on('click', function() {
        $('.js-another-questionnaire').show('fast');
    });
    $('#been_fixed_unknown').on('click', function() {
        $('.js-another-questionnaire').show('fast');
    });
    $('#been_fixed_yes').on('click', function() {
        $('.js-another-questionnaire').hide('fast');
    });

    // Form validation

    // FIXME - needs to use translated string
    jQuery.validator.addMethod('validCategory', function(value, element) {
        return this.optional(element) || value != '-- Pick a category --'; }, translation_strings.category );

    var form_submitted = 0;
    var submitted = false;

    $("form.validate").each(function(){
      $(this).validate({
        rules: validation_rules,
        messages: translation_strings,
        onkeyup: false,
        onfocusout: false,
        errorElement: 'div',
        errorClass: 'form-error',
        // we do this to stop things jumping around on blur
        success: function (err) { if ( form_submitted ) { err.addClass('label-valid').removeClass('label-valid-hidden').html( '&nbsp;' ); } else { err.addClass('label-valid-hidden'); } },
        errorPlacement: function( error, element ) {
            // Different for old/new style design
            if ($('.form-field').length) {
                element.parent('div.form-field').before( error );
            } else {
                element.before( error );
            }
        },
        submitHandler: function(form) {
            if (form.submit_problem) {
                $('input[type=submit]', form).prop("disabled", true);
            }

            form.submit();
        },
        // make sure we can see the error message when we focus on invalid elements
        showErrors: function( errorMap, errorList ) {
            if ( submitted && errorList.length ) {
               $(window).scrollTop( $(errorList[0].element).offset().top - 120 );
            }
            this.defaultShowErrors();
            submitted = false;
        },
        invalidHandler: function(form, validator) { submitted = true; }
      });
    });

    $('input[type=submit]').click( function(e) { form_submitted = 1; } );

    /* set correct required status depending on what we submit
    * NB: need to add things to form_category as the JS updating
    * of this we do after a map click removes them */
    $('#submit_sign_in').click( function(e) {
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').removeClass();
        $('#form_first_name').removeClass();
        $('#form_last_name').removeClass();
        $('#form_fms_extra_title').removeClass();
    } );

    $('#submit_register').click( function(e) {
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').addClass('required');
        if ( $('#mapForm').length ) {
            $('#form_name').addClass('validName');
        }
        $('#form_first_name').addClass('required');
        $('#form_last_name').addClass('required');
        $('#form_fms_extra_title').addClass('required');
    } );

    $('#problem_submit > input[type="submit"]').click( function(e) {
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').addClass('required');
        if ( $('#mapForm').length ) {
            $('#form_name').addClass('validName');
        }
        $('#form_first_name').addClass('required');
        $('#form_last_name').addClass('required');
        $('#form_fms_extra_title').addClass('required');
    } );

    $('#update_post').click( function(e) {
        $('#form_name').addClass('required').removeClass('valid');
    } );

    $('#facebook_sign_in, #twitter_sign_in').click(function(e){
        $('#form_email').removeClass();
        $('#form_rznvy').removeClass();
        $('#email').removeClass();
    });

    // Geolocation
    if (geo_position_js.init()) {
        var link = '<a href="LINK" id="geolocate_link">&hellip; ' + translation_strings.geolocate + '</a>';
        $('form[action="/alert/list"]').append(link.replace('LINK','/alert/list'));
        if ($('body.frontpage').length) {
            $('#postcodeForm').after(link.replace('LINK','/around'));
        } else{
            $('#postcodeForm').append(link.replace('LINK','/around'));
        }
        $('#geolocate_link').click(function(e) {
            var $link = $(this);
            e.preventDefault();
            // Spinny thing!
            if($('.mobile').length){
                $link.append(' <img src="/cobrands/fixmystreet/images/spinner-black.gif" alt="" align="bottom">');
            }else{
                var spincolor = $('<span>').css("color","white").css("color") === $('#front-main').css("background-color")? 'white' : 'yellow';
                $link.append(' <img src="/cobrands/fixmystreet/images/spinner-' + spincolor + '.gif" alt="" align="bottom">');
            }
            geo_position_js.getCurrentPosition(function(pos) {
                $link.find('img').remove();
                var latitude = pos.coords.latitude;
                var longitude = pos.coords.longitude;
                var page = $link.attr('href');
                location.href = page + '?latitude=' + latitude + ';longitude=' + longitude;
            }, function(err) {
                $link.find('img').remove();
                if (err.code == 1) { // User said no
                    $link.html(translation_strings.geolocation_declined);
                } else if (err.code == 2) { // No position
                    $link.html(translation_strings.geolocation_no_position);
                } else if (err.code == 3) { // Too long
                    $link.html(translation_strings.geolocation_no_result);
                } else { // Unknown
                    $link.html(translation_strings.geolocation_unknown);
                }
            }, {
                enableHighAccuracy: true,
                timeout: 10000
            });
        });
    }

    // Delegation is necessary because #form_category may be replaced during the lifetime of the page
    $("#problem_form").on("change.category", "select#form_category", function(){
        var args = {
            category: $(this).val()
        };

        args.latitude = $('input[name="latitude"]').val();
        args.longitude = $('input[name="longitude"]').val();

        $.getJSON('/report/new/category_extras', args, function(data) {
            var $category_meta = $('#category_meta');
            if ( data.category_extra ) {
                if ( $category_meta.length ) {
                    $category_meta.html( data.category_extra );
                } else {
                    $('#form_category_row').after( data.category_extra );
                }
            } else {
                $category_meta.empty();
            }
        });
    });

    // Map form doesn't work in some browsers with HTML5 validation and hidden form, so
    // we disable validation by default, and add it in the JS case.
    // For some reason, the removeAttr doesn't work if we place it at beginning.
    $('#mapForm').removeAttr('novalidate');
});

})(jQuery);

