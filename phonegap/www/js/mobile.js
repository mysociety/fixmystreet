function touchmove(e) {
    e.preventDefault();
}

function show_around( lat, long ) {
    pc = $('#pc').val();
    localStorage.latitude = lat;
    localStorage.longitude = long;
    localStorage.pc = pc;
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
    url += '&c=en-GB&key=' + CONFIG.BING_KEY;
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
                $('#postcodeForm').after( multiple_html );
            }
        } else {
            location_error("Could not find your location");
        }
        if (navigator.notificationEx) { navigator.notificationEx.loadingStop(); }
    });
}

function locate() {
    location_error('');
    $("#multiple").remove();
    var pc = $('#pc').val();
                    
    if (!pc) {
        location_error( "Please enter your location" );
        return false;
    }

    var loadingStart = function() {};
    var loadingStop = function() {};
    if (typeof navigator.notificationEx !== "undefined") {
        loadingStart = navigator.notificationEx.loadingStart;
        loadingStop = navigator.notificationEx.loadingStop;
    }
    loadingStart( { 'backgroundOpacity' : 0.5, labelText: 'Getting Location...', minDuration: 1 } );
    if ( valid_postcode( pc ) ) {
        jQuery.get( CONFIG.MAPIT_URL + 'postcode/' + pc + '.json', function(data, status) {
            if ( status == 'success' ) {
               show_around( data.wgs84_lat, data.wgs84_lon );
               loadingStop();
           } else {
               loadingStop();
           }
        });
    } else {
        lookup_string(pc);
    }
    return false;
}

function foundLocation(myLocation) {
    if (navigator.notificationEx) { navigator.notificationEx.loadingStop(); }
    var lat = myLocation.coords.latitude;
    var long = myLocation.coords.longitude;

    show_around( lat, long );
}

function notFoundLocation() { location_error( 'Could not find location' ); }

function getPosition() {
    var loadingStart = function() {};
    var loadingStop = function() {};

    if (typeof navigator.notificationEx !== "undefined") {
        loadingStart = navigator.notificationEx.loadingStart;
        loadingStop = navigator.notificationEx.loadingStop;
    }
    loadingStart( { 'backgroundOpacity' : 0.5, labelText: 'Getting Location...', minDuration: 1 } );

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
}

function takePhoto(type) {
    navigator.camera.getPicture(takePhotoSuccess, takePhotoFail, { quality: 50, destinationType: Camera.DestinationType.FILE_URI, sourceType: type }); 
}

function fileUploadSuccess(r) {
    console.log( r.response );
    console.log( typeof r.response );
    if ( r.response.indexOf( 'success' ) >= 0  ) {
        window.location = 'email_sent.html';
    } else {
        alert('Could not submit report');
        $('input[type=submit]').prop("disabled", false);
    }
}

function fileUploadFail() {
    alert('Could not submit report');
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
        name: $('#form_name').val(),
                    may_show_name: $('#form_may_show_name').attr('checked') ? 1 : 0,
        email: $('#form_email').val(),
        category: $('#form_category').val(),
        lat: $('#fixmystreet\\.latitude').val(),
        lon: $('#fixmystreet\\.longitude').val(),
        password_sign_in: $('#password_sign_in').val(),
        phone: $('#form_phone').val(),
        pc: $('#pc').val()
    };

    if ( submit_clicked.attr('id') == 'submit_sign_in' ) {
        params.submit_sign_in = 1;
    } else {
        params.submit_register = 1;
    }

    if ( $('#form_photo').val() !== '' ) {
        fileURI = $('#form_photo').val();

        var options = new FileUploadOptions();
        options.fileKey="photo";
        options.fileName=fileURI.substr(fileURI.lastIndexOf('/')+1);
        options.mimeType="image/jpeg";  
        options.params = params;

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
                        window.location = 'report_created.html';
                    } else {
                        window.location = 'email_sent.html';
                    }
                } else {
                    if ( data.check_name ) {
                        $('#email_label').hide();
                        $('#form_email').hide();
                        $('#now_submit').hide();
                        $('#have_password').hide();
                        $('#form_sign_in_yes').hide();
                        $('#let_me_confirm').hide();
                        $('#password_register').hide();
                        $('#password_surround').hide();
                        $('#providing_password').hide();
                        $('#form_name').val( data.check_name );
                        $('#form_name').focus();
                        $('#form_name').before('<div class="form-error">' + data.errors.name + '</div>' );
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

$(function(){
    $('#postcodeForm').submit(locate);
    $('#mapForm').submit(postReport);
    $('#ffo').click(getPosition);
    $('#mapForm :input[type=submit]').on('click', function() { submit_clicked = $(this); });
});

