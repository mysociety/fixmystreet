var fixmystreet = fixmystreet || {};

(function() {

    fixmystreet.maps = {
      // This function might be passed either an OpenLayers.LonLat (so has
      // lon and lat), or an OpenLayers.Geometry.Point (so has x and y).
      update_pin: function(lonlat) {
        var transformedLonlat = lonlat.clone().transform(
            fixmystreet.map.getProjectionObject(),
            new OpenLayers.Projection("EPSG:4326")
        );

        var lat = transformedLonlat.lat || transformedLonlat.y;
        var lon = transformedLonlat.lon || transformedLonlat.x;

        document.getElementById('fixmystreet.latitude').value = lat;
        document.getElementById('fixmystreet.longitude').value = lon;
        return {
            'url': { 'lon': lon, 'lat': lat },
            'state': { 'lon': lonlat.lon, 'lat': lonlat.lat }
        };
      },

      display_around: function() {
        // Required after changing the size of the map element
        fixmystreet.map.updateSize();

        // Dragging the map should fetch new local reports from server
        fixmystreet.bbox_strategy.activate();

        // Should not be able to drag normal pins!!
        drag.deactivate();

        // Force a redraw to return (de)selected marker to normal size
        fixmystreet.markers.refresh({force: true});
      },

      begin_report: function(lonlat) {
        if (typeof lonlat.clone !== 'function') {
            lonlat = new OpenLayers.LonLat(lonlat.lon, lonlat.lat);
        }

        if (fixmystreet.page == 'new') {
            /* Already have a pin */
            fixmystreet.markers.features[0].move(lonlat);
        } else {
            var markers = fixmystreet.maps.markers_list( [ [ lonlat.lat, lonlat.lon, 'green' ] ], false );
            fixmystreet.bbox_strategy.deactivate();
            fixmystreet.markers.removeAllFeatures();
            fixmystreet.markers.addFeatures( markers );
            drag.activate();
        }

        // check to see if markers are visible. We click the
        // link so that it updates the text in case they go
        // back
        if ( ! fixmystreet.markers.getVisibility() ) {
            $('#hide_pins_link').click();
        }
        return lonlat;
      },

      markers_list: function(pins, transform) {
        var markers = [];
        var size = fixmystreet.maps.marker_size_for_zoom(
            fixmystreet.map.getZoom() + fixmystreet.zoomOffset
        );
        var selected_size = fixmystreet.maps.selected_marker_size_for_zoom(
            fixmystreet.map.getZoom() + fixmystreet.zoomOffset
        );
        for (var i=0; i<pins.length; i++) {
            var pin = pins[i];
            var loc = new OpenLayers.Geometry.Point(pin[1], pin[0]);
            if (transform) {
                // The Strategy does this for us, so don't do it in that case.
                loc.transform(
                    new OpenLayers.Projection("EPSG:4326"),
                    fixmystreet.map.getProjectionObject()
                );
            }
            var marker_size = (pin[3] === window.selected_problem_id) ? selected_size : size;
            var marker = new OpenLayers.Feature.Vector(loc, {
                colour: pin[2],
                size: pin[5] || marker_size,
                faded: 0,
                id: pin[3],
                title: pin[4] || ''
            });
            markers.push( marker );
        }
        return markers;
      },

      markers_resize: function() {
        var size = fixmystreet.maps.marker_size_for_zoom(
            fixmystreet.map.getZoom() + fixmystreet.zoomOffset
        );
        var selected_size = fixmystreet.maps.selected_marker_size_for_zoom(
            fixmystreet.map.getZoom() + fixmystreet.zoomOffset
        );
        for (var i = 0; i < fixmystreet.markers.features.length; i++) {
            if (fixmystreet.markers.features[i].attributes.id == window.selected_problem_id) {
                fixmystreet.markers.features[i].attributes.size = selected_size;
            } else {
                fixmystreet.markers.features[i].attributes.size = size;
            }
        }
        fixmystreet.markers.redraw();
      },

      get_marker_by_id: function(problem_id) {
        return fixmystreet.markers.getFeaturesByAttribute('id', problem_id)[0];
      },

      marker_size_for_zoom: function(zoom) {
        if (zoom >= 15) {
            return window.selected_problem_id ? 'small' : 'normal';
        } else if (zoom >= 13) {
            return window.selected_problem_id ? 'mini' : 'small';
        } else {
            return 'mini';
        }
      },

      selected_marker_size_for_zoom: function(zoom) {
        if (zoom >= 15) {
            return 'big';
        } else if (zoom >= 13) {
            return 'normal';
        } else {
            return 'small';
        }
      }
    };

    var drag = {
        activate: function() {
            this._drag = new OpenLayers.Control.DragFeature( fixmystreet.markers, {
                onComplete: function(feature, e) {
                    fixmystreet.update_pin( feature.geometry );
                }
            } );
            fixmystreet.map.addControl( this._drag );
            this._drag.activate();
        },
        deactivate: function() {
            this._drag && this._drag.deactivate();
        }
    };

    function zoomToBounds(bounds) {
        if (!bounds) { return; }
        var center = bounds.getCenterLonLat();
        var z = fixmystreet.map.getZoomForExtent(bounds);
        if ( z < 13 && $('html').hasClass('mobile') ) {
            z = 13;
        }
        fixmystreet.map.setCenter(center, z);
    }

    // `markers.redraw()` in markers_highlight will trigger an
    // `overFeature` event if the mouse cursor is still over the same
    // marker on the map, which would then run markers_highlight
    // again, causing an infinite flicker while the cursor remains over
    // the same marker. We really only want to redraw the markers when
    // the cursor moves from one marker to another (ie: when there is an
    // overFeature followed by an outFeature followed by an overFeature).
    // Therefore, we keep track of the previous event in
    // fixmystreet.latest_map_hover_event and only call markers_highlight
    // if we know the previous event was different to the current one.
    // (See the `overFeature` and `outFeature` callbacks inside of
    // fixmystreet.select_feature).

    function markers_highlight(problem_id) {
        for (var i = 0; i < fixmystreet.markers.features.length; i++) {
            if (typeof problem_id == 'undefined') {
                // There is no highlighted marker, so unfade this marker
                fixmystreet.markers.features[i].attributes.faded = 0;
            } else if (problem_id == fixmystreet.markers.features[i].attributes.id) {
                // This is the highlighted marker, unfade it
                fixmystreet.markers.features[i].attributes.faded = 0;
            } else {
                // This is not the hightlighted marker, fade it
                fixmystreet.markers.features[i].attributes.faded = 1;
            }
        }
        fixmystreet.markers.redraw();
    }

    function sidebar_highlight(problem_id) {
        if (typeof problem_id !== 'undefined') {
            var $a = $('.item-list--reports a[href$="/' + problem_id + '"]');
            $a.parent().addClass('hovered');
        } else {
            $('.item-list--reports .hovered').removeClass('hovered');
        }
    }

    function marker_click(problem_id) {
        var $a = $('.item-list--reports a[href$="/' + problem_id + '"]');
        $a[0] && $a[0].click();
    }

    function categories_or_status_changed() {
        // If the category or status has changed we need to re-fetch map markers
        fixmystreet.markers.refresh({force: true});
    }

    function onload() {
        if ( fixmystreet.area.length ) {
            for (var i=0; i<fixmystreet.area.length; i++) {
                var area = new OpenLayers.Layer.Vector("KML", {
                    strategies: [ new OpenLayers.Strategy.Fixed() ],
                    protocol: new OpenLayers.Protocol.HTTP({
                        url: "/mapit/area/" + fixmystreet.area[i] + ".kml?simplify_tolerance=0.0001",
                        format: new OpenLayers.Format.KML()
                    })
                });
                fixmystreet.map.addLayer(area);
                if ( fixmystreet.area.length == 1 ) {
                    area.events.register('loadend', null, function(a,b,c) {
                        if ( fixmystreet.area_format ) {
                            area.styleMap.styles['default'].defaultStyle = fixmystreet.area_format;
                        }
                        zoomToBounds( area.getDataExtent() );
                    });
                }
            }
        }

        var pin_layer_style_map = new OpenLayers.StyleMap({
            'default': new OpenLayers.Style({
                graphicTitle: "${title}",
                graphicOpacity: 1,
                graphicZIndex: 11,
                backgroundGraphicZIndex: 10
            })
        });
        pin_layer_style_map.addUniqueValueRules('default', 'size', {
            'normal': {
                externalGraphic: fixmystreet.pin_prefix + "pin-${colour}.png",
                graphicWidth: 48,
                graphicHeight: 64,
                graphicXOffset: -24,
                graphicYOffset: -64,
                backgroundGraphic: fixmystreet.pin_prefix + "pin-shadow.png",
                backgroundWidth: 60,
                backgroundHeight: 30,
                backgroundXOffset: -7,
                backgroundYOffset: -30,
                popupYOffset: -40
            },
            'big': {
                externalGraphic: fixmystreet.pin_prefix + "pin-${colour}-big.png",
                graphicWidth: 78,
                graphicHeight: 105,
                graphicXOffset: -39,
                graphicYOffset: -105,
                backgroundGraphic: fixmystreet.pin_prefix + "pin-shadow-big.png",
                backgroundWidth: 88,
                backgroundHeight: 40,
                backgroundXOffset: -10,
                backgroundYOffset: -35
            },
            'small': {
                externalGraphic: fixmystreet.pin_prefix + "pin-${colour}-small.png",
                graphicWidth: 24,
                graphicHeight: 32,
                graphicXOffset: -12,
                graphicYOffset: -32,
                backgroundGraphic: fixmystreet.pin_prefix + "pin-shadow-small.png",
                backgroundWidth: 30,
                backgroundHeight: 15,
                backgroundXOffset: -4,
                backgroundYOffset: -15,
                popupYOffset: -20
            },
            'mini': {
                externalGraphic: fixmystreet.pin_prefix + "pin-${colour}-mini.png",
                graphicWidth: 16,
                graphicHeight: 20,
                graphicXOffset: -8,
                graphicYOffset: -20,
                popupYOffset: -10
            }
        });
        pin_layer_style_map.addUniqueValueRules('default', 'faded', {
            0: {
                graphicOpacity: 1
            },
            1: {
                graphicOpacity: 0.4
            }
        });
        var pin_layer_options = {
            rendererOptions: {
                yOrdering: true
            },
            styleMap: pin_layer_style_map
        };
        if (fixmystreet.page == 'around') {
            fixmystreet.bbox_strategy = fixmystreet.bbox_strategy || new OpenLayers.Strategy.FixMyStreet();
            pin_layer_options.strategies = [ fixmystreet.bbox_strategy ];
            pin_layer_options.protocol = new OpenLayers.Protocol.FixMyStreet({
                url: '/ajax',
                params: fixmystreet.all_pins ? { all_pins: 1 } : { },
                format: new OpenLayers.Format.FixMyStreet()
            });
        }
        fixmystreet.markers = new OpenLayers.Layer.Vector("Pins", pin_layer_options);
        fixmystreet.markers.events.register( 'loadend', fixmystreet.markers, function(evt) {
            if (fixmystreet.map.popups.length) {
                fixmystreet.map.removePopup(fixmystreet.map.popups[0]);
            }
        });

        var markers = fixmystreet.maps.markers_list( fixmystreet.pins, true );
        fixmystreet.markers.addFeatures( markers );

        if (fixmystreet.page == 'around' || fixmystreet.page == 'reports' || fixmystreet.page == 'my') {
            fixmystreet.select_feature = new OpenLayers.Control.SelectFeature(
                fixmystreet.markers,
                {
                    hover: true,
                    // Override clickFeature so that we can use it even though
                    // hover is true. http://gis.stackexchange.com/a/155675
                    clickFeature: function (feature) {
                        marker_click(feature.attributes.id);
                    },
                    overFeature: function (feature) {
                        if (fixmystreet.latest_map_hover_event != 'overFeature') {
                            document.getElementById('map').style.cursor = 'pointer';
                            markers_highlight(feature.attributes.id);
                            sidebar_highlight(feature.attributes.id);
                            fixmystreet.latest_map_hover_event = 'overFeature';
                        }
                    },
                    outFeature: function (feature) {
                        if (fixmystreet.latest_map_hover_event != 'outFeature') {
                            document.getElementById('map').style.cursor = '';
                            markers_highlight();
                            sidebar_highlight();
                            fixmystreet.latest_map_hover_event = 'outFeature';
                        }
                    }
                }
            );
            fixmystreet.map.addControl( fixmystreet.select_feature );
            fixmystreet.select_feature.activate();
            fixmystreet.map.events.register( 'zoomend', null, fixmystreet.maps.markers_resize );

            // If the category filter dropdown exists on the page set up the
            // event handlers to populate it and react to it changing
            if ($("select#filter_categories").length) {
                $("body").on("change", "#filter_categories", categories_or_status_changed);
            }
            // Do the same for the status dropdown
            if ($("select#statuses").length) {
                $("body").on("change", "#statuses", categories_or_status_changed);
            }
        } else if (fixmystreet.page == 'new') {
            drag.activate();
        }
        fixmystreet.map.addLayer(fixmystreet.markers);

        if ( fixmystreet.zoomToBounds ) {
            zoomToBounds( fixmystreet.markers.getDataExtent() );
        }

        $('#hide_pins_link').click(function(e) {
            e.preventDefault();
            var showhide = [
                'Show pins', 'Hide pins',
                'Dangos pinnau', 'Cuddio pinnau',
                "Vis nåler", "Skjul nåler",
                "Zeige Stecknadeln", "Stecknadeln ausblenden"
            ];
            for (var i=0; i<showhide.length; i+=2) {
                if (this.innerHTML == showhide[i]) {
                    fixmystreet.markers.setVisibility(true);
                    fixmystreet.select_feature.activate();
                    this.innerHTML = showhide[i+1];
                } else if (this.innerHTML == showhide[i+1]) {
                    fixmystreet.markers.setVisibility(false);
                    fixmystreet.select_feature.deactivate();
                    this.innerHTML = showhide[i];
                }
            }
        });

        $('#all_pins_link').click(function(e) {
            e.preventDefault();
            fixmystreet.markers.setVisibility(true);
            var texts = [
                'en', 'Show old', 'Hide old',
                'nb', 'Vis gamle', 'Skjul gamle',
                'cy', 'Cynnwys hen adroddiadau', 'Cuddio hen adroddiadau'
            ];
            for (var i=0; i<texts.length; i+=3) {
                if (this.innerHTML == texts[i+1]) {
                    this.innerHTML = texts[i+2];
                    fixmystreet.markers.protocol.options.params = { all_pins: 1 };
                    fixmystreet.markers.refresh( { force: true } );
                    lang = texts[i];
                } else if (this.innerHTML == texts[i+2]) {
                    this.innerHTML = texts[i+1];
                    fixmystreet.markers.protocol.options.params = { };
                    fixmystreet.markers.refresh( { force: true } );
                    lang = texts[i];
                }
            }
            if (lang == 'cy') {
                document.getElementById('hide_pins_link').innerHTML = 'Cuddio pinnau';
            } else if (lang == 'nb') {
                document.getElementById('hide_pins_link').innerHTML = 'Skjul nåler';
            } else {
                document.getElementById('hide_pins_link').innerHTML = 'Hide pins';
            }
        });

    }

    $(function(){

        // Set specific map config - some other JS included in the
        // template should define this
        fixmystreet.maps.config();

        // Create the basics of the map
        fixmystreet.map = new OpenLayers.Map(
            "map", OpenLayers.Util.extend({
                controls: fixmystreet.controls,
                displayProjection: new OpenLayers.Projection("EPSG:4326")
            }, fixmystreet.map_options)
        );

        // Set it up our way

        var layer;
        if (!fixmystreet.layer_options) {
            fixmystreet.layer_options = [ {} ];
        }
        if (!fixmystreet.layer_name) {
            fixmystreet.layer_name = "";
        }
        for (var i=0; i<fixmystreet.layer_options.length; i++) {
            fixmystreet.layer_options[i] = OpenLayers.Util.extend({
                // This option is used by XYZ-based layers
                zoomOffset: fixmystreet.zoomOffset,
                // This option is used by FixedZoomLevels-based layers
                minZoomLevel: fixmystreet.zoomOffset,
                // This option is thankfully used by them both
                numZoomLevels: fixmystreet.numZoomLevels
            }, fixmystreet.layer_options[i]);
            if (fixmystreet.layer_options[i].matrixIds) {
                layer = new fixmystreet.map_type(fixmystreet.layer_options[i]);
            } else {
                layer = new fixmystreet.map_type(fixmystreet.layer_name, fixmystreet.layer_options[i]);
            }
            fixmystreet.map.addLayer(layer);
        }

        if (!fixmystreet.map.getCenter()) {
            var centre = new OpenLayers.LonLat( fixmystreet.longitude, fixmystreet.latitude );
            centre.transform(
                new OpenLayers.Projection("EPSG:4326"),
                fixmystreet.map.getProjectionObject()
            );
            fixmystreet.map.setCenter(centre, fixmystreet.zoom || 3);
        }

        if (document.getElementById('mapForm')) {
            var click = new OpenLayers.Control.Click();
            fixmystreet.map.addControl(click);
            click.activate();
        }

        // Hide the pin filter submit button. Not needed because we'll use JS
        // to refresh the map when the filter inputs are changed.
        $(".report-list-filters [type=submit]").hide();

        if (fixmystreet.page == "my" || fixmystreet.page == "reports") {
            $(".report-list-filters select").change(function() {
                $(this).closest("form").submit();
            });
        }

        // Vector layers must be added onload as IE sucks
        if ($.browser.msie) {
            $(window).load(onload);
        } else {
            onload();
        }

        (function() {
            var timeout;
            $('.item-list--reports').on('mouseenter', '.item-list--reports__item', function(){
                var href = $('a', this).attr('href');
                var id = parseInt(href.replace(/^.*[/]([0-9]+)$/, '$1'));
                clearTimeout(timeout);
                markers_highlight(id);
            }).on('mouseleave', '.item-list--reports__item', function(){
                timeout = setTimeout(markers_highlight, 50);
            });
        })();
    });

// End maps closure
})();


