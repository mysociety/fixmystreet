if (!Object.keys) {
  Object.keys = function(obj) {
    var result = [];
    for (var prop in obj) {
      if (Object.prototype.hasOwnProperty.call(obj, prop)) {
        result.push(prop);
      }
    }
    return result;
  };
}

var fixmystreet = fixmystreet || {};

fixmystreet.utils = fixmystreet.utils || {};

$.extend(fixmystreet.utils, {
    array_to_csv_line: function(arr) {
        var out = [], s;
        for (var i=0; i<arr.length; i++) {
            s = arr[i];
            if (/[",]/.test(s)) {
                s = '"' + s.replace('"', '""') + '"';
            }
            out.push(s);
        }
        return out.join(',');
    },

    // https://stackoverflow.com/questions/1293147/javascript-code-to-parse-csv-data/1293163#1293163
    csv_to_array: function( strData, strDelimiter ) {
        strDelimiter = (strDelimiter || ",");

        var objPattern = new RegExp(
            (
                "(\\" + strDelimiter + "|\\r?\\n|\\r|^)" +
                "(?:\"([^\"]*(?:\"\"[^\"]*)*)\"|" +
                "([^\"\\" + strDelimiter + "\\r\\n]*))"
            ),
            "gi"
            );

        var arrData = [[]];

        var arrMatches = objPattern.exec( strData );
        while (arrMatches) {

            var strMatchedDelimiter = arrMatches[ 1 ];

            if ( strMatchedDelimiter.length &&
                strMatchedDelimiter !== strDelimiter) {
                arrData.push( [] );
            }

            var strMatchedValue;
            if (arrMatches[ 2 ]) {
                strMatchedValue = arrMatches[ 2 ].replace(
                    new RegExp( "\"\"", "g" ),
                    "\""
                );
            } else {
                strMatchedValue = arrMatches[ 3 ];
            }

            arrData[ arrData.length - 1 ].push( strMatchedValue );
            arrMatches = objPattern.exec( strData );
        }

        return( arrData );
    },

    parse_query_string: function() {
        var qs = {};
        if (!location.search) {
            return qs;
        }
        $.each(location.search.substring(1).split(/[;&]/), function(n, i) {
            var s = i.split('='),
                k = s[0],
                v = s[1] && decodeURIComponent(s[1].replace(/\+/g, ' '));
            qs[k] = v;
        });
        return qs;
    }
});

(function() {

    fixmystreet.maps = fixmystreet.maps || {};

    var drag = {
        activate: function() {
            this._drag = new OpenLayers.Control.DragFeatureFMS( fixmystreet.markers, {
                onComplete: function(feature, e) {
                    fixmystreet.update_pin( feature.geometry );
                }
            } );
            fixmystreet.map.addControl( this._drag );
            this._drag.activate();
        },
        deactivate: function() {
            if (this._drag) {
              this._drag.deactivate();
            }
        }
    };

    $.extend(fixmystreet.maps, {
      update_pin: function(lonlat) {
        // This function might be passed either an OpenLayers.LonLat (so has
        // lon and lat), or an OpenLayers.Geometry.Point (so has x and y).
        if (lonlat.x !== undefined && lonlat.y !== undefined) {
            // It's a Point, convert to a LatLon
            lonlat = new OpenLayers.LonLat(lonlat.x, lonlat.y);
        }

        var transformedLonlat = lonlat.clone().transform(
            fixmystreet.map.getProjectionObject(),
            new OpenLayers.Projection("EPSG:4326")
        );

        var lat = transformedLonlat.lat;
        var lon = transformedLonlat.lon;

        document.getElementById('fixmystreet.latitude').value = lat;
        document.getElementById('fixmystreet.longitude').value = lon;

        $(fixmystreet).trigger('maps:update_pin', [ lonlat ]);

        return {
            'url': { 'lon': lon, 'lat': lat },
            'state': { 'lon': lonlat.lon, 'lat': lonlat.lat }
        };
      },

      display_around: function() {
        // Required after changing the size of the map element
        fixmystreet.map.updateSize();

        // Dragging the map should fetch new local reports from server
        if (fixmystreet.bbox_strategy) {
            fixmystreet.bbox_strategy.activate();
        }

        // Should not be able to drag normal pins!!
        drag.deactivate();

        // Force a redraw to return (de)selected marker to normal size
        // Redraw for all pages, kick off a refresh too for around
        // TODO Put 'new report' pin in different layer to simplify this and elsewhere
        fixmystreet.maps.markers_resize();
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
            var markers = fixmystreet.maps.markers_list( [ [ lonlat.lat, lonlat.lon, fixmystreet.pin_new_report_colour ] ], false );
            fixmystreet.bbox_strategy.layer.protocol.abort(fixmystreet.bbox_strategy.response);
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

      setup_inspector: function() {
        setup_inspector_marker_drag();
      },

      markers_list: function(pins, transform) {
        var markers = [];
        var size = fixmystreet.maps.marker_size();
        var selected_size = fixmystreet.maps.selected_marker_size();
        for (var i=0; i<pins.length; i++) {
            var pin = pins[i];
            if (pin[1] == 0 && pin[0] == 0) {
                continue;
            }
            var loc = new OpenLayers.Geometry.Point(pin[1], pin[0]);
            if (transform) {
                // The Strategy does this for us, so don't do it in that case.
                loc.transform(
                    new OpenLayers.Projection("EPSG:4326"),
                    fixmystreet.map.getProjectionObject()
                );
            }
            var id = pin[3] === undefined ? pin[3] : +pin[3];
            var marker_size = (id === window.selected_problem_id) ? selected_size : size;
            var draggable = (id === window.selected_problem_id) ? true : (pin[6] === false ? false : true);
            var marker = new OpenLayers.Feature.Vector(loc, {
                colour: pin[2],
                size: pin[5] || marker_size,
                faded: 0,
                id: id,
                title: pin[4] || '',
                draggable: draggable
            });
            markers.push( marker );
        }
        return markers;
      },

      markers_resize: function() {
        var size = fixmystreet.maps.marker_size();
        var selected_size = fixmystreet.maps.selected_marker_size();
        for (var i = 0; i < fixmystreet.markers.features.length; i++) {
            var attr = fixmystreet.markers.features[i].attributes;
            if (attr.id == window.selected_problem_id) {
                attr.size = selected_size;
                attr.draggable = true;
            } else {
                attr.size = size;
                attr.draggable = false;
            }
        }
        fixmystreet.markers.redraw();
      },

      get_marker_by_id: function(problem_id) {
        return fixmystreet.markers.getFeaturesByAttribute('id', problem_id)[0];
      },

      marker_size: function() {
        var zoom = fixmystreet.map.getZoom() + fixmystreet.zoomOffset;
        if (zoom >= 15) {
            return window.selected_problem_id ? 'small' : 'normal';
        } else if (zoom >= 13) {
            return window.selected_problem_id ? 'mini' : 'small';
        } else {
            return 'mini';
        }
      },

      selected_marker_size: function() {
        var zoom = fixmystreet.map.getZoom() + fixmystreet.zoomOffset;
        if (zoom >= 15) {
            return 'big';
        } else if (zoom >= 13) {
            return 'normal';
        } else {
            return 'small';
        }
      },

      // Handle a single report pin being moved by dragging it on the map.
      // pin_moved_callback is called with a new EPSG:4326 OpenLayers.LonLat if
      // the user drags the pin and confirms its new location.
      admin_drag: function(pin_moved_callback, confirm_change) {
          confirm_change = confirm_change || false;
          var original_lonlat;
          var drag = new OpenLayers.Control.DragFeatureFMS( fixmystreet.markers, {
              onStart: function(feature, e) {
                  // Keep track of where the feature started, so we can put it
                  // back if the user cancels the operation.
                  original_lonlat = new OpenLayers.LonLat(feature.geometry.x, feature.geometry.y);
              },
              onComplete: function(feature, e) {
                  var lonlat = feature.geometry.clone();
                  lonlat.transform(
                      fixmystreet.map.getProjectionObject(),
                      new OpenLayers.Projection("EPSG:4326")
                  );
                  if ((confirm_change && window.confirm(translation_strings.correct_position)) || !confirm_change) {
                      // Let the callback know about the newly confirmed position
                      pin_moved_callback(lonlat);
                  } else {
                      // Put it back
                      fixmystreet.markers.features[0].move(original_lonlat);
                  }
              }
          } );
          // Allow handled feature click propagation to other click handlers
          drag.handlers.feature.stopClick = false;
          fixmystreet.map.addControl( drag );
          drag.activate();
      },

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

      markers_highlight: function(problem_id) {
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
      },

      /* Keep track of how many things are loading simultaneously, and only hide
       * the loading spinner when everything has finished.
       * This allows multiple layers to be loading at once without each layer
       * having to keep track of the others or be responsible for manipulating
       * the spinner in the DOM.
       */
      loading_spinner: {
          count: {},
          show: function() {
              fixmystreet.maps.loading_spinner.count[this.id] = 1;
              if (Object.keys(fixmystreet.maps.loading_spinner.count).length) {
                  // Show the loading indicator over the map
                  $('#loading-indicator').removeClass('hidden');
                  $('#loading-indicator').attr('aria-hidden', false);
              }
          },
          hide: function() {
              delete fixmystreet.maps.loading_spinner.count[this.id];
              if (!Object.keys(fixmystreet.maps.loading_spinner.count).length) {
                  // Remove loading indicator
                  $('#loading-indicator').addClass('hidden');
                  $('#loading-indicator').attr('aria-hidden', true);
              }
          }
      },

      get_map_state: function() {
          var centre = fixmystreet.map.getCenter();
          return {
              zoom: fixmystreet.map.getZoom(),
              lat: centre.lat,
              lon: centre.lon,
          };
      },

      set_map_state: function(state) {
          fixmystreet.map.setCenter(
              new OpenLayers.LonLat( state.lon, state.lat ),
              state.zoom
          );
      }
    });

    /* Make sure pins aren't going to reload just because we're zooming out,
     * we already have the pins when the page loaded */
    function zoomToBounds(bounds) {
        if (!bounds || !fixmystreet.markers.strategies) { return; }
        var strategy = fixmystreet.markers.strategies[0];
        strategy.deactivate();
        var center = bounds.getCenterLonLat();
        var z = fixmystreet.map.getZoomForExtent(bounds);
        fixmystreet.map.setCenter(center, z);
        // Reactivate the strategy and make it think it's done an update
        strategy.activate();
        if (strategy instanceof OpenLayers.Strategy.BBOX) {
            strategy.calculateBounds();
            strategy.resolution = fixmystreet.map.getResolution();
        }
    }

    function sidebar_highlight(problem_id) {
        if (typeof problem_id !== 'undefined') {
            var $li = $('[data-report-id="' + problem_id + '"]');
            $li.addClass('hovered');
        } else {
            $('.item-list .hovered').removeClass('hovered');
        }
    }

    function marker_click(problem_id, evt) {
        var $a = $('.item-list a[href$="/' + problem_id + '"]');
        if (!$a[0]) {
            return;
        }

        // clickFeature operates on touchstart, we do not want the map click taking place on touchend!
        if (fixmystreet.maps.click_control) {
            fixmystreet.maps.click_control.deactivate();
        }

        // All of this, just so that ctrl/cmd-click on a pin works?!
        var event;
        if (typeof window.MouseEvent === 'function') {
            event = new MouseEvent('click', evt);
            $a[0].dispatchEvent(event);
        } else if (document.createEvent) {
            event = document.createEvent("MouseEvents");
            event.initMouseEvent(
                'click', true, true, window, 1,
                0, 0, 0, 0,
                evt.ctrlKey, evt.altKey, evt.shiftKey, evt.metaKey,
                0, null);
            $a[0].dispatchEvent(event);
        } else if (document.createEventObject) {
            event = document.createEventObject();
            event.metaKey = evt.metaKey;
            event.ctrlKey = evt.ctrlKey;
            if (event.metaKey === undefined) {
                event.metaKey = event.ctrlKey;
            }
            $a[0].fireEvent("onclick", event);
        } else {
            $a[0].click();
        }
    }

    function categories_or_status_changed() {
        // If the category or status has changed we need to re-fetch map markers
        fixmystreet.markers.refresh({force: true});
    }

    function replace_query_parameter(qs, id, key) {
        var value,
            $el = $('#' + id);
        if (!$el[0]) {
            return;
        }
        if ( $el[0].type === 'checkbox' ) {
            value = $el[0].checked ? '1' : '';
            if (value) {
                qs[key] = value;
            } else {
                delete qs[key];
            }
        } else {
            value = $el.val();
            if (value) {
                qs[key] = (typeof value === 'string') ? value : fixmystreet.utils.array_to_csv_line(value);
            } else {
                delete qs[key];
            }
        }
        return value;
    }

    function update_url(qs) {
        var new_url;
        if ($.isEmptyObject(qs)) {
            new_url = location.href.replace(location.search, "");
        } else if (location.search) {
            new_url = location.href.replace(location.search, '?' + $.param(qs));
        } else {
            new_url = location.href + '?' + $.param(qs);
        }
        return new_url;
    }

    function update_history(qs, data) {
        var new_url = update_url(qs);
        history.pushState(data, null, new_url);

        // Ensure the permalink control is updated when the filters change
        var permalink_controls = fixmystreet.map.getControlsByClass(/Permalink/);
        if (permalink_controls.length) {
            permalink_controls[0].updateLink();
        }
    }

    function page_changed_history() {
        if (!('pushState' in history)) {
            return;
        }
        var qs = fixmystreet.utils.parse_query_string();

        var show_old_reports = replace_query_parameter(qs, 'show_old_reports', 'show_old_reports');
        var page = $('.pagination:first').data('page');
        if (page > 1) {
            qs.p = page;
        } else {
            delete qs.p;
        }
        update_history(qs, {
            page_change: { 'page': page, 'show_old_reports': show_old_reports }
        });
    }

    function categories_or_status_changed_history() {
        if (!('pushState' in history)) {
            return;
        }
        var qs = fixmystreet.utils.parse_query_string();
        var filter_categories = replace_query_parameter(qs, 'filter_categories', 'filter_category');
        var filter_statuses = replace_query_parameter(qs, 'statuses', 'status');
        var sort_key = replace_query_parameter(qs, 'sort', 'sort');
        var show_old_reports = replace_query_parameter(qs, 'show_old_reports', 'show_old_reports');
        delete qs.p;
        update_history(qs, {
            filter_change: { 'filter_categories': filter_categories, 'statuses': filter_statuses, 'sort': sort_key, 'show_old_reports': show_old_reports }
        });
    }

    function setup_inspector_marker_drag() {
        // On the 'inspect report' page the pin is draggable, so we need to
        // update the easting/northing fields when it's dragged.
        if (!$('form#report_inspect_form').length) {
            // Not actually on the inspect report page
            return;
        }
        fixmystreet.maps.admin_drag(function(lonlat) {
            var bng = lonlat.clone().transform(
                new OpenLayers.Projection("EPSG:4326"),
                new OpenLayers.Projection("EPSG:27700") // TODO: Handle other projections
            );
            $("#problem_northing").text(bng.y.toFixed(1));
            $("#problem_easting").text(bng.x.toFixed(1));
            $("#problem_latitude").text(lonlat.y.toFixed(6));
            $("#problem_longitude").text(lonlat.x.toFixed(6));
            $("input[name=latitude]").val(lonlat.y.toFixed(6));
            $("input[name=longitude]").val(lonlat.x.toFixed(6));
        },
        false);
    }

    function onload() {
        if ( fixmystreet.area.length ) {
            var extent = new OpenLayers.Bounds();
            var lr = new OpenLayers.Geometry.LinearRing([
                new OpenLayers.Geometry.Point(20E6,20E6),
                new OpenLayers.Geometry.Point(10E6,20E6),
                new OpenLayers.Geometry.Point(0,20E6),
                new OpenLayers.Geometry.Point(-10E6,20E6),
                new OpenLayers.Geometry.Point(-20E6,20E6),
                new OpenLayers.Geometry.Point(-20E6,0),
                new OpenLayers.Geometry.Point(-20E6,-20E6),
                new OpenLayers.Geometry.Point(-10E6,-20E6),
                new OpenLayers.Geometry.Point(0,-20E6),
                new OpenLayers.Geometry.Point(10E6,-20E6),
                new OpenLayers.Geometry.Point(20E6,-20E6),
                new OpenLayers.Geometry.Point(20E6,0)
            ]);
            var loaded = 0;
            var new_geometry = new OpenLayers.Geometry.Polygon(lr);
            var style_area = function() {
                loaded++;
                var style = this.styleMap.styles['default'];
                if ( fixmystreet.area_format ) {
                    style.defaultStyle = fixmystreet.area_format;
                } else {
                    $.extend(style.defaultStyle, { fillColor: 'black', strokeColor: 'black' });
                }
                var geometry = this.features[0].geometry;
                if (geometry.CLASS_NAME == 'OpenLayers.Geometry.Collection' ||
                    geometry.CLASS_NAME == 'OpenLayers.Geometry.MultiPolygon') {
                    $.each(geometry.components, function(i, polygon) {
                        new_geometry.addComponents(polygon.components);
                        extent.extend(polygon.getBounds());
                    });
                } else if (geometry.CLASS_NAME == 'OpenLayers.Geometry.Polygon') {
                    new_geometry.addComponents(geometry.components);
                    extent.extend(this.getDataExtent());
                }
                if (loaded == fixmystreet.area.length) {
                    var f = this.features[0].clone();
                    f.geometry = new_geometry;
                    this.removeAllFeatures();
                    this.addFeatures([f]);
                    // Look at original href here to know if location was present at load.
                    // If it was, we don't want to zoom out to the bounds of the area.
                    var qs = OpenLayers.Util.getParameters(fixmystreet.original.href);
                    if (!qs.bbox && !qs.lat && !qs.lon) {
                        zoomToBounds(extent);
                    }
                } else {
                    fixmystreet.map.removeLayer(this);
                }
            };
            for (var i=0; i<fixmystreet.area.length; i++) {
                var area = new OpenLayers.Layer.Vector("KML", {
                    renderers: ['SVGBig', 'VML', 'Canvas'],
                    strategies: [ new OpenLayers.Strategy.Fixed() ],
                    protocol: new OpenLayers.Protocol.HTTP({
                        url: "/mapit/area/" + fixmystreet.area[i] + ".geojson?simplify_tolerance=0.0001",
                        format: new OpenLayers.Format.GeoJSON()
                    })
                });
                fixmystreet.map.addLayer(area);
                area.events.register('loadend', area, style_area);
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
        }
        if (fixmystreet.page == 'reports') {
            pin_layer_options.strategies = [ new OpenLayers.Strategy.FixMyStreetNoLoad() ];
        }
        if (fixmystreet.page == 'my') {
            pin_layer_options.strategies = [ new OpenLayers.Strategy.FixMyStreetFixed() ];
        }
        if (fixmystreet.page == 'around' || fixmystreet.page == 'reports' || fixmystreet.page == 'my') {
            pin_layer_options.protocol = new OpenLayers.Protocol.FixMyStreet({
                url: fixmystreet.original.href.split('?')[0] + '?ajax=1',
                format: new OpenLayers.Format.FixMyStreet()
            });
        }
        fixmystreet.markers = new OpenLayers.Layer.Vector("Pins", pin_layer_options);
        fixmystreet.markers.events.register( 'loadend', fixmystreet.markers, function(evt) {
            if (fixmystreet.map.popups.length) {
                fixmystreet.map.removePopup(fixmystreet.map.popups[0]);
            }
        });
        fixmystreet.markers.events.register( 'loadstart', null, fixmystreet.maps.loading_spinner.show);
        fixmystreet.markers.events.register( 'loadend', null, fixmystreet.maps.loading_spinner.hide);
        OpenLayers.Request.XMLHttpRequest.onabort = function() {
            fixmystreet.markers.events.triggerEvent("loadend", {response: null});
        };

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
                        marker_click(feature.attributes.id, this.handlers.feature.evt);
                    },
                    overFeature: function (feature) {
                        if (fixmystreet.latest_map_hover_event != 'overFeature') {
                            document.getElementById('map').style.cursor = 'pointer';
                            fixmystreet.maps.markers_highlight(feature.attributes.id);
                            sidebar_highlight(feature.attributes.id);
                            fixmystreet.latest_map_hover_event = 'overFeature';
                        }
                    },
                    outFeature: function (feature) {
                        if (fixmystreet.latest_map_hover_event != 'outFeature') {
                            document.getElementById('map').style.cursor = '';
                            fixmystreet.maps.markers_highlight();
                            sidebar_highlight();
                            fixmystreet.latest_map_hover_event = 'outFeature';
                        }
                    }
                }
            );
            fixmystreet.map.addControl( fixmystreet.select_feature );
            fixmystreet.select_feature.activate();
            fixmystreet.map.events.register( 'zoomend', null, function() {
                fixmystreet.maps.markers_resize();
                $(fixmystreet).trigger('map:zoomend');
            });

            // Set up the event handlers to populate the filters and react to them changing
            $("#filter_categories").on("change.filters", categories_or_status_changed);
            $("#statuses").on("change.filters", categories_or_status_changed);
            $("#sort").on("change.filters", categories_or_status_changed);
            $("#show_old_reports").on("change.filters", categories_or_status_changed);
            $('.js-pagination').on('change.filters', categories_or_status_changed);
            $('.js-pagination').on('click', 'a', function(e) {
                e.preventDefault();
                var page = $('.pagination:first').data('page');
                if ($(this).hasClass('show_old')) {
                    $("#show_old_reports").prop('checked', true);
                } else if ($(this).hasClass('next')) {
                    $('.pagination:first').data('page', page + 1);
                } else {
                    $('.pagination:first').data('page', page - 1);
                }
                fixmystreet.markers.protocol.use_page = true;
                $(this).trigger('change');
            });
            $("#filter_categories").on("change.user", categories_or_status_changed_history);
            $("#statuses").on("change.user", categories_or_status_changed_history);
            $("#sort").on("change.user", categories_or_status_changed_history);
            $("#show_old_reports").on("change.user", categories_or_status_changed_history);
            $('.js-pagination').on('click', 'a', page_changed_history);
        } else if (fixmystreet.page == 'new') {
            drag.activate();
        }
        fixmystreet.map.addLayer(fixmystreet.markers);

        if (fixmystreet.page == "report") {
            setup_inspector_marker_drag();
        }

        if ( fixmystreet.zoomToBounds ) {
            zoomToBounds( fixmystreet.markers.getDataExtent() );
        }

        $('#hide_pins_link, .big-hide-pins-link').click(function(e) {
            e.preventDefault();
            if (this.innerHTML == translation_strings.show_pins) {
                fixmystreet.markers.setVisibility(true);
                fixmystreet.select_feature.activate();
                $('#hide_pins_link, .big-hide-pins-link').html(translation_strings.hide_pins);
            } else if (this.innerHTML == translation_strings.hide_pins) {
                fixmystreet.markers.setVisibility(false);
                fixmystreet.select_feature.deactivate();
                $('#hide_pins_link, .big-hide-pins-link').html(translation_strings.show_pins);
            }
            if (typeof ga !== 'undefined') {
                ga('send', 'event', 'toggle-pins-on-map', 'click');
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
                theme: null,
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

        // map.getCenter() returns a position in "map units", but sometimes you
        // want the center in GPS-style latitude/longitude coordinates (WGS84)
        // for example, to pass as GET params to fixmystreet.com/report/new.
        fixmystreet.map.getCenterWGS84 = function() {
            return fixmystreet.map.getCenter().transform(
                fixmystreet.map.getProjectionObject(),
                new OpenLayers.Projection("EPSG:4326")
            );
        };

        if (document.getElementById('mapForm')) {
            var click = fixmystreet.maps.click_control = new OpenLayers.Control.Click();
            fixmystreet.map.addControl(click);
            click.activate();
        }

        // Vector layers must be added onload as IE sucks
        if ($.browser.msie) {
            $(window).load(onload);
        } else {
            onload();
        }

        // Allow external scripts to react to pans/zooms on the map,
        // by subscribing to $(fixmystreet).on('maps:update_view')
        fixmystreet.map.events.register('moveend', null, function(){
            $(fixmystreet).trigger('maps:update_view');
        });

        if (!fixmystreet.map.events.extensions.buttonclick.isDeviceTouchCapable) {
            // On touchscreens go straight to the report (see #2294).
            (function() {
                var timeout;
                $('#js-reports-list').on('mouseenter', '.item-list--reports__item', function(){
                    var href = $('a', this).attr('href');
                    var id = parseInt(href.replace(/^.*[\/]([0-9]+)$/, '$1'),10);
                    clearTimeout(timeout);
                    fixmystreet.maps.markers_highlight(id);
                }).on('mouseleave', '.item-list--reports__item', function(){
                    timeout = setTimeout(fixmystreet.maps.markers_highlight, 50);
                });
            })();
        }
    });

// End maps closure
})();


/* Overridding the buttonDown function of PanZoom so that it does
   zoomTo(0) rather than zoomToMaxExtent()
*/
OpenLayers.Control.PanZoomFMS = OpenLayers.Class(OpenLayers.Control.PanZoom, {
    _addButton: function(id1, id2) {
        var btn = document.createElement('div'),
            id = id1 + id2;
        btn.innerHTML = id1 + ' ' + id2;
        btn.id = this.id + "_" + id;
        btn.action = id;
        btn.className = "olButton";
        this.div.appendChild(btn);
        this.buttons.push(btn);
        return btn;
    },
    moveTo: function(){},
    draw: function(px) {
        // A customised version of .draw() that doesn't specify
        // and dimensions/positions for the buttons, since we
        // size and position them all using CSS.
        OpenLayers.Control.prototype.draw.apply(this, arguments);
        this.buttons = [];
        this._addButton("pan", "up");
        this._addButton("pan", "left");
        this._addButton("pan", "right");
        this._addButton("pan", "down");
        this._addButton("zoom", "in");
        this._addButton("zoom", "out");
        return this.div;
    }
});

OpenLayers.Control.ArgParserFMS = OpenLayers.Class(OpenLayers.Control.ArgParser, {
    getParameters: function(url) {
        var args = OpenLayers.Control.ArgParser.prototype.getParameters.apply(this, arguments);
        // Get defaults from provided data if not in URL
        if (!args.lat && !args.lon) {
            args.lon = fixmystreet.longitude;
            args.lat = fixmystreet.latitude;
        }
        if (args.lat && !args.zoom) {
            args.zoom = fixmystreet.zoom || 3;
        }
        return args;
    },

    CLASS_NAME: "OpenLayers.Control.ArgParserFMS"
});

/* Overriding Permalink so that it can pass the correct zoom to OSM */
OpenLayers.Control.PermalinkFMS = OpenLayers.Class(OpenLayers.Control.Permalink, {
    _updateLink: function(alter_zoom) {
        // this.base was originally set in initialize(), but the window's href
        // may have changed since then if e.g. the map filters have been updated.
        // NB this won't change the base of the 'problems nearby' permalink on
        // /report, as this would result in it pointing at the wrong page.
        if (this.base !== '/around' && fixmystreet.page !== 'report') {
            this.base = window.location.href;
        }

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

        var params = this.createParams(center, zoom);

        // Strip out the ugly OpenLayers layers state string
        delete params.layers;
        if (params.lat && params.lon) {
            // No need for the postcode string either, if we have a latlon
            delete params.pc;
        }

        href += separator + OpenLayers.Util.getParameterString(params);
        // Could use mlat/mlon here as well if we are on a page with a marker
        if (this.base == '/around') {
            href += '&js=1';
        }

        if (this.anchor && !this.element) {
            window.location.href = href;
        }
        else {
            this.element.href = href;
        }

        if ('replaceState' in history) {
            if (fixmystreet.page.match(/around|reports/)) {
                history.replaceState(
                    history.state,
                    null,
                    href
                );
            }
        }
    },
    updateLink: function() {
        this._updateLink(0);
    },
    CLASS_NAME: "OpenLayers.Control.PermalinkFMS"
});

OpenLayers.Strategy.FixMyStreet = OpenLayers.Class(OpenLayers.Strategy.BBOX, {
    // Update when the zoom changes, pagination means there might be new things
    resFactor: 1.5,
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

/* This strategy additionally does not update on load, as we already have the data. */
OpenLayers.Strategy.FixMyStreetNoLoad = OpenLayers.Class(OpenLayers.Strategy.FixMyStreet, {
    activate: function() {
        var activated = OpenLayers.Strategy.prototype.activate.call(this);
        if (activated) {
            this.layer.events.on({
                "moveend": this.update,
                "refresh": this.update,
                "visibilitychanged": this.update,
                scope: this
            });
        }
        return activated;
    }
});

/* Copy of Strategy.Fixed, but with no initial load */
OpenLayers.Strategy.FixMyStreetFixed = OpenLayers.Class(OpenLayers.Strategy.Fixed, {
    activate: function() {
        var activated = OpenLayers.Strategy.prototype.activate.apply(this, arguments);
        if (activated) {
            this.layer.events.on({
                "refresh": this.load,
                scope: this
            });
        }
        return activated;
    }
});

/* Pan data request handler */
// This class is used to get a JSON object from /around?ajax that contains
// pins for the map and HTML for the sidebar. It does a fetch whenever the map
// is dragged (modulo a buffer extending outside the viewport).
// This subclass is required so we can pass the 'filter_category' and 'status' query
// params to /around?ajax if the user has filtered the map.

fixmystreet.protocol_params = {
    filter_category: 'filter_categories',
    status: 'statuses',
    sort: 'sort'
};

OpenLayers.Protocol.FixMyStreet = OpenLayers.Class(OpenLayers.Protocol.HTTP, {
    initial_page: null,
    use_page: false,

    read: function(options) {
        // Pass the values of the category, status, and sort fields as query params
        options.params = options.params || {};
        $.each(fixmystreet.protocol_params, function(key, id) {
            var val = $('#' + id).val();
            if (val && val.length) {
                options.params[key] = val.join ? fixmystreet.utils.array_to_csv_line(val) : val;
            }
        });
        if ( $('#show_old_reports').is(':checked') ) {
            options.params.show_old_reports = 1;
        }
        var page;
        if (this.use_page) {
            page = $('.pagination:first').data('page');
            this.use_page = false;
        } else if (this.initial_page) {
            page = 1;
        } else {
            var qs = fixmystreet.utils.parse_query_string();
            this.initial_page = page = qs.p || 1;
        }
        options.params.p = page;
        return OpenLayers.Protocol.HTTP.prototype.read.apply(this, [options]);
    },
    CLASS_NAME: "OpenLayers.Protocol.FixMyStreet"
});

/* Pan data handler */
OpenLayers.Format.FixMyStreet = OpenLayers.Class(OpenLayers.Format.JSON, {
    read: function(json, filter) {
        var obj;
        if (typeof json == 'string') {
            obj = OpenLayers.Format.JSON.prototype.read.apply(this, [json, filter]);
        } else {
            obj = json;
        }
        var reports_list;
        if (typeof(obj.reports_list) != 'undefined' && (reports_list = document.getElementById('js-reports-list'))) {
            reports_list.innerHTML = obj.reports_list;
            if ( $('.item-list--reports').data('show-old-reports') ) {
                $('#show_old_reports_wrapper').removeClass('hidden');
            } else {
                $('#show_old_reports_wrapper').addClass('hidden');
            }
        }
        if (typeof(obj.pagination) != 'undefined') {
            $('.js-pagination').html(obj.pagination);
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

        if ( typeof ga !== 'undefined' && fixmystreet.cobrand == 'fixmystreet' ) {
            ga('send', 'pageview', { 'page': '/map_click' } );
        }
    }
});

/* Drag handler that allows individual features to disable dragging */
OpenLayers.Control.DragFeatureFMS = OpenLayers.Class(OpenLayers.Control.DragFeature, {
    CLASS_NAME: "OpenLayers.Control.DragFeatureFMS",

    overFeature: function(feature) {
        if (feature.attributes.draggable) {
            return OpenLayers.Control.DragFeature.prototype.overFeature.call(this, feature);
        } else {
            return false;
        }
    }
});

OpenLayers.Renderer.SVGBig = OpenLayers.Class(OpenLayers.Renderer.SVG, {
    MAX_PIXEL: 15E7,
    CLASS_NAME: "OpenLayers.Renderer.SVGBig"

});
