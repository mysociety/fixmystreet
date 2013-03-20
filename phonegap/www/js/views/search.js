(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SearchView: FMS.FMSView.extend({
            template: 'address_search',
            id: 'search-page',

            events: {
                'click #submit': 'search',
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay'
            },

            search: function() {
                var pc = this.$('#pc').val();
                FMS.locator.on('search_located', this.searchSuccess, this );
                FMS.locator.on('search_failed', this.searchFail, this );

                $('#ajaxOverlay').show();
                FMS.locator.lookup(pc);
            },


            searchSuccess: function( info ) {
                var coords = info.coordinates;
                FMS.currentLocation = coords;
                this.navigate('around');
            },


            searchFail: function( details ) {
                $('#ajaxOverlay').hide();
                if ( details.msg ) {
                    this.displayError( details.msg );
                } else if ( details.locs ) {
                    this.displayError( FMS.strings.multiple_locations );
                } else {
                    this.displayError( FMS.strings.location_problem );
                }
            }
        })
    });
})(FMS, Backbone, _, $);