/* Overridding the buttonDown function of PanZoom so that it does
   zoomTo(0) rather than zoomToMaxExtent()
*/
OpenLayers.Control.PanZoomFMS = OpenLayers.Class(OpenLayers.Control.PanZoom, {
    onButtonClick: function (evt) {
        var btn = evt.buttonElement;
        switch (btn.action) {
            case "panup":
                this.map.pan(0, -this.getSlideFactor("h"));
                break;
            case "pandown":
                this.map.pan(0, this.getSlideFactor("h"));
                break;
            case "panleft":
                this.map.pan(-this.getSlideFactor("w"), 0);
                break;
            case "panright":
                this.map.pan(this.getSlideFactor("w"), 0);
                break;
            case "zoomin":
            case "zoomout":
            case "zoomworld":
                var size = this.map.getSize(),
                    xy = { x: size.w / 2, y: size.h / 2 };
                switch (btn.action) {
                    case "zoomin":
                        this.map.zoomTo(this.map.getZoom() + 1, xy);
                        break;
                    case "zoomout":
                        this.map.zoomTo(this.map.getZoom() - 1, xy);
                        break;
                    case "zoomworld":
                        this.map.zoomTo(0, xy);
                        break;
                }
        }
    },
    moveTo: function(){},
    draw: function(px) {
        // A customised version of .draw() that doesn't specify
        // and dimensions/positions for the buttons, since we
        // size and position them all using CSS.
        OpenLayers.Control.prototype.draw.apply(this, arguments);
        this.buttons = [];
        this._addButton("panup", "north-mini.png");
        this._addButton("panleft", "west-mini.png");
        this._addButton("panright", "east-mini.png");
        this._addButton("pandown", "south-mini.png");
        this._addButton("zoomin", "zoom-plus-mini.png");
        this._addButton("zoomworld", "zoom-world-mini.png");
        this._addButton("zoomout", "zoom-minus-mini.png");
        return this.div;
    }
});

