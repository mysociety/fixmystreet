var can_geolocate = false;

Storage.prototype.setObject = function(key, value) {
    this.setItem(key, JSON.stringify(value));
};

Storage.prototype.getObject = function(key) {
    return JSON.parse(this.getItem(key));
};

function touchmove(e) {
    e.preventDefault();
}

function show_around( lat, long ) {
    pc = $('#pc').val();
    localStorage.latitude = lat;
    localStorage.longitude = long;
    localStorage.pc = pc;
    $.mobile.changePage('around.html');
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
var watch_id = null;
var watch_count = 0;

function foundLocation(myLocation) {
    var lat = myLocation.coords.latitude;
    var long = myLocation.coords.longitude;
    watch_count++;
    if ( myLocation.coords.accuracy < 100 ) {
        navigator.geolocation.clearWatch(watch_id);
        show_around( lat, long );
        watch_id = null;
    } else if ( watch_count > 10 ) {
        navigator.geolocation.clearWatch(watch_id);
        watch_id = null;
        $.mobile.changePage( 'frontpage-form.html' );
    }
}

function notFoundLocation() { if ( watch_id ) { location_error( 'Could not find location' ); } else { console.log('should not be here'); } }

function getPosition() {
    if ( !can_geolocate ) {
        window.setTimeout( getPosition, 200 );
        return;
    }
    if ( !watch_id ) {
        watch_count = 0;
        watch_id = navigator.geolocation.watchPosition(foundLocation, notFoundLocation, { timeout: 60000, enableHighAccuracy: true } );
    } else {
        alert('currently locating');
    }
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
        if ( $('#form_name_error').length ) {
            $('#form_name_error').text(msg);
        } else {
            $('#form_name').before('<div class="form-error" id="form_name_error">' + msg + '</div>' );
        }
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
                $.mobile.changePage('report_created.html');
            } else {
                $.mobile.changePage('email_sent.html');
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
        alert('Could not submit report');
        $('input[type=submit]').prop("disabled", false);
    }
}

function fileUploadFail() {
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
                        $.mobile.changePage('report_created.html');
                    } else {
                        $.mobile.changePage('email_sent.html');
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
                }
            },
            error: function (data, status, errorThrown ) {
                alert( 'There was a problem submitting your report, please try again (' + status + '): ' + JSON.stringify(data), function(){}, 'Submit report' );
                $('input[type=submit]').prop("disabled", false);
            }
        } );
    }
    return false;
}

function sign_in() {
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
            if ( data.name ) {
                localStorage.name = data.name;
                localStorage.username = $('#form_email').val();
                localStorage.password = $('#password_sign_in').val();
                $('#user-meta').html('<p>You are signed in as ' + localStorage.username + '.</p>');
                $('#form_sign_in_only').hide();
                $('#forget_button').show();
                $('#form_email').val('');
                $('#password_sign_in').val('');
            } else {
                $('#form_email').before('<div class="form-error">There was a problem with your email/password combination.</div>');
            }
        }
    } );

}

function display_account_page() {
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
                $.mobile.changePage('sign_in.html');
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
    display_account_page();
}

function onDeviceReady() {
    can_geolocate = true;
}

function get_report_params () {
    var params = {
        service: 'iphone',
        title: $('#form_title').val(),
        detail: $('#form_detail').val(),
        may_show_name: $('#form_may_show_name').attr('checked') ? 1 : 0,
        category: $('#form_category').val(),
        lat: $('#fixmystreet\\.latitude').val(),
        lon: $('#fixmystreet\\.longitude').val(),
        phone: $('#form_phone').val(),
        pc: $('#pc').val(),
        time: new Date()
    };

    if ( localStorage.username && localStorage.password && localStorage.name ) {
        params.name = localStorage.name;
        params.email = localStorage.username;
        params.password_sign_in = localStorage.password;
    } else {
        params.name = $('#form_name').val();
        params.email = $('#form_email').val();
        params.password_sign_in = $('#password_sign_in').val();
    }

    if ( $('#form_photo').val() !== '' ) {
        fileURI = $('#form_photo').val();
        params.file = fileURI;
    }

    return params;

}

