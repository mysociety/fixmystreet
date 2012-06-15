// This function might be passed either an OpenLayers.LonLat (so has
// lon and lat) or an OpenLayers.Geometry.Point (so has x and y)
function fixmystreet_update_pin(lonlat) {
    lonlat.transform(
        fixmystreet.map.getProjectionObject(),
        new OpenLayers.Projection("EPSG:4326")
    );
    document.getElementById('fixmystreet.latitude').value = lonlat.lat || lonlat.y;
    document.getElementById('fixmystreet.longitude').value = lonlat.lon || lonlat.x;
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

function fms_markers_list(pins, transform) {
    var markers = [];
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
            size: pin[5] || 'normal',
            id: pin[3],
            title: pin[4] || ''
        });
        markers.push( marker );
    }
    return markers;
}

function fixmystreet_onload() {
    if ( fixmystreet.area ) {
        var area = new OpenLayers.Layer.Vector("KML", {
            strategies: [ new OpenLayers.Strategy.Fixed() ],
            protocol: new OpenLayers.Protocol.HTTP({
                url: CONFIG.FMS_URL + "/mapit/area/" + fixmystreet.area + ".kml?simplify_tolerance=0.0001",
                format: new OpenLayers.Format.KML()
            })
        });
        fixmystreet.map.addLayer(area);
        area.events.register('loadend', null, function(a,b,c) {
            var bounds = area.getDataExtent();
            if (bounds) {
                var center = bounds.getCenterLonLat();
                fixmystreet.map.setCenter(center, fixmystreet.map.getZoomForExtent(bounds), false, true);
            }
        });
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
            externalGraphic: "i/pin-${colour}.png",
            graphicWidth: 48,
            graphicHeight: 64,
            graphicXOffset: -24,
            graphicYOffset: -64,
            backgroundGraphic: "i/pin-shadow.png",
            backgroundWidth: 60,
            backgroundHeight: 30,
            backgroundXOffset: -7,
            backgroundYOffset: -30
        },
        'big': {
            externalGraphic: "i/pin-${colour}-big.png",
            graphicWidth: 78,
            graphicHeight: 105,
            graphicXOffset: -39,
            graphicYOffset: -105,
            backgroundGraphic: "i/pin-shadow-big.png",
            backgroundWidth: 88,
            backgroundHeight: 40,
            backgroundXOffset: -10,
            backgroundYOffset: -35
        }
    });
    var pin_layer_options = {
        rendererOptions: {
            yOrdering: true
        },
        styleMap: pin_layer_style_map
    };
    if (fixmystreet.page == 'around') {
        fixmystreet.bbox_strategy = new OpenLayers.Strategy.BBOX({ ratio: 1 });
        pin_layer_options.strategies = [ fixmystreet.bbox_strategy ];
        pin_layer_options.protocol = new OpenLayers.Protocol.HTTP({
            url: CONFIG.FMS_URL + '/ajax',
            params: fixmystreet.all_pins ? { all_pins: 1 } : { },
            format: new OpenLayers.Format.FixMyStreet()
        });
    }
    fixmystreet.markers = new OpenLayers.Layer.Vector("Pins", pin_layer_options);
    fixmystreet.markers.events.register( 'loadend', fixmystreet.markers, function(evt) {
        if (fixmystreet.map.popups.length) fixmystreet.map.removePopup(fixmystreet.map.popups[0]);
    });

    var markers = fms_markers_list( fixmystreet.pins, true );
    fixmystreet.markers.addFeatures( markers );
    if (fixmystreet.page == 'around' || fixmystreet.page == 'reports' || fixmystreet.page == 'my') {
        fixmystreet.select_feature = new OpenLayers.Control.SelectFeature( fixmystreet.markers );
        var selectedFeature;
        function onPopupClose(evt) {
            fixmystreet.select_feature.unselect(selectedFeature);
            OpenLayers.Event.stop(evt);
        }
        fixmystreet.markers.events.register( 'featureunselected', fixmystreet.markers, function(evt) {
            var feature = evt.feature, popup = feature.popup;
            fixmystreet.map.removePopup(popup);
            popup.destroy();
            feature.popup = null;
        });
        fixmystreet.markers.events.register( 'featureselected', fixmystreet.markers, function(evt) {
            var feature = evt.feature;
            selectedFeature = feature;
            var popup = new OpenLayers.Popup.FramedCloud("popup",
                feature.geometry.getBounds().getCenterLonLat(),
                null,
                feature.attributes.title + "<br><a href=" + CONFIG.FMS_URL + "/report/" + feature.attributes.id + ">More details</a>",
                { size: new OpenLayers.Size(0,0), offset: new OpenLayers.Pixel(0,-40) },
                true, onPopupClose);
            feature.popup = popup;
            fixmystreet.map.addPopup(popup);
        });
        fixmystreet.map.addControl( fixmystreet.select_feature );
        fixmystreet.select_feature.activate();
    } else if (fixmystreet.page == 'new') {
        fixmystreet_activate_drag();
    }
    fixmystreet.map.addLayer(fixmystreet.markers);

    if ( fixmystreet.zoomToBounds ) {
        var bounds = fixmystreet.markers.getDataExtent();
        if (bounds) { fixmystreet.map.zoomToExtent( bounds ); }
    }

    $('#hide_pins_link').click(function(e) {
        e.preventDefault();
        var showhide = [
            'Show pins', 'Hide pins',
            'Dangos pinnau', 'Cuddio pinnau',
            "Vis nåler", "Gjem nåler"
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
            'nb', 'Inkluder utdaterte problemer', 'Skjul utdaterte rapporter',
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
            document.getElementById('hide_pins_link').innerHTML = 'Gjem nåler';
        } else {
            document.getElementById('hide_pins_link').innerHTML = 'Hide pins';
        }
    });

}

