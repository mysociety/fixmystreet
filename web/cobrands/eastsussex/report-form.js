function setup_anonymous_checkbox (div) {
    var label = div.find( '.name-warning' );
    checkbox = div.find('input[type=checkbox]');

    checkbox.change( function () {
        var v = $(this).attr('checked');
        if (v) {
            label.show();
        }
        else {
            label.hide();
        }
    });
}

$(function () {
    setup_anonymous_checkbox( $('#form_sign_in_no') );
    setup_anonymous_checkbox( $('#form-box--logged-in-name') );
    setup_anonymous_checkbox( $('#update_form') );

    $('.public-warning').attr({ 'title': 'This information will be be visible to the public on the report' });
});
