(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        AroundView: FMS.LocatorView.extend({
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
                if ( FMS.isOffline ) {
                    this.navigate( 'offline' );
                } else if ( FMS.currentPosition ) {
                    var info = { coordinates: FMS.currentPosition };
                    FMS.currentPosition = null;
                    this.gotLocation(info);
                } else if ( this.model && this.model.get('lat') ) {
                    var modelInfo = { coordinates: { latitude: this.model.get('lat'), longitude: this.model.get('lon') } };
                    this.gotLocation(modelInfo);
                } else {
                    this.locate();
                }
            },

            gotLocation: function( info ) {
                this.finishedLocating();

                this.listenTo(FMS.locator, 'gps_current_position', this.positionUpdate);

                this.located = true;
                this.locateCount = 21;

                var coords = info.coordinates;
                fixmystreet.latitude = coords.latitude;
                fixmystreet.longitude = coords.longitude;

                if ( !fixmystreet.map ) {
                    show_map();
                } else {
                    FMS.currentPosition = coords;
                    var centre = this.projectCoords( coords );
                    fixmystreet.map.panTo(centre);
                }
                FMS.locator.trackPosition();
            },

            positionUpdate: function( info ) {
                FMS.currentPosition = info.coordinates;
                var centre = this.projectCoords( info.coordinates );

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

            failedLocation: function( details ) {
                this.finishedLocating();
                this.locateCount = 21;
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
