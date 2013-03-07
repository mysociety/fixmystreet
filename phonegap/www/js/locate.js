var Locate = ( function() { return {
    locating: 0,

    lookup: function(q) {
        var that = this;
        if (!q) {
            this.trigger('failed', { msg: FMS.strings.missing_location } );
            return false;
        }

        var url = CONFIG.FMS_URL + '/ajax/lookup_location?term=' + q;

        var x = $.ajax( {
            url: url,
            dataType: 'json',
            timeout: 30000,
            success: function(data, status) {
                if ( status == 'success' ) {
                    if ( data.latitude ) {
                        that.trigger('located', { coordinates: { latitude: data.latitude, longitude: data.longitude } } );
                    } else if ( data.suggestions ) {
                        that.trigger( 'failed', { locs: data.suggestions } );
                    } else {
                        that.trigger( 'failed', { msg: data.error } );
                    }
                } else {
                    that.trigger( 'failed', { msg: FMS.strings.location_problem } );
                }
            },
            error: function(data, status, errorThrown) {
                that.trigger( 'failed', { msg: FMS.strings.location_problem } );
            }
        } );
    },

    geolocate: function( minAccuracy ) {
        this.locating = 1;

        $('#ajaxOverlay').show();
        var that = this;
        this.watch_id = navigator.geolocation.watchPosition(
            function(location) {
                if ( that.watch_id == undefined ) { console.log( 'no watch id' ); return; }
                if ( minAccuracy && location.coords.accuracy > minAccuracy ) {
                    that.trigger('locating', location.coords.accuracy);
                } else {
                    console.log( 'located with accuracy of ' + location.coords.accuracy );
                    that.locating = 0;
                    navigator.geolocation.clearWatch( that.watch_id );
                    delete that.watch_id;

                    that.check_location(location.coords);
                }
            },
            function() {
                if ( that.watch_id == undefined ) { return; }
                that.locating = 0;
                navigator.geolocation.clearWatch( that.watch_id );
                delete that.watch_id;
                that.trigger('failed', { msg: FMS.strings.geolocation_failed } );
            },
            { timeout: 20000, enableHighAccuracy: true }
        );
    },

    check_location: function(coords) {
        var that = this;
        $.ajax( {
            url: CONFIG.FMS_URL + 'report/new/ajax',
            dataType: 'json',
            data: {
                latitude: coords.latitude,
                longitude: coords.longitude
            },
            timeout: 10000,
            success: function(data) {
                if (data.error) {
                    that.trigger('failed', { msg: data.error } );
                    return;
                }
                that.trigger('located', { coordinates: coords, details: data } )
            },
            error: function (data, status, errorThrown) {
                that.trigger('failed', { msg: FMS.strings.location_check_failed } );
            }
        } );
    }

}});