$(function(){

    set_map_config();

    fixmystreet.map = new OpenLayers.Map("map", {
        controls: fixmystreet.controls,
        displayProjection: new OpenLayers.Projection("EPSG:4326")
    });

    if ($('html').hasClass('mobile') && fixmystreet.page == 'around') {
        $('#fms_pan_zoom').css({ top: '2.75em !important' });
    }

    fixmystreet.layer_options = OpenLayers.Util.extend({
        zoomOffset: fixmystreet.zoomOffset,
        transitionEffect: 'resize',
        numZoomLevels: fixmystreet.numZoomLevels
    }, fixmystreet.layer_options);
    var layer = new fixmystreet.map_type("", fixmystreet.layer_options);
    fixmystreet.map.addLayer(layer);

    if (!fixmystreet.map.getCenter()) {
        var centre = new OpenLayers.LonLat( fixmystreet.longitude, fixmystreet.latitude );
        centre.transform(
            new OpenLayers.Projection("EPSG:4326"),
            fixmystreet.map.getProjectionObject()
        );
        fixmystreet.map.setCenter(centre, fixmystreet.zoom || 3);
    }

    if (fixmystreet.state_map && fixmystreet.state_map == 'full') {
        // TODO Work better with window resizing, this is pretty 'set up' only at present
        var $content = $('.content'),
            q = ( $content.offset().left + $content.width() ) / 2;
        // Need to try and fake the 'centre' being 75% from the left
        fixmystreet.map.pan(-q, -25, { animate: false });
        fixmystreet.map.events.register("movestart", null, function(e){
            fixmystreet.map.moveStart = { zoom: this.getZoom(), center: this.getCenter() };
        });
        fixmystreet.map.events.register("zoomend", null, function(e){
            if ( fixmystreet.map.moveStart && !fixmystreet.map.moveStart.zoom && fixmystreet.map.moveStart.zoom !== 0 ) {
                return true; // getZoom() on Firefox appears to return null at first?
            }
            if ( !fixmystreet.map.moveStart || !this.getCenter().equals(fixmystreet.map.moveStart.center) ) {
                // Centre has moved, e.g. by double-click. Same whether zoom in or out
                fixmystreet.map.pan(-q, -25, { animate: false });
                return;
            }
            var zoom_change = this.getZoom() - fixmystreet.map.moveStart.zoom;
            if (zoom_change == -1) {
                // Zoomed out, need to re'centre'
                fixmystreet.map.pan(-q/2, 0, { animate: false });
            } else if (zoom_change == 1) {
                // Using a zoom button
                fixmystreet.map.pan(q, 0, { animate: false });
            }
        });
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
        $('.mobile-map-banner').text('Place pin on map')
        .prepend('<a href="index.html">home</a>');
        fixmystreet.page = 'around';
    });

    // Vector layers must be added onload as IE sucks
    if ($.browser.msie) {
        $(window).load(fixmystreet_onload);
    } else {
        fixmystreet_onload();
    }
});

/* Overridding the buttonDown function of PanZoom so that it does
   zoomTo(0) rather than zoomToMaxExtent()
*/
OpenLayers.Control.PanZoomFMS = OpenLayers.Class(OpenLayers.Control.PanZoom, {
    buttonDown: function (evt) {
        if (!OpenLayers.Event.isLeftClick(evt)) {
            return;
        }

        switch (this.action) {
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
                this.map.zoomIn();
                break;
            case "zoomout":
                this.map.zoomOut();
                break;
            case "zoomworld":
                this.map.zoomTo(0);
                break;
        }

        OpenLayers.Event.stop(evt);
    }
});

