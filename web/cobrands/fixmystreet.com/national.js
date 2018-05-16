var fixmystreet = fixmystreet || {};


(function(){

fixmystreet.is_national = true;

fixmystreet.check_do_not_send = {
    check: function() {
        var do_not_send = [];
        if (fixmystreet.do_not_send && fixmystreet.bodies) {
            for ( var i = 0; i < fixmystreet.bodies.length; i++ ) {
                if ( fixmystreet.do_not_send[fixmystreet.bodies[i]] != 1 ) {
                    do_not_send.push(fixmystreet.bodies[i]);
                }
            }
        }
        $('#do_not_send').val(do_not_send.join(','));
    }
};

fixmystreet.disable_report_form = function() {
    $("#problem_form").children().each( function (i, c) {
        if (c.id != 'form_category_row' && c.id != 'js-layer-message') {
            $(c).hide();
        }
    } );
};

fixmystreet.enable_report_form = function() {
    $("#problem_form").children().each( function (i, c) {
        if (c.id != 'js-layer-message') {
            $(c).show();
        }
    } );
};

$(fixmystreet).on('assets:check_do_not_send', fixmystreet.check_do_not_send.check);

})();
