(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        AroundView: FMS.FMSView.extend({
            template: 'around',
            id: 'around-page',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click #locate_search': 'goSearch',
                'click #reports': 'goReports',
                'click #search': 'goSearch',
                'click #relocate': 'centerMapOnPosition',
                'click #mark-here': 'onClickReport'
            },

            afterDisplay: function() {
                if ( FMS.currentLocation ) {
                    var info = { coordinates: FMS.currentLocation };
                    FMS.currentLocation = null;
                    this.showMap(info);
                } else if ( this.model && this.model.get('lat') ) {
                    var modelInfo = { coordinates: { latitude: this.model.get('lat'), longitude: this.model.get('lon') } };
                    this.showMap(modelInfo);
                } else {
                    this.locate();
                }
            },

            locate: function() {
                $('#locating').show();
                this.listenTo(FMS.locator, 'gps_located', this.showMap);
                this.listenTo(FMS.locator, 'gps_failed', this.noMap );
                this.listenTo(FMS.locator, 'gps_locating', this.locationUpdate);

                FMS.locator.geolocate(100);
                this.startLocateProgress();
            },

            locationUpdate: function( accuracy ) {
                if ( accuracy && accuracy < 500 ) {
                    $('#progress-bar').css( 'background-color', 'orange' );
                } else if ( accuracy && accuracy < 250 ) {
                    $('#progress-bar').css( 'background-color', 'yellow' );
                } else {
                    $('#progress-bar').css( 'background-color', 'grey' );
                }

                $('#accuracy').text(parseInt(accuracy, 10) + 'm');
            },

            startLocateProgress: function() {
                this.located = false;
                this.locateCount = 1;
                var that = this;
                window.setTimeout( function() {that.showLocateProgress();}, 1000);
            },

            showLocateProgress: function() {
                if ( !this.located && this.locateCount > 20 ) {
                    FMS.searchMessage = FMS.strings.geolocation_failed;
                    this.navigate('search');
                    return;
                }
                var percent = ( ( 20 - this.locateCount ) / 20 ) * 100;
                $('#progress-bar').css( 'width', percent + '%' );
                this.locateCount++;
                var that = this;
                window.setTimeout( function() {that.showLocateProgress();}, 1000);
            },

            showMap: function( info ) {
                this.stopListening(FMS.locator, 'gps_locating');
                this.stopListening(FMS.locator, 'gps_located');
                this.stopListening(FMS.locator, 'gps_failed');

                this.listenTo(FMS.locator, 'gps_current_position', this.positionUpdate);

                this.located = true;
                this.locateCount = 21;
                $('#ajaxOverlay').hide();
                $('#locating').hide();

                var coords = info.coordinates;
                fixmystreet.latitude = coords.latitude;
                fixmystreet.longitude = coords.longitude;

                if ( !fixmystreet.map ) {
                    show_map();
                } else {
                    var centre = this.projectCoords( coords );
                    FMS.currentPosition = centre;
                    fixmystreet.map.panTo(centre);
                }
                FMS.locator.trackPosition();
            },

            positionUpdate: function( info ) {
                var centre = this.projectCoords( info.coordinates );

                FMS.currentPosition = centre;

                var point = new OpenLayers.Geometry.Point( centre.lon, centre.lat );

                fixmystreet.location.removeAllFeatures();
                    var x = new OpenLayers.Feature.Vector(
                        point,
                        {},
                        {
                            graphicZIndex: 3000,
                            graphicName: 'circle',
                            strokeColor: '#00f',
                            strokeWidth: 1,
                            fillOpacity: 1,
                            fillColor: '#00f',
                            pointRadius: 10
                        }
                    );
                fixmystreet.location.addFeatures([ x ]);
            },

            centerMapOnPosition: function(e) {
                e.preventDefault();
                if ( !fixmystreet.map ) {
                    return;
                }
                // if there isn't a currentPosition then something
                // is up so we probably should not recenter
                if ( FMS.currentPosition ) {
                    fixmystreet.map.panTo(FMS.currentPosition);
                }
            },

            noMap: function( details ) {
                this.stopListening(FMS.locator, 'gps_locating');
                this.stopListening(FMS.locator, 'gps_located');
                this.stopListening(FMS.locator, 'gps_failed');
                this.locateCount = 21;
                $('#locating').hide();
                $('#ajaxOverlay').hide();
                if ( details.msg ) {
                    FMS.searchMessage = details.msg;
                } else {
                    FMS.searchMessage = FMS.strings.location_problem;
                }
                this.navigate('search');
            },

           onClickReport: function() {
                var position = this.getCrossHairPosition();

                if ( FMS.isOffline ) {
                    this.navigate( 'offline' );
                } else {
                    this.listenTo(FMS.locator, 'gps_located', this.goPhoto);
                    this.listenTo(FMS.locator, 'gps_failed', this.noMap );
                    FMS.locator.check_location( { latitude: position.lat, longitude: position.lon } );
                }
            },

            goPhoto: function(info) {
                this.stopListening(FMS.locator);
                FMS.locator.stopTracking();
                this.model.set('lat', info.coordinates.latitude );
                this.model.set('lon', info.coordinates.longitude );
                this.model.set('categories', info.details.category );
                FMS.saveCurrentDraft();

                this.navigate( 'photo' );
            },

            goSearch: function(e) {
                e.preventDefault();
                this.stopListening(FMS.locator);
                FMS.locator.stopTracking();
                this.navigate( 'search' );
            },

            goReports: function(e) {
                e.preventDefault();
                this.stopListening(FMS.locator);
                FMS.locator.stopTracking();
                this.navigate( 'reports' );
            },

            getCrossHairPosition: function() {
                var cross = fixmystreet.map.getControlsByClass(
                "OpenLayers.Control.Crosshairs");

                var position = cross[0].getMapPosition();
                position.transform(
                    fixmystreet.map.getProjectionObject(),
                    new OpenLayers.Projection("EPSG:4326")
                );

                return position;
            },

            projectCoords: function( coords ) {
                var centre = new OpenLayers.LonLat( coords.longitude, coords.latitude );
                centre.transform(
                    new OpenLayers.Projection("EPSG:4326"),
                    fixmystreet.map.getProjectionObject()
                );

                return centre;
            },

            _destroy: function() {
                fixmystreet = null;
            }
        })
    });
})(FMS, Backbone, _, $);
