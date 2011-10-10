/*
 * fixmystreet.js
 * FixMyStreet JavaScript
 */

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

    $('#form_category').change(function() {
        if ( category_extras ) {
            $('#category_meta').empty();
            if ( category_extras[this.options[ this.selectedIndex ].text] ) {
                var fields = category_extras[this.options[ this.selectedIndex ].text];
                $('<h4>Additional information</h4>').appendTo('#category_meta');
                for ( var i in fields) {
                    var meta = fields[i];
                    var field = '<div class="form-field">';
                    field += '<label for="form_' + meta.code + '">' + meta.description + ':</label>';
                    if ( meta.values ) {
                        field += '<select name="' + meta.code + '" id="form_' + meta.code + '">';
                        for ( var j in meta.values.value ) {
                            field += '<option value="' + meta.values.value[j].key + '">' + j + '</option>';
                        }
                        field += '</select>';
                    } else {
                        field += '<input type="text" value="" name="' + meta.code + '" id="form_' + meta.code + '">';
                    }
                    field += '</div>';
                    $( field ).appendTo('#category_meta');
                }
            }
        }
    });

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
