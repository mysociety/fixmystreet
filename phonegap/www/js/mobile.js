function touchmove(e) {
    e.preventDefault();
}

function loadingSpinner(method){
    if (method == "on") {
        //Adjust to screen size
        var pHeight = window.innerHeight;
        var pWidth = window.innerWidth;
        var sH = parseInt($('#loadingSpinner').css('height'),10);
        var sW = parseInt($('#loadingSpinner').css('width'),10);
        $('#loadingSpinner').css('top',(pHeight-sH)/2+$('body').scrollTop());
        $('#loadingSpinner').css('left',(pWidth-sW)/2);
        $('#loadingSpinner').css('z-index',1000);
        //Show
        $('#loadingSpinner').show();
    } else if (method == 'off'){
        $('#loadingSpinner').hide();
    }
}

function showBusy( title, msg ) {
    if ( navigator && navigator.notification && typeof navigator.notification.activityStart !== "undefined") {
        navigator.notification.activityStart( title, msg );
    } else {
        loadingSpinner('on');
    }
}

function hideBusy() {
    if ( navigator && navigator.notification && navigator.notification.activityStop) {
        navigator.notification.activityStop();
    } else {
        loadingSpinner('off');
    }
}

function show_around( lat, long ) {
    pc = $('#pc').val();
    localStorage.latitude = lat;
    localStorage.longitude = long;
    localStorage.pc = pc;
    hideBusy();
    window.location='around.html';
    return false;
}

function valid_postcode(pc) {
    var out_pattern = '[A-PR-UWYZ]([0-9]{1,2}|([A-HIK-Y][0-9](|[0-9]|[ABEHMNPRVWXY]))|[0-9][A-HJKSTUW])';
    var in_pattern = '[0-9][ABD-HJLNP-UW-Z]{2}';
    var full_pattern = '^' + out_pattern + in_pattern + '$';
    var postcode_regex = new RegExp(full_pattern);

    pc = pc.toUpperCase().replace(/\s+/, '');
    if ( postcode_regex.test(pc) ) {
        return true;
    }

    return false;
}

function checkConnection() {
    var networkState = navigator.network.connection.type;
    if ( networkState == Connection.NONE || networkState == Connection.UNKNOWN ) {
        $('#main').hide();
        $('#noconnection').show();
    }
}

function use_lat_long( lat, long ) {
    show_around( lat, long );
}

function location_error( msg ) {
    hideBusy();
    if ( msg === '' ) {
        $('#location_error').remove();
        return;
    }

    alert(msg);

    if ( !$('#location_error') ) {
        $('#postcodeForm').after('<p id="location_error"></p>');
    }

    $('#location_error').text( msg );
}

