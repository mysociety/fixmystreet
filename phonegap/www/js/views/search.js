(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SearchView: FMS.FMSView.extend({
            template: 'address_search',
            id: 'search-page',

            events: {
                'vclick a.address': 'goAddress',
                'vclick #submit': 'search',
                'vclick #locate': 'goLocate',
                'pagehide': 'destroy',
                'pagebeforeshow': 'beforeDisplay',
                'pageshow': 'afterDisplay',
                'submit #postcodeForm': 'search'
            },

            afterDisplay: function() {
                if ( FMS.isOffline ) {
                    this.navigate('offline');
                }
            },

            search: function(e) {
                // this is to stop form submission
                e.preventDefault();
                this.clearValidationErrors();
                var pc = this.$('#pc').val();
                this.listenTo(FMS.locator, 'search_located', this.searchSuccess );
                this.listenTo(FMS.locator, 'search_failed', this.searchFail);

                FMS.locator.lookup(pc);
            },

            searchSuccess: function( info ) {
                this.stopListening(FMS.locator);
                var coords = info.coordinates;
                FMS.currentPosition = coords;
                this.navigate('around');
            },

            goAddress: function(e) {
                var t = $(e.target);
                var lat = t.attr('data-lat');
                var long = t.attr('data-long');

                FMS.currentPosition = { latitude: lat, longitude: long };
                this.navigate('around');
            },

            searchFail: function( details ) {
                // this makes sure any onscreen keyboard is dismissed
                $('#submit').focus();
                this.stopListening(FMS.locator);
                if ( details.msg ) {
                    this.validationError( 'pc', details.msg );
                } else if ( details.locations ) {
                    var multiple = '';
                    for ( var i = 0; i < details.locations.length; i++ ) {
                        var loc = details.locations[i];
                        var li = '<li><a class="address" id="location_' + i + '" data-lat="' + loc.lat + '" data-long="' + loc.long + '">' + loc.address + '</a></li>';
                        multiple = multiple + li;
                    }
                    $('#front-howto').html('<p>Multiple matches found</p><ul data-role="listview" data-inset="true">' + multiple + '</ul>');
                    $('.ui-page').trigger('create');
                } else {
                    this.validationError( 'pc', FMS.strings.location_problem );
                }
            },

            goLocate: function(e) {
                e.preventDefault();
                this.navigate( 'around' );
            },

            _destroy: function() {
                delete FMS.searchMessage;
                this.stopListening(FMS.locator);
            }
        })
    });
})(FMS, Backbone, _, $);
