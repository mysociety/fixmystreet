(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        AroundView: FMS.LocatorView.extend({
            template: 'around',
            id: 'around-page',

            events: {
                'pagehide': 'destroy',
                'pagebeforeshow': 'beforeDisplay',
                'pageshow': 'afterDisplay',
                'vclick #locate_search': 'goSearch',
                'vclick #login-options': 'goLogin',
                'vclick #view-my-reports': 'goReports',
                'vclick #search': 'goSearch',
                'vclick #relocate': 'centerMapOnPosition',
                'vclick #cancel': 'onClickCancel',
                'vclick #confirm': 'onClickReport',
                'vclick #mark-here': 'onClickMark',
                'vclick #reposition': 'onClickReposition',
                'vclick a.address': 'goAddress',
                'submit #postcodeForm': 'search'
            },

            render: function(){
                if ( !this.template ) {
                    console.log('no template to render');
                    return;
                }
                template = _.template( tpl.get( this.template ) );
                if ( this.model ) {
                    this.$el.html(template({ model: this.model.toJSON(), user: FMS.currentUser.toJSON() }));
                } else {
                    this.$el.html(template());
                }
                this.afterRender();
                return this;
            },

            beforeDisplay: function() {
                $('a[data-role="button"]').hide();
                $('#cancel').hide();
            },

            afterDisplay: function() {
                if ( FMS.isOffline ) {
                    this.navigate( 'offline' );
                } else if ( this.model && this.model.get('lat') ) {
                    var modelInfo = { coordinates: { latitude: this.model.get('lat'), longitude: this.model.get('lon') } };
                    this.gotLocation(modelInfo);
                } else if ( FMS.currentPosition ) {
                    var info = { coordinates: FMS.currentPosition };
                    FMS.currentPosition = null;
                    this.gotLocation(info);
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
                this.displayButtons();
                FMS.locator.trackPosition();
                // FIXME: not sure why I need to do this
                fixmystreet.select_feature.deactivate();
                fixmystreet.select_feature.activate();
                fixmystreet.nav.activate();
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
                            'externalGraphic': 'images/gps-marker.svg', 
                            pointRadius: 16
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
                    fixmystreet.map.panTo(this.projectCoords( FMS.currentPosition ));
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

            displayButtons: function() {
                $('#relocate').show();
                if ( this.model.get('lat') ) {
                    $('#cancel').addClass('ui-btn-left').show();
                    $('#confirm').addClass('ui-btn-right ui-btn-icon-right').show();
                    $('#view-my-reports').hide();
                    $('#login-options').hide();
                    $('#mark-here').hide();
                    $('#postcodeForm').hide();
                    fixmystreet.markers.setVisibility(false);
                    fixmystreet.select_feature.deactivate();
                } else {
                    $('#cancel').hide().removeClass('ui-btn-left');
                    $('#confirm').hide().removeClass('ui-btn-right ui-btn-icon-right');
                    $('#view-my-reports').show();
                    $('#login-options').show();
                    $('#mark-here').show();
                    $('#postcodeForm').show();
                    fixmystreet.markers.setVisibility(true);
                    fixmystreet.select_feature.activate();
                }
            },

            onClickMark: function(e) {
                e.preventDefault();
                $('#cancel').addClass('ui-btn-left').show();
                $('#confirm').addClass('ui-btn-right ui-btn-icon-right').show();
                $('#view-my-reports').hide();
                $('#login-options').hide();
                $('#mark-here').hide();
                $('#postcodeForm').hide();
                fixmystreet.bbox_strategy.deactivate();
                var lonlat = this.getCrossHairPosition();
                var markers = fms_markers_list( [ [ lonlat.lat, lonlat.lon, 'green', 'location', '', 'location' ] ], true );
                fixmystreet.markers.removeAllFeatures();
                fixmystreet.markers.addFeatures( markers );
            },

            onClickCancel: function(e) {
                e.preventDefault();
                $('#cancel').hide().removeClass('ui-btn-left');
                $('#confirm').hide().removeClass('ui-btn-right ui-btn-icon-right');
                $('#view-my-reports').show();
                $('#login-options').show();
                $('#mark-here').show();
                $('#postcodeForm').show();
                if ( this.model.isPartial() ) {
                    FMS.clearCurrentDraft();
                } else {
                    this.model.set('lat', null);
                    this.model.set('lon', null);
                }
                fixmystreet.bbox_strategy.activate();
                fixmystreet.select_feature.activate();
            },

            onClickReposition: function(e) {
                e.preventDefault();
                var lonlat = this.getCrossHairPosition();
                lonlat.transform(
                    new OpenLayers.Projection("EPSG:4326"),
                    fixmystreet.map.getProjectionObject()
                );
                fixmystreet.markers.features[0].move(lonlat);
                $('#reposition').hide();
            },

           onClickReport: function() {
                var position = this.getCrossHairPosition();

                if ( FMS.isOffline ) {
                    this.stopListening(FMS.locator);
                    FMS.locator.stopTracking();
                    // these may be out of the area but lets just save them
                    // for now and they can be checked when we are online.
                    this.model.set('lat', position.lat );
                    this.model.set('lon', position.lon );
                    FMS.saveCurrentDraft();
                    this.navigate( 'offline' );
                } else {
                    this.listenTo(FMS.locator, 'gps_located', this.goPhoto);
                    this.listenTo(FMS.locator, 'gps_failed', this.noMap );
                    FMS.locator.check_location( { latitude: position.lat, longitude: position.lon } );
                }
            },

            search: function(e) {
                $('#pc').blur();
                // this is to stop form submission
                e.preventDefault();
                $('#front-howto').hide();
                this.clearValidationErrors();
                var pc = this.$('#pc').val();
                this.listenTo(FMS.locator, 'search_located', this.searchSuccess );
                this.listenTo(FMS.locator, 'search_failed', this.searchFail);

                FMS.locator.lookup(pc);
            },

            searchSuccess: function( info ) {
                this.stopListening(FMS.locator);
                var coords = info.coordinates;
                fixmystreet.map.panTo(this.projectCoords( coords ));
            },

            goAddress: function(e) {
                $('#front-howto').html('').hide();
                var t = $(e.target);
                var lat = t.attr('data-lat');
                var long = t.attr('data-long');

                var coords  = { latitude: lat, longitude: long };
                fixmystreet.map.panTo(this.projectCoords( coords ));
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
                    $('#front-howto').show();
                } else {
                    this.validationError( 'pc', FMS.strings.location_problem );
                }
            },

            goPhoto: function(info) {
                this.stopListening(FMS.locator);
                FMS.locator.stopTracking();
                this.model.set('lat', info.coordinates.latitude );
                this.model.set('lon', info.coordinates.longitude );
                this.model.set('categories', info.details.category );
                if ( info.details.title_list ) {
                    this.model.set('title_list', info.details.title_list);
                }
                FMS.saveCurrentDraft();
                fixmystreet.nav.deactivate();

                this.navigate( 'photo' );
            },

            goSearch: function(e) {
                e.preventDefault();
                this.stopListening(FMS.locator);
                FMS.locator.stopTracking();
                this.navigate( 'search' );
            },

            goLogin: function(e) {
                e.preventDefault();
                this.stopListening(FMS.locator);
                FMS.locator.stopTracking();
                this.navigate( 'login' );
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
            }
        })
    });
})(FMS, Backbone, _, $);
