/*
 * southampton.js
 * FixMyStreet JavaScript for Southampton
 */

function update_category_extra(msg) {
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

function check_depth() {
    var depth = $(this).val();
    if ('Deeper than a tennis ball' == depth) {
        var content = '<div style="margin: 1em 0em 1em 6.5em"><strong>' +
            'Please contact Actionline on 0800 5 19 19 19 so your report can be dealt with urgently' +
            '</strong></div>';
        var depth_extra = $('#depth_extra');
        if ( depth_extra.length ) {
            depth_extra.html( content );
            depth_extra.show('fast');
        } else {
            $('#form_depth').after( '<div id="depth_extra">' + content + '</div>' );
        }
    } else {
        $('#depth_extra').hide('fast');
    }
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
    $("#problem_form").on("change.southampton", "select#form_category", 
      function() {
        $('#form_sign_in').show('fast');
        $('#problem_submit').show('fast');
        $('#street_light_report').hide('fast');
        $('#depth_extra').hide('fast');
        $('#category_extra').hide('fast');
        var category = $(this).val();
        if ('Potholes' == category) {
            var content =
                '<div class="form-field"><label for="form_size">Size:</label>' +
                '<select name="detail_size"><option>-- Please select --<option>Unknown' +
                '<option>Small: No larger than a dinner plate (up to 30cm/12inches)' +
                '<option>Medium: No larger than a dustbin lid (up to 60cm/24inches)' +
                '<option>Large: Larger than a dustbin lid (over 60cm/24inches)' +
                '</select></div>' +
                '<div class="form-field"><label for="form_depth">Depth:</label>' +
                '<select id="form_depth" name="detail_depth"><option>-- Please select --<option>Unknown' +
                '<option>No deeper than a golf ball (up to 4cm/1.5inches)' +
                '<option>No deeper than a tennis ball (up to 6.5cm/2.5inches)' +
                '<option>Deeper than a tennis ball' +
                '</select></div>';
            if (!$('#category_extra').length) {
                var qns = '<div id="category_extra" style="margin:0; display:none;">' +
                content +
                '</div>';
                $('#form_title').closest('div.form-field').after(qns);
            } else {
                $('#category_extra').html( content );
            }
            $('#category_extra').show('fast');
            $('#form_depth').on('change', check_depth );
        } else if ('Fly Tipping' == category) {
            update_category_extra( 'Please list/detail items fly-tipped in the description box &amp; if it has been left on council or private property (if you know).' );
        } else if ('Litter' == category) {
            update_category_extra( 'Please detail the type of litter.  If you are reporting broken glass, syringes, oil spills or human excrement, please contact Actionline on 0800 5 19 19 19 so your report can be dealt with.' );
        } else if ('Leaves' == category) {
            update_category_extra( 'Please give as much information as you can, e.g. approximate quantity in bin bags. Thank you' );
        } else if ('Dead animals' == category) {
            update_category_extra( 'Please give as much information as you can, e.g. which animal, on road or pavement. Thank you' );
        } else if ('Shopping trolleys' == category) {
            update_category_extra( 'Please give as much information as you can, e.g. which supermarket. Thank you' );
        } else if ('Bollards' == category) {
            update_category_extra( 'Please give as much information as you can, e.g. are they lit, metal or concrete. Thank you' );
        } else if ('Overhanging vegetation' == category) {
            update_category_extra( 'Please give as much information as you can, e.g. is it coming from a private property or open area. Thank you' );
        } else if ('Graffiti' == category) {
            var graffiti_content =
                '<div class="form-field"><label for="form_offensive">Is it racist/ offensive:</label>' +
                '<select name="detail_offensive"><option>-- Please select --' +
                '<option>Yes<option>No</select></div>';
            if (!$('#category_extra').length) {
                var graffiti_qns = '<div id="category_extra" style="margin:0; display:none;">' +
                graffiti_content +
                '</div>';
                $('#form_title').closest('div.form-field').after(graffiti_qns);
            } else {
                $('#category_extra').html( graffiti_content );
            }
            $('#category_extra').show('fast');
        } else if ('Street lighting' == category) {
            $('#form_sign_in').hide('fast');
            $('#problem_submit').hide('fast');
            $('#category_extra').hide('fast');
            var lighting_content =
                '<div id="street_light_report" style="margin: 1em 0em 1em 6.5em">Please report Street light problems using the Southampton Street Lighting site at: <a href="http://www.lightsoninsouthampton.co.uk/Public/ReportFault.aspx">http://www.lightsoninsouthampton.co.uk/Public/ReportFault.aspx</a></div>';
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

