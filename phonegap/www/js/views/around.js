(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        AroundView: FMS.FMSView.extend({
            template: 'around',
            id: 'around-page',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click #mark-here': 'onClickReport'
            },

            afterDisplay: function() {
                this.locate();
            },

            locate: function() {
                $('#locating').show();
                var that = this;
                var l = new Locate();
                _.extend(l, Backbone.Events);
                l.on('located', this.showMap, this );
                l.on('failed', this.noMap, this );
                l.on('locating', this.locationUpdate, this);

                l.geolocate(100);
            },

            locationUpdate: function( accuracy ) {
                $('#accuracy').text(parseInt(myLocation.coords.accuracy, 10) + 'm');
            },

            showMap: function( info ) {
                $('#locating').hide();
                var coords = info.coordinates;
                fixmystreet.latitude = coords.latitude;
                fixmystreet.longitude = coords.longitude;
                if ( !fixmystreet.map ) {
                    show_map();
                } else {
                    var centre = new OpenLayers.LonLat( coords.longitude, coords.latitude );
                    centre.transform(
                        new OpenLayers.Projection("EPSG:4326"),
                        fixmystreet.map.getProjectionObject()
                    );
                    fixmystreet.map.panTo(centre);
                }
            },

            noMap: function( details ) {
                $('#locating').hide();
                $('#ajaxOverlay').hide();
                if ( details.msg ) {
                    this.displayError( details.msg );
                } else if ( details.locs ) {
                    this.displayError( FMS.strings.multiple_locations );
                } else {
                    this.displayError( FMS.strings.location_problem );
                }
            },

           onClickReport: function() {
                var position = this.getCrossHairPosition();

                var l = new Locate();
                _.extend(l, Backbone.Events);
                l.on('failed', this.noMap, this );
                l.on('located', this.goPhoto, this );
                l.check_location( { latitude: position.lat, longitude: position.lon } );
            },

            goPhoto: function(info) {
                this.model.set('lat', info.coordinates.latitude );
                this.model.set('lon', info.coordinates.longitude );
                this.model.set('categories', info.details.category );

                this.navigate( 'photo' );
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

            _destroy: function() {
                fixmystreet = null;
            }
        })
    });
})(FMS, Backbone, _, $);
