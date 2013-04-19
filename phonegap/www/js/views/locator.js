(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        LocatorView: FMS.FMSView.extend({
            skipLocationCheck: false,

            locate: function() {
                $('#locating').show();
                this.listenTo(FMS.locator, 'gps_located', this.gotLocation);
                this.listenTo(FMS.locator, 'gps_failed', this.failedLocation);
                this.listenTo(FMS.locator, 'gps_locating', this.locationUpdate);

                FMS.locator.geolocate(CONFIG.ACCURACY, this.skipLocationCheck);
                this.startLocateProgress();
            },

            startLocateProgress: function() {
                this.located = false;
                this.locateCount = 1;
                var that = this;
                window.setTimeout( function() {that.showLocateProgress();}, 1000);
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

            showLocateProgress: function() {
                if ( !this.located && this.locateCount > 20 ) {
                    FMS.searchMessage = FMS.strings.geolocation_failed;
                    $('#locating').hide();
                    return;
                }
                var percent = ( ( 20 - this.locateCount ) / 20 ) * 100;
                $('#progress-bar').css( 'width', percent + '%' );
                this.locateCount++;
                var that = this;
                window.setTimeout( function() {that.showLocateProgress();}, 1000);
            },

            finishedLocating: function() {
                this.stopListening(FMS.locator, 'gps_locating');
                this.stopListening(FMS.locator, 'gps_located');
                this.stopListening(FMS.locator, 'gps_failed');
                $('#locating').hide();
            },

            failedLocation: function(details) {
                this.finishedLocating();
            },

            gotLocation: function(info) {
                this.finishedLocating();
            }
        })
    });
})(FMS, Backbone, _, $);
