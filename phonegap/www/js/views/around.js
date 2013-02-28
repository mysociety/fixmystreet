;(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        AroundView: FMS.FMSView.extend({
            template: 'around',
            tag: 'div',
            id: 'around-page',

            afterDisplay: function() {
                this.locate();
            },

            locate: function() {
                var that = this;
                var l = new Locate();
                _.extend(l, Backbone.Events);
                l.on('located', this.showMap, this );
                l.on('failed', this.noMap, this );

                l.geolocate();
            },

            showMap: function( info ) {
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
                $('#ajaxOverlay').hide();
                if ( details.msg ) {
                    this.displayError( details.msg );
                } else if ( details.locs ) {
                    this.displayError( STRINGS.multiple_locations );
                } else {
                    this.displayError( STRINGS.location_problem );
                }
            },
        })
    });
})(FMS, Backbone, _, $);
