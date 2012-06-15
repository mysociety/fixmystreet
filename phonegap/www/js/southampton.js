/*
 * southampton.js
 * FixMyStreet JavaScript for Southampton
 */


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

    $('#form_category').change(function(){
        var category = $(this).val();
        if ('Potholes' == category) {
            if (!$('#potholes_extra').length) {
                var qns = '<div id="potholes_extra" style="margin:0; display:none;">' +
                '<div class="form-field"><label for="form_size">Size:</label>' +
                '<select name="detail_size"><option>-- Please select --<option>Unknown' +
                '<option>Small: No larger than a dinner plate (up to 30cm/12inches)' +
                '<option>Medium: No larger than a dustbin lid (up to 60cm/24inches)' +
                '<option>Large: Larger than a dustbin lid (over 60cm/24inches)' +
                '</select></div>' +
                '<div class="form-field"><label for="form_depth">Depth:</label>' +
                '<select name="detail_depth"><option>-- Please select --<option>Unknown' +
                '<option>No deeper than a golf ball (up to 4cm/1.5inches)' +
                '<option>No deeper than a tennis ball (up to 6.5cm/2.5inches)' +
                '<option>Deeper than a tennis ball' +
                '</select></div></div>';
                $('#form_title').closest('div.form-field').after(qns);
            }
            $('#potholes_extra').show('fast');
        } else {
            $('#potholes_extra').hide('fast');
        }
    }).change();

});

