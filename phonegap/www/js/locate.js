(function(FMS, Backbone, _) {
    _.extend( FMS, {
        Locate: function() { return {
            locating: 0,
            updating: 0,

            lookup: function(q) {
                var that = this;
                if (!q) {
                    this.trigger('search_failed', { msg: FMS.strings.missing_location } );
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
                                that.trigger('search_located', { coordinates: { latitude: data.latitude, longitude: data.longitude } } );
                            } else if ( data.suggestions ) {
                                that.trigger( 'search_failed', { locs: data.suggestions } );
                            } else {
                                that.trigger( 'search_failed', { msg: data.error } );
                            }
                        } else {
                            that.trigger( 'search_failed', { msg: FMS.strings.location_problem } );
                        }
                    },
                    error: function(data, status, errorThrown) {
                        that.trigger( 'search_failed', { msg: FMS.strings.location_problem } );
                    }
                } );
            },

            geolocate: function( minAccuracy ) {
                console.log('geolocation');
                this.locating = 1;

                $('#ajaxOverlay').show();
                console.log(this);
                var that = this;
                this.watch_id = navigator.geolocation.watchPosition(
                    function(location) {
                    console.log('success');
                    console.log(location);
                        if ( that.watch_id === undefined ) { console.log( 'no watch id' ); return; }

                        if ( minAccuracy && location.coords.accuracy > minAccuracy ) {
                            that.trigger('gps_locating', location.coords.accuracy);
                        } else {
                            console.log( 'located with accuracy of ' + location.coords.accuracy );
                            that.locating = 0;
                            navigator.geolocation.clearWatch( that.watch_id );
                            delete that.watch_id;

                            that.check_location(location.coords);
                        }
                    },
                    function() {
                        if ( that.watch_id === undefined ) { return; }
                        that.locating = 0;
                        navigator.geolocation.clearWatch( that.watch_id );
                        delete that.watch_id;
                        that.trigger('gps_failed', { msg: FMS.strings.geolocation_failed } );
                    },
                    { timeout: 20000, enableHighAccuracy: true }
                );
            },

            updatePosition: function() {
                console.log('updatePosition');
                this.updating = 1;
                var that = this;
                this.update_watch_id = navigator.geolocation.watchPosition(
                    function(location) {
                        if ( that.update_watch_id === undefined ) { console.log( 'no update watch id' ); return; }

                        that.trigger('gps_current_position', { coordinates: location.coords } );
                    },
                    function() {},
                    { timeout: 20000, enableHighAccuracy: true }
                );
            },

            stopUpdating: function() {
                this.updating = 0;
                if ( this.update_watch_id ) {
                    navigator.geolocation.clearupdate_watch( this.watch_id );
                    delete this.update_watch_id;
                }
            },

            check_location: function(coords) {
                console.log('check_location');
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
                            that.trigger('gps_failed', { msg: data.error } );
                            return;
                        }
                        that.trigger('gps_located', { coordinates: coords, details: data } );
                    },
                    error: function (data, status, errorThrown) {
                        that.trigger('gps_failed', { msg: FMS.strings.location_check_failed } );
                    }
                } );
            }
        }; }
    });
})(FMS, Backbone, _);