/* Overriding Permalink so that it can pass the correct zoom to OSM */
OpenLayers.Control.PermalinkFMS = OpenLayers.Class(OpenLayers.Control.Permalink, {
    updateLink: function() {
        var separator = this.anchor ? '#' : '?';
        var href = this.base;
        if (href.indexOf(separator) != -1) {
            href = href.substring( 0, href.indexOf(separator) );
        }

        href += separator + OpenLayers.Util.getParameterString(this.createParams(null, this.map.getZoom()+fixmystreet.zoomOffset));
        // Could use mlat/mlon here as well if we are on a page with a marker
        if (this.anchor && !this.element) {
            window.location.href = href;
        }
        else {
            this.element.href = href;
        }
    }
});

/* Pan data handler */
OpenLayers.Format.FixMyStreet = OpenLayers.Class(OpenLayers.Format.JSON, {
    read: function(json, filter) {
        if (typeof json == 'string') {
            obj = OpenLayers.Format.JSON.prototype.read.apply(this, [json, filter]);
        } else {
            obj = json;
        }
        var current, current_near;
        if (typeof(obj.current) != 'undefined' && (current = document.getElementById('current'))) {
            current.innerHTML = obj.current;
        }
        if (typeof(obj.current_near) != 'undefined' && (current_near = document.getElementById('current_near'))) {
            current_near.innerHTML = obj.current_near;
        }
        var markers = fms_markers_list( obj.pins, false );
        return markers;
    },
    CLASS_NAME: "OpenLayers.Format.FixMyStreet"
});

/* Click handler */
OpenLayers.Control.Click = OpenLayers.Class(OpenLayers.Control, {                
    defaultHandlerOptions: {
        'single': true,
        'double': false,
        'pixelTolerance': 0,
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
        fixmystreet_update_pin(lonlat);
        // check to see if markers are visible. We click the
        // link so that it updates the text in case they go
        // back
        if ( ! fixmystreet.markers.getVisibility() ) {
            fixmystreet.state_pins_were_hidden = true;
            $('#hide_pins_link').click();
        }
        if (fixmystreet.page == 'new') {
            return;
        }
        $.getJSON( CONFIG.FMS_URL + 'report/new/ajax', {
                latitude: $('#fixmystreet\\.latitude').val(),
                longitude: $('#fixmystreet\\.longitude').val()
        }, function(data) {
            if (data.error) {
                // XXX If they then click back and click somewhere in the area, this error will still show.
                $('#side-form').html('<h1>Reporting a problem</h1><p>' + data.error + '</p>');
                return;
            }
            $('#councils_text').html(data.councils_text);
            $('#form_category_row').html(data.category);
        });

        $('#side-form, #site-logo').show();
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
                $map_box = $('#map_box'), bo = $map_box.offset();
            // e.xy is relative to top left of map, which might not be top left of page
            e.xy.x += bo.left;
            e.xy.y += bo.top;
            if (e.xy.y <= o.top || (e.xy.x >= o.left && e.xy.x <= o.left + w + 24 && e.xy.y >= o.top && e.xy.y <= o.top + h + 64)) {
                // top of the page, pin hidden by header;
                // or underneath where the new sidebar will appear
                lonlat.transform(
                    new OpenLayers.Projection("EPSG:4326"),
                    fixmystreet.map.getProjectionObject()
                );
                var p = fixmystreet.map.getViewPortPxFromLonLat(lonlat);
                p.x -= ( o.left + w ) / 2;
                lonlat = fixmystreet.map.getLonLatFromViewPortPx(p);
                fixmystreet.map.panTo(lonlat);
            }
        }

        $('#sub_map_links').hide();
        if ($('html').hasClass('mobile')) {
            var $map_box = $('#map_box'),
                width = $map_box.width(),
                height = $map_box.height();
            $map_box.append(
                '<p id="mob_sub_map_links">' +
                '<a href="#" id="try_again">Try again</a>' +
                '<a href="#ok" id="mob_ok">OK</a>' +
                '</p>'
            ).css({ position: 'relative', width: width, height: height, marginBottom: '1em' });
            // Making it relative here makes it much easier to do the scrolling later

            $('.mobile-map-banner').text('Right place?').prepend('<a href="index.html">home</a>');

            // mobile user clicks 'ok' on map
            $('#mob_ok').toggle(function(){
                //scroll the height of the map box instead of the offset
                //of the #side-form or whatever as we will probably want
                //to do this on other pages where #side-form might not be
                $('html, body').animate({ scrollTop: height-60 }, 1000, function(){
                    $('#mob_sub_map_links').addClass('map_complete');
                    $('#mob_ok').text('MAP');
                });
            }, function(){
                $('html, body').animate({ scrollTop: 0 }, 1000, function(){
                    $('#mob_sub_map_links').removeClass('map_complete');
                    $('#mob_ok').text('OK');
                });
            });
        }

        fixmystreet.page = 'new';
        location.hash = 'report';
    }
});

