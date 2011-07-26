/*
 * fixmystreet.js
 * FixMyStreet JavaScript
 */

$(function(){

    $('#pc').focus();

    $('input[type=submit]').removeAttr('disabled');
    $('#mapForm').submit(function() {
        if (this.submit_problem) {
            $('input[type=submit]', this).prop("disabled", true);
        }
        return true;
    });

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
