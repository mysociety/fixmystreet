// This function might be passed either an OpenLayers.LonLat (so has
// lon and lat) or an OpenLayers.Geometry.Point (so has x and y)
function fixmystreet_update_pin(lonlat) {
    lonlat.transform(
        fixmystreet.map.getProjectionObject(),
        new OpenLayers.Projection("EPSG:4326")
    );
    document.getElementById('fixmystreet.latitude').value = lonlat.lat || lonlat.y;
    document.getElementById('fixmystreet.longitude').value = lonlat.lon || lonlat.x;

    $.getJSON('/report/new/ajax', {
        latitude: $('#fixmystreet\\.latitude').val(),
        longitude: $('#fixmystreet\\.longitude').val()
    }, function(data) {
        if (data.error) {
            if (!$('#side-form-error').length) {
                $('<div id="side-form-error"/>').insertAfter($('#side-form'));
            }
            $('#side-form-error').html('<h1>' + translation_strings.reporting_a_problem + '</h1><p>' + data.error + '</p>').show();
            $('#side-form').hide();
            return;
        }
        $('#side-form, #site-logo').show();
        var old_category = $("select#form_category").val();
        $('#councils_text').html(data.councils_text);
        $('#form_category_row').html(data.category);
        if ($("select#form_category option[value=\""+old_category+"\"]").length) {
            $("select#form_category").val(old_category);
        }
        if ( data.extra_name_info && !$('#form_fms_extra_title').length ) {
            // there might be a first name field on some cobrands
            var lb = $('#form_first_name').prev();
            if ( lb.length === 0 ) { lb = $('#form_name').prev(); }
            lb.before(data.extra_name_info);
        }

        // If the category filter appears on the map and the user has selected
        // something from it, then pre-fill the category field in the report,
        // if it's a value already present in the drop-down.
        var category = $("#filter_categories").val();
        if (category !== undefined && $("#form_category option[value="+category+"]").length) {
            $("#form_category").val(category);
        }

        var category_select = $("select#form_category");
        if (category_select.val() != '-- Pick a category --') {
            category_select.change();
        }
    });

    if (!$('#side-form-error').is(':visible')) {
        $('#side-form, #site-logo').show();
        window.scrollTo(0, 0);
    }
}

function fixmystreet_activate_drag() {
    fixmystreet.drag = new OpenLayers.Control.DragFeature( fixmystreet.markers, {
        onComplete: function(feature, e) {
            fixmystreet_update_pin( feature.geometry.clone() );
        }
    } );
    fixmystreet.map.addControl( fixmystreet.drag );
    fixmystreet.drag.activate();
}

function fixmystreet_zoomToBounds(bounds) {
    if (!bounds) { return; }
    var center = bounds.getCenterLonLat();
    var z = fixmystreet.map.getZoomForExtent(bounds);
    if ( z < 13 && $('html').hasClass('mobile') ) {
        z = 13;
    }
    fixmystreet.map.setCenter(center, z);
    if (fixmystreet.state_map && fixmystreet.state_map == 'full') {
        fixmystreet.map.pan(-fixmystreet_midpoint(), -25, { animate: false });
    }
}

function fms_markers_list(pins, transform) {
    var markers = [];
    var size = fms_marker_size_for_zoom(fixmystreet.map.getZoom() + fixmystreet.zoomOffset);
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
        var marker = new OpenLayers.Feature.Vector(loc, {
            colour: pin[2],
            size: pin[5] || size,
            faded: 0,
            id: pin[3],
            title: pin[4] || ''
        });
        markers.push( marker );
    }
    return markers;
}

function fms_marker_size_for_zoom(zoom) {
    if (zoom >= 15) {
        return 'normal';
    } else if (zoom >= 13) {
        return 'small';
    } else {
        return 'mini';
    }
}

function fms_markers_resize() {
    var size = fms_marker_size_for_zoom(fixmystreet.map.getZoom() + fixmystreet.zoomOffset);
    for (var i = 0; i < fixmystreet.markers.features.length; i++) {
        fixmystreet.markers.features[i].attributes.size = size;
    }
    fixmystreet.markers.redraw();
}