function save_report() {
    var params = get_report_params();

    var r;
    if ( localStorage.getObject( 'reports' ) ) {
        r = localStorage.getObject( 'reports' );
    } else {
        r = [];
    }
    r.push( params );
    localStorage.setObject('reports', r);
    $.mobile.changePage('my_reports.html');
}

function display_saved_reports() {
    if ( localStorage.getObject( 'reports' ) ) {
        var r = localStorage.getObject('reports');
        var list = $('<ul id="current" class="issue-list-a tab open"></ul>');
        for ( i = 0; i < r.length; i++ ) {
            if ( r[i] && r[i].title ) {
                var item = $('<li class="saved-report" id="' + i + '"></li>');
                var date;
                if ( r[i].time ) {
                    var date = new Date( r[i].time );
                    date = date.getDate() + '-' + ( date.getMonth() + 1 ) + '-' + date.getFullYear();
                    date += ' ' + date.getHour() + ':' + date.getMinute();
                } else {
                    date = '';
                }
                var content = $('<a class="text"><h4>' + r[i].title + '</h4><small>' + date + '</small></a>');
                if ( r[i].file ) {
                    $('<img class="img" src="' + r[i].file + '" height="60" width="90">').prependTo(content);
                }
                content.appendTo(item);
                item.appendTo(list);
            }
        }
        list.appendTo('#reports');
    } else {
        $("#reports").innerHTML('No Reports');
    }
}

function open_saved_report_page(e) {
    localStorage.currentReport = this.id;
    $.mobile.changePage('report.html');
}

function display_saved_report() {
    var r = localStorage.getObject('reports')[localStorage.currentReport];
    fixmystreet.latitude = r.lat;
    fixmystreet.longitude = r.lon;
    fixmystreet.pins = [ [ r.lat, r.lon, 'yellow', '', "", 'big' ] ];

    $('#title').text(r.title);
    $('#details').text(r.detail);
    if ( r.file ) {
        $('#photo').attr('src', r.file);
        $('#photo_link').attr('href', r.file);
        $('#report-img').show();
    } else {
        $('#report-img').hide();
    }
}

function submit_problem_show() {
    if ( localStorage.name ) {
        $('.form-focus-hidden').show();
    } else {
        $('.form-focus-hidden').hide();
    }
}

$(document).bind('pageinit', function() {
    $('#postcodeForm').submit(locate);
    $('#mapForm').submit(postReport);
    $('#signInForm').submit(sign_in);
    $('#ffo').click(getPosition);
    $('#forget').on('click', forget);
    $('#save_report').on('click', save_report);
    $('#mapForm :input[type=submit]').on('click', function() { submit_clicked = $(this); });
    account();
});

document.addEventListener("deviceready", onDeviceReady, false);

$(document).delegate('#report-created', 'pageshow',function() {
    var uri = CONFIG.FMS_URL + 'report/' + localStorage.report;
    $('#report_url').html( '<a href="' + uri + '">' + uri + '</a>' );
});

function decide_front_page() {
    if ( !can_geolocate ) {
        window.setTimeout( decide_front_page, 100 );
        return;
    }
    if ( navigator.network.connection.type == Connection.NONE ||
            navigator.network.connection.type == Connection.UNKNOWN ) {
        $.mobile.changePage( 'no_connection.html' );
    } else {
        getPosition();
    }
}

$(document).delegate('#front-page', 'pageinit', decide_front_page);
$(document).delegate('#account-page', 'pageshow', display_account_page);
$(document).delegate('#my-reports-page', 'pageshow', display_saved_reports);
$(document).delegate('#report-page', 'pageshow', display_saved_report);
$(document).delegate('#submit-problem', 'pageshow', submit_problem_show);
$(document).delegate('.saved-report', 'click', open_saved_report_page);