/* Overriding Permalink so that it can pass the correct zoom to OSM */
OpenLayers.Control.PermalinkFMS = OpenLayers.Class(OpenLayers.Control.Permalink, {
    _updateLink: function(alter_zoom) {
        var separator = this.anchor ? '#' : '?';
        var href = this.base;
        if (href.indexOf(separator) != -1) {
            href = href.substring( 0, href.indexOf(separator) );
        }

        var center = this.map.getCenter();

        var zoom = this.map.getZoom();
        if ( alter_zoom ) {
            zoom += fixmystreet.zoomOffset;
        }
        href += separator + OpenLayers.Util.getParameterString(this.createParams(center, zoom));
        // Could use mlat/mlon here as well if we are on a page with a marker
        if (this.anchor && !this.element) {
            window.location.href = href;
        }
        else {
            this.element.href = href;
        }
    },
    updateLink: function() {
        this._updateLink(0);
    }
});
OpenLayers.Control.PermalinkFMSz = OpenLayers.Class(OpenLayers.Control.PermalinkFMS, {
    updateLink: function() {
        this._updateLink(1);
    }
});

OpenLayers.Strategy.FixMyStreet = OpenLayers.Class(OpenLayers.Strategy.BBOX, {
    ratio: 1,
    // The transform in Strategy.BBOX's getMapBounds could mean you end up with
    // co-ordinates too precise, which could then cause the Strategy to think
    // it needs to update when it doesn't. So create a new bounds out of the
    // provided one to make sure it's passed through toFloat().
    getMapBounds: function() {
        var bounds = OpenLayers.Strategy.BBOX.prototype.getMapBounds.apply(this);
        if (bounds) {
            bounds = new OpenLayers.Bounds(bounds.toArray());
        }
        return bounds;
    },
    // The above isn't enough, however, because Strategy.BBOX's getMapBounds
    // and calculateBounds work out the bounds in different ways, the former by
    // transforming the map's extent to the layer projection, the latter by
    // adding or subtracting from the centre. As we have a ratio of 1, rounding
    // errors can still occur. This override makes calculateBounds always equal
    // getMapBounds (so no movement means no update).
    calculateBounds: function(mapBounds) {
        if (!mapBounds) {
            mapBounds = this.getMapBounds();
        }
        this.bounds = mapBounds;
    }
});