// `markers.redraw()` in fms_markers_highlight will trigger an
// `overFeature` event if the mouse cursor is still over the same
// marker on the map, which would then run fms_markers_highlight
// again, causing an infinite flicker while the cursor remains over
// the same marker. We really only want to redraw the markers when
// the cursor moves from one marker to another (ie: when there is an
// overFeature followed by an outFeature followed by an overFeature).
// Therefore, we keep track of the previous event in
// fixmystreet.latest_map_hover_event and only call fms_markers_highlight
// if we know the previous event was different to the current one.
// (See the `overFeature` and `outFeature` callbacks inside of
// fixmystreet.select_feature).

function fms_markers_highlight(problem_id) {
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

function fms_sidebar_highlight(problem_id) {
    if (typeof problem_id !== 'undefined') {
        var $a = $('.item-list--reports a[href$="' + problem_id + '"]');
        $a.parent().addClass('hovered');
    } else {
        $('.item-list--reports .hovered').removeClass('hovered');
    }
}

function fms_marker_click(problem_id) {
    var $a = $('.item-list--reports a[href$="' + problem_id + '"]');
    $a[0] && $a[0].click();
}

function fms_categories_or_status_changed() {
    // If the category or status has changed we need to re-fetch map markers
    fixmystreet.markers.refresh({force: true});
}

function fixmystreet_onload() {
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
                    fixmystreet_zoomToBounds( area.getDataExtent() );
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
            graphicOpacity: 0.15
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

    var markers = fms_markers_list( fixmystreet.pins, true );
    fixmystreet.markers.addFeatures( markers );

    if (fixmystreet.page == 'around' || fixmystreet.page == 'reports' || fixmystreet.page == 'my') {
        fixmystreet.select_feature = new OpenLayers.Control.SelectFeature(
            fixmystreet.markers,
            {
                hover: true,
                // Override clickFeature so that we can use it even though
                // hover is true. http://gis.stackexchange.com/a/155675
                clickFeature: function (feature) {
                    fms_marker_click(feature.attributes.id);
                },
                overFeature: function (feature) {
                    if (fixmystreet.latest_map_hover_event != 'overFeature') {
                        document.getElementById('map').style.cursor = 'pointer';
                        fms_markers_highlight(feature.attributes.id);
                        fms_sidebar_highlight(feature.attributes.id);
                        fixmystreet.latest_map_hover_event = 'overFeature';
                    }
                },
                outFeature: function (feature) {
                    if (fixmystreet.latest_map_hover_event != 'outFeature') {
                        document.getElementById('map').style.cursor = '';
                        fms_markers_highlight();
                        fms_sidebar_highlight();
                        fixmystreet.latest_map_hover_event = 'outFeature';
                    }
                }
            }
        );
        fixmystreet.map.addControl( fixmystreet.select_feature );
        fixmystreet.select_feature.activate();
        fixmystreet.map.events.register( 'zoomend', null, fms_markers_resize );

        // If the category filter dropdown exists on the page set up the
        // event handlers to populate it and react to it changing
        if ($("select#filter_categories").length) {
            $("body").on("change", "#filter_categories", fms_categories_or_status_changed);
        }
        // Do the same for the status dropdown
        if ($("select#statuses").length) {
            $("body").on("change", "#statuses", fms_categories_or_status_changed);
        }
    } else if (fixmystreet.page == 'new') {
        fixmystreet_activate_drag();
    }
    fixmystreet.map.addLayer(fixmystreet.markers);

    if ( fixmystreet.zoomToBounds ) {
        fixmystreet_zoomToBounds( fixmystreet.markers.getDataExtent() );
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
    set_map_config();

    // Create the basics of the map
    fixmystreet.map = new OpenLayers.Map(
        "map", OpenLayers.Util.extend({
            controls: fixmystreet.controls,
            displayProjection: new OpenLayers.Projection("EPSG:4326")
        }, fixmystreet.map_options)
    );

    // Need to do this here, after the map is created
    if ($('html').hasClass('mobile')) {
        if (fixmystreet.page == 'around') {
            $('#fms_pan_zoom').css({ top: '2.75em' });
        }
    } else {
        $('#fms_pan_zoom').css({ top: '4.75em' });
    }

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

    if (fixmystreet.state_map && fixmystreet.state_map == 'full') {
        fixmystreet.map.pan(-fixmystreet_midpoint(), -25, { animate: false });
    }

    if (document.getElementById('mapForm')) {
        var click = new OpenLayers.Control.Click();
        fixmystreet.map.addControl(click);
        click.activate();
    }

    $(window).hashchange(function(){
        if (location.hash == '#report' && $('.rap-notes').is(':visible')) {
            $('.rap-notes-close').click();
            return;
        }

        if (location.hash && location.hash != '#') {
            return;
        }

        // Okay, back to around view.
        fixmystreet.bbox_strategy.activate();
        fixmystreet.markers.refresh( { force: true } );
        if ( fixmystreet.state_pins_were_hidden ) {
            // If we had pins hidden when we clicked map (which had to show the pin layer as I'm doing it in one layer), hide them again.
            $('#hide_pins_link').click();
        }
        fixmystreet.drag.deactivate();
        $('#side-form').hide();
        $('#side').show();
        $('#sub_map_links').show();
        //only on mobile
        $('#mob_sub_map_links').remove();
        $('.mobile-map-banner').html('<a href="/">' + translation_strings.home + '</a> ' + translation_strings.place_pin_on_map);
        fixmystreet.page = 'around';
    });

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
        $(window).load(fixmystreet_onload);
    } else {
        fixmystreet_onload();
    }

    (function() {
        var timeout;
        $('.item-list--reports').on('mouseenter', '.item-list--reports__item', function(){
            var href = $('a', this).attr('href');
            var id = parseInt(href.replace(/^.*[/]([0-9]+)$/, '$1'));
            clearTimeout(timeout);
            fms_markers_highlight(id);
        }).on('mouseleave', '.item-list--reports__item', function(){
            timeout = setTimeout(fms_markers_highlight, 50);
        });
    })();
});

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
                var mid_point = 0;
                if (fixmystreet.state_map && fixmystreet.state_map == 'full') {
                    mid_point = fixmystreet_midpoint();
                }
                var size = this.map.getSize(),
                    xy = { x: size.w / 2 + mid_point, y: size.h / 2 };
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
        if ( center && fixmystreet.state_map && fixmystreet.state_map == 'full' ) {
            // Translate the permalink co-ords so that 'centre' is accurate
            var mid_point = fixmystreet_midpoint();
            var p = this.map.getViewPortPxFromLonLat(center);
            p.x += mid_point;
            p.y += 25;
            center = this.map.getLonLatFromViewPortPx(p);
        }

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
        if (typeof json == 'string') {
            obj = OpenLayers.Format.JSON.prototype.read.apply(this, [json, filter]);
        } else {
            obj = json;
        }
        var current;
        if (typeof(obj.current) != 'undefined' && (current = document.getElementById('current'))) {
            current.innerHTML = obj.current;
        }
        return fms_markers_list( obj.pins, false );
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
        var cobrand = $('meta[name="cobrand"]').attr('content');
        if (typeof fixmystreet.nav_control != 'undefined') {
            fixmystreet.nav_control.disableZoomWheel();
        }
        var lonlat = fixmystreet.map.getLonLatFromViewPortPx(e.xy);
        if (fixmystreet.page == 'new') {
            /* Already have a pin */
            fixmystreet.markers.features[0].move(lonlat);
        } else {
            var markers = fms_markers_list( [ [ lonlat.lat, lonlat.lon, 'green' ] ], false );
            fixmystreet.bbox_strategy.deactivate();
            fixmystreet.markers.removeAllFeatures();
            fixmystreet.markers.addFeatures( markers );
            fixmystreet_activate_drag();
        }

        // check to see if markers are visible. We click the
        // link so that it updates the text in case they go
        // back
        if ( ! fixmystreet.markers.getVisibility() ) {
            fixmystreet.state_pins_were_hidden = true;
            $('#hide_pins_link').click();
        }

        // Store pin location in form fields, and check coverage of point
        fixmystreet_update_pin(lonlat);

        // Already did this first time map was clicked, so no need to do it again.
        if (fixmystreet.page == 'new') {
            return;
        }

        fixmystreet.map.updateSize(); // might have done, and otherwise Firefox gets confused.
        /* For some reason on IOS5 if you use the jQuery show method it
         * doesn't display the JS validation error messages unless you do this
         * or you cause a screen redraw by changing the phone orientation.
         * NB: This has to happen after the call to show() */
        if ( navigator.userAgent.match(/like Mac OS X/i)) {
            document.getElementById('side-form').style.display = 'block';
        }
        $('#side').hide();
        if (typeof heightFix !== 'undefined') {
            heightFix('#report-a-problem-sidebar', '.content', 26);
        }

        // If we clicked the map somewhere inconvenient
        var sidebar = $('#report-a-problem-sidebar');
        if (sidebar.css('position') == 'absolute') {
            var w = sidebar.width(), h = sidebar.height(),
                o = sidebar.offset(),
                $map_boxx = $('#map_box'), bo = $map_boxx.offset();
            // e.xy is relative to top left of map, which might not be top left of page
            e.xy.x += bo.left;
            e.xy.y += bo.top;

            // 24 and 64 is the width and height of the marker pin
            if (e.xy.y <= o.top || (e.xy.x >= o.left && e.xy.x <= o.left + w + 24 && e.xy.y >= o.top && e.xy.y <= o.top + h + 64)) {
                // top of the page, pin hidden by header;
                // or underneath where the new sidebar will appear
                lonlat.transform(
                    new OpenLayers.Projection("EPSG:4326"),
                    fixmystreet.map.getProjectionObject()
                );
                var p = fixmystreet.map.getViewPortPxFromLonLat(lonlat);
                p.x -= midpoint_box_excluding_column(o, w, bo, $map_boxx.width());
                lonlat = fixmystreet.map.getLonLatFromViewPortPx(p);
                fixmystreet.map.panTo(lonlat);
            }
        }

        $('#sub_map_links').hide();
        if ($('html').hasClass('mobile')) {
            var $map_box = $('#map_box'),
                width = $map_box.width(),
                height = $map_box.height();
            $map_box.append( '<p id="mob_sub_map_links">' + '<a href="#" id="try_again">' + translation_strings.try_again + '</a>' + '<a href="#ok" id="mob_ok">' + translation_strings.ok + '</a>' + '</p>' ).css({ position: 'relative', width: width, height: height, marginBottom: '1em' });
            // Making it relative here makes it much easier to do the scrolling later

            $('.mobile-map-banner').html('<a href="/">' + translation_strings.home + '</a> ' + translation_strings.right_place);

            // mobile user clicks 'ok' on map
            $('#mob_ok').toggle(function(){
                //scroll the height of the map box instead of the offset
                //of the #side-form or whatever as we will probably want
                //to do this on other pages where #side-form might not be
                $('html, body').animate({ scrollTop: height-60 }, 1000, function(){
                    $('#mob_sub_map_links').addClass('map_complete');
                    $('#mob_ok').text(translation_strings.map);
                });
            }, function(){
                $('html, body').animate({ scrollTop: 0 }, 1000, function(){
                    $('#mob_sub_map_links').removeClass('map_complete');
                    $('#mob_ok').text(translation_strings.ok);
                });
            });
        }

        fixmystreet.page = 'new';
        location.hash = 'report';
        if ( typeof ga !== 'undefined' && cobrand == 'fixmystreet' ) {
            ga('send', 'pageview', { 'page': '/map_click' } );
        }
    }
});

