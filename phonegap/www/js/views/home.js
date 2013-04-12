(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        HomeView: FMS.FMSView.extend({
            template: 'home',
            id: 'front-page',

            afterRender: function() {
                /*
                if ( !can_geolocate && ( !navigator.network || !navigator.network.connection ) ) {
                    geocheck_count++;
                    window.setTimeout( decide_front_page, 1000 );
                    return;
                }

                // sometime onDeviceReady does not fire so set this here to be sure
                can_geolocate = true;

                geocheck_count = 0;
               */

                $('#locating').show();

            },

            afterDisplay: function() {
                if ( navigator && navigator.connection && ( navigator.connection.type == Connection.NONE ||
                        navigator.connection.type == Connection.UNKNOWN ) ) {
                    localStorage.offline = 1;
                    this.navigate( 'offline' );
                } else if ( FMS.currentDraft && (
                    FMS.currentDraft.get('title') || FMS.currentDraft.get('lat') ||
                    FMS.currentDraft.get('details') || FMS.currentDraft.get('file') )
                ) {
                    this.navigate( 'existing' );
                } else {
                    this.navigate( 'around' );
                }
            }
        })
    });
})(FMS, Backbone, _, $);
