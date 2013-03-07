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
                console.log('accuracy is ' + accuracy);
            },

            startLocateProgress: function() {
                this.locateCount = 1;
                var that = this;
                window.setTimeout( function() {that.showLocateProgress();}, 1000);
            },

            showLocateProgress: function() {
                if ( this.locateCount > 20 ) {
                    return;
                }
                var percent = ( ( 20 - this.locateCount ) / 20 ) * 100;
                $('#progress-bar').css( 'width', percent + '%' );
                this.locateCount++;
                var that = this;
                window.setTimeout( function() {that.showLocateProgress();}, 1000);
            },

            showMap: function( info ) {
                this.locateCount = 21;
                $('#progress-bar').css( 'background-color', 'green' );
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
                this.locateCount = 21;
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
