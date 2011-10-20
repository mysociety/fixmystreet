/*
 * fixmystreet.js
 * FixMyStreet JavaScript
 */

function form_category_onchange() {
    $.getJSON('/report/new/category_extras', {
        latitude: fixmystreet.latitude,
        longitude: fixmystreet.longitude,
        category: this.options[ this.selectedIndex ].text,
    }, function(data) {
        if ( data.category_extra ) {
            if ( $('#category_meta').size() ) {
                $('#category_meta').html( data.category_extra);
            } else {
                $('#form_category_row').after( data.category_extra );
            }
        } else {
            $('#category_meta').empty();
        }
    });
}

$(function(){

    $('html').removeClass('no-js').addClass('js');

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


    $('#form_category').change( form_category_onchange );

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
