$(function(){
    // available for admin pages

    // hide the open311_only section and reveal it only when send_method is relevant
    var $open311_only = $('.admin-open311-only');
    if ($open311_only) {
        function hide_or_show_open311() {
            var send_method = $('#send_method').val();
            var show_open311 = false;
            if ($('#endpoint').val()) {
                show_open311 = true; // always show the form if there is an endpoint value
            } else if (send_method && send_method.toLowerCase() != 'email') {
                show_open311 = true;
            }
             if (show_open311) {
                 $open311_only.slideDown();
             } else {
                $open311_only.slideUp();
            }
        }
        $('#send_method').on('change', hide_or_show_open311);
        hide_or_show_open311();
    }

    // admin hints: maybe better implemented as tooltips?
    $(".admin-hint").on('click', function(){
        if ($(this).hasClass('admin-hint-show')) {
            $(this).removeClass('admin-hint-show');
        } else {
            $(this).addClass('admin-hint-show');
        }
    });

});