function lookup_string(q) {
    q = q.toLowerCase();
    q = q.replace(/[^\-&\w ']/, ' ');
    q = q.replace(/\s+/, ' ');

    if (!q) {
        hideBusy();
        location_error("Please enter location");
        return false;
    }

    var url = "http://dev.virtualearth.net/REST/v1/Locations?q=" + escape(q);
    url += '&c=en-GB&key=' + CONFIG.BING_API_KEY;
    var x = jQuery.get( url, function(data, status) {
        if ( status == 'success' ) {
            var valid_locations = 0;
            var latitude = 0;
            var longitude = 0;
            var multiple = [];

            for ( i = 0; i < data.resourceSets[0].resources.length; i++ ) {
                var details = data.resourceSets[0].resources[i];
                if ( details.address.countryRegion != 'United Kingdom' ) { continue; }
                var address = details.name;

                latitude = details.point.coordinates[0];
                longitude = details.point.coordinates[1];
                latitude = latitude.toPrecision(6);
                longitude = longitude.toPrecision(6);

                multiple.push( { 'address': address, 'latitude': latitude, 'longitude': longitude } );
                valid_locations += 1;
            }

            if ( valid_locations == 1 ) {
                show_around( latitude, longitude );
            } else if ( valid_locations === 0 ) {
                location_error('Location not found');
                $('#pc').select();
            } else {
                location_error('');
                $('#multiple').remove();
                var multiple_html = '<ul id="multiple"><li>Multiple locations found, please select one:';
                for ( i = 0; i < multiple.length; i++ ) {
                    multiple_html += '<li><a href="#" onclick="use_lat_long( ' + multiple[i].latitude + ',' + multiple[i].longitude +')">' + multiple[i].address + '</a></li>';
                }
                multiple_html += '</ul>';
                $('#front-howto').hide();
                $('#postcodeForm').after( multiple_html );
            }
        } else {
            location_error("Could not find your location");
        }
        hideBusy();
    });
    return false;
}

function locate() {
    $("#multiple").remove();
    var pc = $('#pc').val();

    if (!pc) {
        location_error( "Please enter your location" );
        return false;
    }

    showBusy('Locating', 'Looking up location');

    if ( valid_postcode( pc ) ) {
        jQuery.get( CONFIG.MAPIT_URL + 'postcode/' + pc + '.json', function(data, status) {
            if ( status == 'success' ) {
                //activityStop();
               show_around( data.wgs84_lat, data.wgs84_lon );
           } else {
               activityStop();
               alert('Could not locate postcode');
           }
        });
    } else {
        lookup_string(pc);
    }
    return false;
}

function foundLocation(myLocation) {
    var lat = myLocation.coords.latitude;
    var long = myLocation.coords.longitude;

    show_around( lat, long );
}

function notFoundLocation() { location_error( 'Could not find location' ); }

function getPosition() {
    showBusy( 'Locating', 'Looking up location' );

    navigator.geolocation.getCurrentPosition(foundLocation, notFoundLocation);
}


function takePhotoSuccess(imageURI) {
    $('#form_photo').val(imageURI);
    $('#photo').attr('src', imageURI );
    $('#add_photo').hide();
    $('#display_photo').show();
}

function delPhoto() {
    $('#form_photo').val('');
    $('#photo').attr('src', '' );
    $('#display_photo').hide();
    $('#add_photo').show();
}

function takePhotoFail(message) {
    alert('There was a problem taking your photo');
    console.log('error taking picture: ' + message);
}

function takePhoto(type) {
    navigator.camera.getPicture(takePhotoSuccess, takePhotoFail, { quality: 50, destinationType: Camera.DestinationType.FILE_URI, sourceType: type }); 
}

function check_name( name, msg ) {
    $('#email_label').hide();
    $('#form_email').hide();
    $('#now_submit').hide();
    $('#have_password').hide();
    $('#form_sign_in_yes').hide();
    $('#let_me_confirm').hide();
    $('#password_register').hide();
    $('#password_surround').hide();
    $('#providing_password').hide();
    $('#form_name').val( name );
    if ( msg ) {
        $('#form_name').focus();
        $('#form_name').before('<div class="form-error">' + msg + '</div>' );
    }
}

function fileUploadSuccess(r) {
    if ( r.response ) {
        var data;
        try {
            data = JSON.parse( decodeURIComponent(r.response) );
        }
        catch(err) {
            data = {};
        }
        if ( data.success ) {
            if ( data.report ) {
                localStorage.report = data.report;
                hideBusy();
                window.location = 'report_created.html';
            } else {
                hideBusy();
                window.location = 'email_sent.html';
            }
        } else {
            if ( data.check_name ) {
                check_name( data.check_name, data.errors.name );
            } else {
                alert('Could not submit report');
            }
            $('input[type=submit]').prop("disabled", false);
        }
    } else {
        hideBusy();
        alert('Could not submit report');
        $('input[type=submit]').prop("disabled", false);
    }
}

function fileUploadFail() {
    hideBusy();
    alert('Could not submit report');
    $('input[type=submit]').prop("disabled", false);
}


var submit_clicked = null;

function postReport(e) {
    e.preventDefault();

    // the .stopImmediatePropogation call in invalidHandler should render this
    // redundant but it doesn't seem to work so belt and braces :(
    if ( !$('#mapForm').valid() ) { return; }

    var params = {
        service: 'iphone',
        title: $('#form_title').val(),
        detail: $('#form_detail').val(),
        may_show_name: $('#form_may_show_name').attr('checked') ? 1 : 0,
        category: $('#form_category').val(),
        lat: $('#fixmystreet\\.latitude').val(),
        lon: $('#fixmystreet\\.longitude').val(),
        phone: $('#form_phone').val(),
        pc: $('#pc').val()
    };

    if ( localStorage.username && localStorage.password && localStorage.name ) {
        params.name = localStorage.name;
        params.email = localStorage.username;
        params.password_sign_in = localStorage.password;
        params.submit_sign_in = 1;
    } else {
        params.name = $('#form_name').val();
        params.email = $('#form_email').val();
        params.password_sign_in = $('#password_sign_in').val();

        if ( submit_clicked.attr('id') == 'submit_sign_in' ) {
            params.submit_sign_in = 1;
        } else {
            params.submit_register = 1;
        }
    }

    showBusy( 'Sending Report', 'Please wait while your report is sent' );
    if ( $('#form_photo').val() !== '' ) {
        fileURI = $('#form_photo').val();

        var options = new FileUploadOptions();
        options.fileKey="photo";
        options.fileName=fileURI.substr(fileURI.lastIndexOf('/')+1);
        options.mimeType="image/jpeg";
        options.params = params;
        options.chunkedMode = false;

        var ft = new FileTransfer();
        ft.upload(fileURI, CONFIG.FMS_URL + "report/new/mobile", fileUploadSuccess, fileUploadFail, options);
    } else {
        jQuery.ajax( {
            url: CONFIG.FMS_URL + "report/new/mobile",
            type: 'POST',
            data: params, 
            timeout: 30000,
            success: function(data) {
                if ( data.success ) {
                    localStorage.pc = null;
                    localStorage.lat = null;
                    localStorage.long = null;
                    if ( data.report ) {
                        localStorage.report = data.report;
                        hideBusy();
                        window.location = 'report_created.html';
                    } else {
                        hideBusy();
                        window.location = 'email_sent.html';
                    }
                    if ( !localStorage.name && $('#password_sign_in').val() ) {
                        localStorage.name = $('#form_name').val();
                        localStorage.username = $('#form_email').val();
                        localStorage.password = $('#password_sign_in').val();
                    }
                } else {
                    if ( data.check_name ) {
                        check_name( data.check_name, data.errors.name );
                    }
                    $('input[type=submit]').prop("disabled", false);
                    hideBusy();
                }
            },
            error: function (data, status, errorThrown ) {
                hideBusy();
                alert( 'There was a problem submitting your report, please try again (' + status + '): ' + JSON.stringify(data), function(){}, 'Submit report' );
                $('input[type=submit]').prop("disabled", false);
            }
        } );
    }
    return false;
}

function sign_in() {
    showBusy( 'Signing In', 'Please wait while you are signed in' );
    $('#form_email').blur();
    $('#password_sign_in').blur();
    jQuery.ajax( {
        url: CONFIG.FMS_URL + "auth/ajax/sign_in",
        type: 'POST',
        data: {
            email: $('#form_email').val(),
            password_sign_in: $('#password_sign_in').val(),
            remember_me: 1
        },
        success: function(data) {
            console.log(data);
            if ( data.name ) {
                localStorage.name = data.name;
                localStorage.username = $('#form_email').val();
                localStorage.password = $('#password_sign_in').val();
                hideBusy();
                $('#user-meta').html('<p>You are signed in as ' + localStorage.username + '.</p>');
                $('#form_sign_in_only').hide();
                $('#forget_button').show();
                $('#form_email').val('');
                $('#password_sign_in').val('');
            } else {
                hideBusy();
                $('#form_email').before('<div class="form-error">There was a problem with your email/password combination.</div>');
            }
        }
    } );

}

function display_signed_out_msg() {
    if ( localStorage.signed_out == 1 ) {
        $('#user-meta').html('<p>You&rsquo;ve been signed out.</p>');
        $('#form_sign_in_only').show();
        localStorage.signed_out = null;
    }
    if ( localStorage.name ) {
        $('#user-meta').html('<p>You are signed in as ' + localStorage.username + '.</p>');
        $('#form_sign_in_only').hide();
        $('#forget_button').show();
    } else {
        $('#forget_button').hide();
        $('#form_sign_in_only').show();
    }
}

function sign_out() {
    jQuery.ajax( {
        url: CONFIG.FMS_URL + "auth/ajax/sign_out?" + new Date().getTime(),
        type: 'GET',
        success: function(data) {
            if ( data.signed_out ) {
                localStorage.signed_out = 1;
                localStorage.name = null;
                hideBusy();
                document.location = 'sign_in.html';
            }
        }
    } );
}

function sign_out_around() {
    jQuery.ajax( {
        url: CONFIG.FMS_URL + "auth/ajax/sign_out?" + new Date().getTime(),
        type: 'GET',
        success: function(data) {
            $('#user-meta').html('');
            $('#email_label').show();
            $('#form_email').show();
            $('#now_submit').show();
            $('#have_password').show();
            $('#form_sign_in_yes').show();
            $('#let_me_confirm').show();
            $('#password_register').show();
            $('#password_surround').show();
            $('#providing_password').show();
            $('#form_name').val( '' );
            $('.form-focus-hidden').hide();
        }
    } );
}

function account() {
    $('.mobile-sign-in-banner').show();
    $('#account').show();
    if ( localStorage.name ) {
        if ( $('body').hasClass('signed-in-page') ) {
            $('#user-meta').html('<p>Hi ' + localStorage.name + '</p>');
        }

        if ( $('#form_sign_in').length ) {
            check_name( localStorage.name );
            $('.form-focus-hidden').show();
        }
    }
}

function forget() {
    delete localStorage.name;
    delete localStorage.username;
    delete localStorage.password;
    localStorage.signed_out = 1;
    display_signed_out_msg();
}

function onDeviceReady() {
    var location = document.location + '';
    if ( location.indexOf('no_connection.html') < 0 && (
            navigator.network.connection.type == Connection.NONE ||
            navigator.network.connection.type == Connection.UNKNOWN ) ) {
        document.location = 'no_connection.html';
    }
    $('#postcodeForm').submit(locate);
    $('#mapForm').submit(postReport);
    $('#signInForm').submit(sign_in);
    $('#ffo').click(getPosition);
    $('#forget').click(forget);
    $('#mapForm :input[type=submit]').on('click', function() { submit_clicked = $(this); });
    account();
    hideBusy();
}

document.addEventListener("deviceready", onDeviceReady, false);
