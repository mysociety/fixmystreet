(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        AroundView: FMS.LocatorView.extend({
            template: 'around',
            id: 'around-page',

            events: {
                'pagehide': 'destroy',
                'pagebeforeshow': 'beforeDisplay',
                'pageshow': 'afterDisplay',
                'vclick #locate_cancel': 'goSearch',
                'vclick #login-options': 'goLogin',
                'vclick #view-my-reports': 'goReports',
                'vclick #search': 'goSearch',
                'vclick #relocate': 'centerMapOnPosition',
                'vclick #cancel': 'onClickCancel',
                'vclick #confirm': 'onClickReport',
                'vclick #confirm-map': 'onClickReport',
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
                $('#login-options').hide();
                $('#postcodeForm').hide();
                $('#cancel').hide();
                this.fixPageHeight();
            },

            afterDisplay: function() {
                if ( FMS.isOffline ) {
                    this.navigate( 'offline' );
                } else if ( this.model && this.model.get('lat') ) {
                    var modelInfo = { coordinates: { latitude: this.model.get('lat'), longitude: this.model.get('lon') } };
                    this.setMapPosition(modelInfo);
                    this.displayButtons(true);
                    this.setReportPosition({ lat: this.model.get('lat'), lon: this.model.get('lon') }, true);
                    this.listenTo(FMS.locator, 'gps_current_position', this.positionUpdate);
                } else if ( FMS.currentPosition ) {
                    var info = { coordinates: FMS.currentPosition };
                    FMS.currentPosition = null;
                    this.setMapPosition(info);
                    this.displayButtons(false);
                    this.listenTo(FMS.locator, 'gps_current_position', this.positionUpdate);
                } else {
                    this.locate();
                    this.displayButtons(false);
                }
            },

            setMapPosition: function( info ) {
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
            },

            gotLocation: function( info ) {
                $('#relocate').show();
                this.finishedLocating();

                this.listenTo(FMS.locator, 'gps_current_position', this.positionUpdate);

                this.located = true;
                this.locateCount = 21;

                this.setMapPosition( info );

                FMS.locator.trackPosition();
                // FIXME: not sure why I need to do this
                fixmystreet.select_feature.deactivate();
                fixmystreet.select_feature.activate();
                fixmystreet.nav.activate();
            },

            positionUpdate: function( info ) {
                $('#relocate').show();
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
                var msg = '';
                if ( details.msg ) {
                    msg = details.msg;
                } else {
                    msg = FMS.strings.location_problem;
                }
                if ( !fixmystreet.map ) {
                    $('#relocate').hide();
                    $('#mark-here').hide();
                }
                $('#front-howto').html('<p>' + msg + '</msg>');
                $('#front-howto').show();
            },

            displayButtons: function(isLocationSet) {
                if ( fixmystreet.map ) {
                    fixmystreet.nav.activate();
                }
                if (isLocationSet) {
                    $('#cancel').addClass('ui-btn-left').show();
                    $('#confirm').addClass('ui-btn-right ui-btn-icon-right').show();
                    $('#confirm-map').show();
                    $('#view-my-reports').hide();
                    $('#login-options').hide();
                    $('#mark-here').hide();
                    $('#postcodeForm').hide();
                    if ( fixmystreet.map ) {
                        fixmystreet.markers.setVisibility(false);
                        fixmystreet.select_feature.deactivate();
                        fixmystreet.bbox_strategy.deactivate();
                    }
                } else {
                    $('#cancel').hide().removeClass('ui-btn-left');
                    $('#confirm').hide().removeClass('ui-btn-right ui-btn-icon-right');
                    $('#confirm-map').hide();
                    $('#view-my-reports').show();
                    $('#login-options').show();
                    $('#mark-here').show();
                    $('#postcodeForm').show();
                    $('#reposition').hide();
                    if ( fixmystreet.map ) {
                        fixmystreet.bbox_strategy.activate();
                        fixmystreet.report_location.setVisibility(false);
                        fixmystreet.markers.setVisibility(true);
                        fixmystreet.select_feature.activate();
                    }
                }
            },

            setReportPosition: function(lonlat, convertPosition) {
                var markers = fms_markers_list( [ [ lonlat.lat, lonlat.lon, 'green', 'location', '', 'location' ] ], convertPosition );
                fixmystreet.report_location.removeAllFeatures();
                fixmystreet.report_location.addFeatures( markers );
                fixmystreet.report_location.setVisibility(true);
            },

            onClickMark: function(e) {
                e.preventDefault();
                this.displayButtons(true);
                $('#reposition').hide();

                var lonlat = this.getCrossHairPosition();
                this.setReportPosition(lonlat, true);
            },

            onClickCancel: function(e) {
                e.preventDefault();
                fixmystreet.markers.removeAllFeatures();
                fixmystreet_activate_drag();
                this.displayButtons(false);
                if ( this.model.isPartial() ) {
                    FMS.clearCurrentDraft();
                } else {
                    this.model.set('lat', null);
                    this.model.set('lon', null);
                }
            },

            onClickReposition: function(e) {
                e.preventDefault();
                var lonlat = this.getCrossHairPosition();
                lonlat.transform(
                    new OpenLayers.Projection("EPSG:4326"),
                    fixmystreet.map.getProjectionObject()
                );
                fixmystreet.report_location.features[0].move(lonlat);
                $('#reposition').hide();
            },

           onClickReport: function(e) {
                e.preventDefault();
                var position = this.getMarkerPosition();

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
                if ( fixmystreet.map ) {
                    fixmystreet.map.panTo(this.projectCoords( coords ));
                } else {
                    this.setMapPosition(info);
                    this.displayButtons(false);
                }
            },

            goAddress: function(e) {
                $('#relocate').show();
                $('#front-howto').html('').hide();
                var t = $(e.target);
                var lat = t.attr('data-lat');
                var long = t.attr('data-long');

                var coords  = { latitude: lat, longitude: long };
                if ( fixmystreet.map ) {
                    fixmystreet.map.panTo(this.projectCoords( coords ));
                } else {
                    this.setMapPosition({ coordinates: coords });
                }
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
                    $('#relocate').hide();
                    $('#front-howto').show();
                } else {
                    this.validationError( 'pc', FMS.strings.location_problem );
                }
            },

            pauseMap: function() {
                this.stopListening(FMS.locator);
                FMS.locator.stopTracking();
                if ( fixmystreet.map ) {
                    fixmystreet.nav.deactivate();
                }
            },

            goPhoto: function(info) {
                this.pauseMap();
                this.model.set('lat', info.coordinates.latitude );
                this.model.set('lon', info.coordinates.longitude );
                this.model.set('categories', info.details.category );
                if ( info.details.title_list ) {
                    this.model.set('title_list', info.details.title_list);
                }
                FMS.saveCurrentDraft();

                this.navigate( 'photo' );
            },

            goSearch: function(e) {
                e.preventDefault();
                if ( !fixmystreet.map ) {
                    this.$('#mark-here').hide();
                    this.$('#relocate').hide();
                    $('#front-howto').html('<p>' + FMS.strings.locate_dismissed + '</msg>');
                    $('#front-howto').show();
                }
                this.finishedLocating();
            },

            goLogin: function(e) {
                e.preventDefault();
                this.pauseMap();
                this.navigate( 'login' );
            },

            goReports: function(e) {
                e.preventDefault();
                this.pauseMap();
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

            getMarkerPosition: function() {
                var marker = fixmystreet.report_location.features[0].geometry;

                var position = new OpenLayers.LonLat( marker.x, marker.y );
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