/* Pan data request handler */
// This class is used to get a JSON object from /ajax that contains
// pins for the map and HTML for the sidebar. It does a fetch whenever the map
// is dragged (modulo a buffer extending outside the viewport).
// This subclass is required so we can pass the 'filter_category' and 'status' query
// params to /ajax if the user has filtered the map.
OpenLayers.Protocol.FixMyStreet = OpenLayers.Class(OpenLayers.Protocol.HTTP, {
    read: function(options) {
        // Pass the values of the category and status fields as query params
        var filter_category = $("#filter_categories").val();
        if (filter_category !== undefined) {
            options.params = options.params || {};
            options.params.filter_category = filter_category;
        }
        var status = $("#statuses").val();
        if (status !== undefined) {
            options.params = options.params || {};
            options.params.status = status;
        }
        return OpenLayers.Protocol.HTTP.prototype.read.apply(this, [options]);
    },
    CLASS_NAME: "OpenLayers.Protocol.FixMyStreet"
});

/* Pan data handler */
OpenLayers.Format.FixMyStreet = OpenLayers.Class(OpenLayers.Format.JSON, {
    read: function(json, filter) {
        // Check we haven't received the data after the map has been clicked.
        if (fixmystreet.page == 'new') {
            // If we have, we want to do nothing, which means returning an
            // array of the back-projected version of the current pin
            var pin = fixmystreet.markers.features[0].clone();
            pin.geometry.transform(
                fixmystreet.map.getProjectionObject(),
                new OpenLayers.Projection("EPSG:4326")
            );
            return [ pin ];
        }
        if (typeof json == 'string') {
            obj = OpenLayers.Format.JSON.prototype.read.apply(this, [json, filter]);
        } else {
            obj = json;
        }
        var current;
        if (typeof(obj.current) != 'undefined' && (current = document.getElementById('current'))) {
            current.innerHTML = obj.current;
        }
        return fixmystreet.maps.markers_list( obj.pins, false );
    },
    CLASS_NAME: "OpenLayers.Format.FixMyStreet"
});

/* Click handler */
OpenLayers.Control.Click = OpenLayers.Class(OpenLayers.Control, {
    defaultHandlerOptions: {
        'single': true,
        'double': false,
        'pixelTolerance': 4,
        'stopSingle': false,
        'stopDouble': false
    },

    initialize: function(options) {
        this.handlerOptions = OpenLayers.Util.extend(
            {}, this.defaultHandlerOptions);
        OpenLayers.Control.prototype.initialize.apply(
            this, arguments
        );
        this.handler = new OpenLayers.Handler.Click(
            this, {
                'click': this.trigger
            }, this.handlerOptions);
    },

    trigger: function(e) {
        // If we are looking at an individual report, and the report was
        // ajaxed into the DOM from the all reports page, then clicking
        // the map background should take us back to the all reports list.
        if ($('.js-back-to-report-list').length) {
            $('.js-back-to-report-list').trigger('click');
            return true;
        }

        var lonlat = fixmystreet.map.getLonLatFromViewPortPx(e.xy);
        fixmystreet.display.begin_report(lonlat);

        if ( typeof ga !== 'undefined' && window.cobrand == 'fixmystreet' ) {
            ga('send', 'pageview', { 'page': '/map_click' } );
        }
    }
});

