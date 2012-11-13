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

function location_error( msg ) {
    if ( msg === '' ) {
        $('#location_error').remove();
        return;
    }

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
                    multiple_html += '<li><a href="#" onclick="show_around( ' + multiple[i].latitude + ',' + multiple[i].longitude +')">' + multiple[i].address + '</a></li>';
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

function have_gps(myLocation) {
    navigator.geolocation.clearWatch(watch_id);
    if ( watch_id ) {
        watch_id = null;
        var lat = myLocation.coords.latitude;
        var long = myLocation.coords.longitude;
        $('#have-gps').text('Determined location using GPS');
        $('#make-report').show();

        localStorage.latitude = lat;
        localStorage.longitude = long;
    }
}

function do_not_have_gps(err) {
    console.log(err);
    if ( watch_id ) {
        navigator.geolocation.clearWatch(watch_id);
        watch_id = null;
        $('#have-gps').text('Cannot determine location');
        $('#make-report').hide();
    }
}

function check_for_gps() {
    if ( !can_geolocate ) {
        window.setTimeout( check_for_gps, 200 );
        return;
    }
    if ( !watch_id ) {
        watch_count = 0;
        watch_id = navigator.geolocation.watchPosition(have_gps, do_not_have_gps, { timeout: 60000, enableHighAccuracy: true } );
    } else {
        alert('currently locating');
    }
}

function create_offline() {
    $.mobile.changePage('submit-problem.html');
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

function remove_saved_report() {
    if ( localStorage.currentReport ) {
        var r = new Report();
        r.remove(localStorage.currentReport);
        delete localStorage.currentReport;
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
            remove_saved_report();
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
    if ( e ) {
        e.preventDefault();
    }

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
        if ( $('#form_name').val() !== '' ) {
            params.name = $('#form_name').val();
        }
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
                        if ( !localStorage.name && $('#password_sign_in').val() ) {
                            localStorage.name = $('#form_name').val();
                            localStorage.username = $('#form_email').val();
                            localStorage.password = $('#password_sign_in').val();
                        }
                        $.mobile.changePage('report_created.html');
                    } else {
                        $.mobile.changePage('email_sent.html');
                    }
                    remove_saved_report();
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

function set_location() {
    var cross = fixmystreet.map.getControlsByClass(
                "OpenLayers.Control.Crosshairs");

    var position = cross[0].getMapPosition();
    position.transform(
        fixmystreet.map.getProjectionObject(),
        new OpenLayers.Projection("EPSG:4326")
    );

    localStorage.latitude = position.lat;
    localStorage.longitude = position.lon;
    $.mobile.changePage('submit-problem.html');
}

function mark_here() {
    if ( fixmystreet.markers.getVisibility() ) {
        fixmystreet.state_pins_were_hidden = false;
        $('#hide_pins_link').click();
    }

    $('#sub_map_links').hide();
    var $map_box = $('#map_box');
    $map_box.append(
        '<p id="mob_sub_map_links">' +
        '<a href="#" id="try_again">Try again</a>' +
        '<a href="#ok" id="mob_ok">Confirm</a>' +
        '</p>' );
    $('#mark-here').hide();

    $('#try_again').on('vclick', function(){
        fixmystreet.bbox_strategy.activate();
        fixmystreet.markers.refresh( { force: true } );
        if ( !fixmystreet.state_pins_were_hidden ) {
            // If we had pins hidden when we clicked map (which had to show the pin layer as I'm doing it in one layer), hide them again.
            $('#hide_pins_link').click();
        }
        //fixmystreet.drag.deactivate();
        $('#sub_map_links').show();
        $('#mob_sub_map_links').remove();
        $('#mark-here').show();
    });
    $('#mob_ok').on('vclick', set_location );
}

function forget_user_details() {
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

function _submit_save_report() {
    var params = get_report_params();

    var r = new Report(params);
    r.save();
    return r;
}

function save_report() {
    _submit_save_report();
    $.mobile.changePage('my_reports.html');
}

function submit_back() {
    var r = _submit_save_report();
    localStorage.currentReport = r.id();
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
                    var date_o = new Date( r[i].time );
                    date = date_o.getDate() + '-' + ( date_o.getMonth() + 1 ) + '-' + date_o.getFullYear();
                    date = date + ' ' + date_o.getHours() + ':' + date_o.getMinutes();
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
    var r = new Report();
    r.load(localStorage.currentReport);

    fixmystreet.latitude = r.lat();
    fixmystreet.longitude = r.lon();
    fixmystreet.pins = [ [ r.lat(), r.lon(), 'yellow', '', "", 'big' ] ];

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

function complete_report() {
    var r = new Report();
    r.load(localStorage.currentReport);

    if ( r.lat() && r.lon() ) {
        show_around( r.lat(), r.lon() );
    } else {
        getPosition();
    }
}

function delete_report() {
    var r = new Report();
    r.load(localStorage.currentReport);
    r.remove();
    $.mobile.changePage('my_reports.html');
}

function submit_problem_show() {
    if ( localStorage.currentReport ) {
        var r = new Report();
        r.load(localStorage.currentReport);

        $('#form_title').val(r.title());
        $('#form_detail').val(r.detail());
        if ( r.may_show_name() === 0 ) {
            $('#form_may_show_name').attr('checked', 'off');
        }
        //category: $('#form_category').val();
        $('#form_phone').val(r.phone());
        $('#pc').val(r.pc());
        if ( r.file() ) {
            $('#form_photo').val(r.file());
            $('#photo').attr('src', r.file() );
            $('#add_photo').hide();
            $('#display_photo').show();
        }
    }

    $('#mapForm').on('submit', postReport);
    $('#side-form, #site-logo').show();
    $('#pc').val(localStorage.pc);
    $('#fixmystreet\\.latitude').val(localStorage.latitude);
    $('#fixmystreet\\.longitude').val(localStorage.longitude);

    if ( localStorage.offline == 1 ) {
        $('#councils_text').html("You are currently operating in offline mode so you can save the details of the problem but you'll need to finish reporting when you have internet access.");
        $('#form_category_row').hide();
        $('#email_label').hide();
        $('#form_email').hide();
        $('#form_sign_in').hide();
    } else {
        if ( localStorage.name ) {
            check_name( localStorage.name );
            $('.form-focus-hidden').show();
        } else {
            $('.form-focus-hidden').hide();
        }

        $.getJSON( CONFIG.FMS_URL + 'report/new/ajax', {
                latitude: $('#fixmystreet\\.latitude').val(),
                longitude: $('#fixmystreet\\.longitude').val()
        }, function(data) {
            if (data.error) {
                // XXX If they then click back and click somewhere in the area, this error will still show.
                $('#side-form').html('<h1>Reporting a problem</h1><p>' + data.error + '</p>');
                return;
            }
            $('#councils_text').html(data.councils_text);
            $('#form_category_row').html(data.category);
        });
    }
}


function decide_front_page() {
    if ( !can_geolocate ) {
        window.setTimeout( decide_front_page, 100 );
        return;
    }

    localStorage.offline = 0;
    delete localStorage.currentReport;

    if ( navigator.network.connection.type == Connection.NONE ||
            navigator.network.connection.type == Connection.UNKNOWN ) {
        localStorage.offline = 1;
        $.mobile.changePage( 'no_connection.html' );
    } else {
        getPosition();
    }
}

document.addEventListener("deviceready", onDeviceReady, false);

$(document).on('pageshow', '#report-created', function() {
    var uri = CONFIG.FMS_URL + 'report/' + localStorage.report;
    $('#report_url').html( '<a href="' + uri + '">' + uri + '</a>' );
});


$(document).on('pageshow', '#front-page', decide_front_page);
$(document).on('pageshow', '#account-page', display_account_page);
$(document).on('pageshow', '#my-reports-page', display_saved_reports);
$(document).on('pageshow', '#report-page', display_saved_report);
$(document).on('pageshow', '#submit-problem', submit_problem_show);
$(document).on('pageshow', '#no-connection-page', check_for_gps);

$(document).bind('pageinit', function() {
    $('#postCodeForm').on('submit', locate);
    $('#signInForm').on('submit', sign_in);
});

$(document).on('vclick', '#save_report', save_report);
$(document).on('vclick', '#forget', forget_user_details);
$(document).on('vclick', '.saved-report', open_saved_report_page);
$(document).on('vclick', '#mark-here', mark_here);
$(document).on('vclick', '#create_report', create_offline);
$(document).on('vclick', '#complete_report', complete_report);
$(document).on('vclick', '#delete_report', delete_report);
$(document).on('vclick', '#id_photo_button', function() {takePhoto(navigator.camera.PictureSourceType.CAMERA);});
$(document).on('vclick', '#id_existing', function() {takePhoto(navigator.camera.PictureSourceType.SAVEDPHOTOALBUM);});
$(document).on('vclick', '#mapForm :input[type=submit]', function() { submit_clicked = $(this); });
$(document).on('vclick', '#id_del_photo_button', delPhoto);
$(document).on('vclick', '#submit-header a.ui-btn-left', submit_back);
