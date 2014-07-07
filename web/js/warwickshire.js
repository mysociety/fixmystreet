/*
 * southampton.js
 * FixMyStreet JavaScript for Warwickshire, cadged from Southampton code, TODO refactor
 */

function update_category_extra(msg) {
    // TODO never gets called?
    var content = '<div style="margin: 1em 0em 1em 6.5em"><strong>' + msg + '</strong></div>';
    var el = $('#category_extra');
    if ( el.length ) {
        el.html( content );
    } else {
        var cat_extra = '<div id="category_extra" style="margin:0; display_none;">' +
            content +
            '</div>';
        $('#form_title').closest('div.form-field').after(cat_extra);
    }
    $('#category_extra').show('fast');
}

$(function(){

    $('[placeholder]').focus(function(){
        var input = $(this);
        if (input.val() == input.attr('placeholder')) {
            input.val('');
            input.removeClass('placeholder');
            input.css({ 'color': '#000000' });
        }
    }).blur(function(){
        var input = $(this);
        if (input.val() === '' || input.val() == input.attr('placeholder')) {
            input.css({ 'color': '#999999' });
            input.val(input.attr('placeholder'));
        }
    }).blur();

    // use on() here because the #form_category may be replaced 
    // during the page's lifetime
    $("#problem_form").on("change.warwickshire", "select#form_category", 
      function() {
        $('#form_sign_in').show('fast');
        $('#problem_submit').show('fast');
        $('#street_light_report').hide('fast');
        $('#depth_extra').hide('fast');
        $('#category_extra').hide('fast');
        var category = $(this).val();
        if ('Street lighting' == category) {
            $('#category_extra').hide('fast');
            var lighting_content =
                '<div id="street_light_report" style="margin: 1em 0em 1em 6.5em"> TODO: extra guidance text here!</div>' +
                '<input type="hidden" name="street_light_id" value="DUMMY" />'; // will be set by JS
            if ( $('#form_category_row').count ) {
                $('#form_category_row').after(lighting_content);
            } else {
                $('#form_category:parent').after(lighting_content);
            }
        } else {
            $('#category_extra').hide('fast');
        }
    }
    ).change(); // change called to trigger (in case we've come in with potholes selected)

});

