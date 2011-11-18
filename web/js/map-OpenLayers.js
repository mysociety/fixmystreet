$(function(){

    var perm = new OpenLayers.Control.Permalink();
    set_map_config(perm);

    fixmystreet.map = new OpenLayers.Map("map", {
        controls: fixmystreet.controls,
        displayProjection: new OpenLayers.Projection("EPSG:4326")
    });

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

    if (document.getElementById('mapForm')) {
        var click = new OpenLayers.Control.Click();
        fixmystreet.map.addControl(click);
        click.activate();
    }

    /* To let permalink not be caught by the Click layer, answer found
     * at http://www.mail-archive.com/users@openlayers.org/msg12958.html
     * Not sure why you can't use eventListeners or events.register...
     */
    OpenLayers.Event.observe( perm.element, "click", function(e) {
        OpenLayers.Event.stop(e);
        location.href = OpenLayers.Event.element(e).href;
        return false;
    });

    $(window).hashchange(function(){
        if (location.hash) return;
        // Okay, back to around view.
        fixmystreet.bbox_strategy.activate();
        fixmystreet.markers.refresh( { force: true } );
        fixmystreet.drag.deactivate();
        $('#side-form').hide();
        $('#side').show();
        $('#sub_map_links').show();
        fixmystreet.page = 'around';
    });

    // Vector layers must be added onload as IE sucks
    if ($.browser.msie) {
        $(window).load(fixmystreet_onload);
    } else {
        fixmystreet_onload();
    }
});

function fixmystreet_onload() {
    if ( fixmystreet.area ) {
        var area = new OpenLayers.Layer.Vector("KML", {
            strategies: [ new OpenLayers.Strategy.Fixed() ],
            protocol: new OpenLayers.Protocol.HTTP({
                url: "/mapit/area/" + fixmystreet.area + ".kml?simplify_tolerance=0.0001",
                format: new OpenLayers.Format.KML()
            })
        });
        fixmystreet.map.addLayer(area);
        area.events.register('loadend', null, function(a,b,c) {
            var bounds = area.getDataExtent();
            if (bounds) { fixmystreet.map.zoomToExtent( bounds ); }
        });
    }

    var pin_layer_options = {
        styleMap: new OpenLayers.StyleMap({
            'default': new OpenLayers.Style({
                externalGraphic: "/i/pin${type}.gif",
                graphicTitle: "${title}",
                graphicWidth: 32,
                graphicHeight: 59,
                graphicOpacity: 1,
                graphicXOffset: -2,
                graphicYOffset: -59
            })
        })
    };
    if (fixmystreet.page == 'around') {
        fixmystreet.bbox_strategy = new OpenLayers.Strategy.BBOX();
        pin_layer_options.strategies = [ fixmystreet.bbox_strategy ];
        pin_layer_options.protocol = new OpenLayers.Protocol.HTTP({
            url: '/ajax',
            params: fixmystreet.all_pins ? { all_pins: 1 } : { },
            format: new OpenLayers.Format.FixMyStreet()
        });
    }
    fixmystreet.markers = new OpenLayers.Layer.Vector("Pins", pin_layer_options);

    var markers = fms_markers_list( fixmystreet.pins, true );
    fixmystreet.markers.addFeatures( markers );
    if (fixmystreet.page == 'around' || fixmystreet.page == 'reports' || fixmystreet.page == 'my') {
        fixmystreet.markers.events.register( 'featureselected', fixmystreet.markers, function(evt) {
            if (evt.feature.attributes.id) {
                window.location = '/report/' + evt.feature.attributes.id;
            }
            OpenLayers.Event.stop(evt);
        });
        var select = new OpenLayers.Control.SelectFeature( fixmystreet.markers );
        fixmystreet.map.addControl( select );
        select.activate();
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
                this.innerHTML = showhide[i+1];
            } else if (this.innerHTML == showhide[i+1]) {
                fixmystreet.markers.setVisibility(false);
                this.innerHTML = showhide[i];
            }
        }
    });

    $('#all_pins_link').click(function(e) {
        e.preventDefault();
        fixmystreet.markers.setVisibility(true);
        var texts = [
            'en', 'Include stale reports', 'Hide stale reports',
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

function fms_markers_list(pins, transform) {
    var cols = { 'red':'R', 'green':'G', 'blue':'B', 'purple':'P' };
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
            type: cols[pin[2]],
            id: pin[3],
            title: pin[4]
        });
        markers.push( marker );
    }
    return markers;
}

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
        if (typeof(obj.current) != 'undefined')
            document.getElementById('current').innerHTML = obj.current;
        if (typeof(obj.current_near) != 'undefined')
            document.getElementById('current_near').innerHTML = obj.current_near;
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
            {}, this.defaultHandlerOptions
        );
        OpenLayers.Control.prototype.initialize.apply(
            this, arguments
        ); 
        this.handler = new OpenLayers.Handler.Click(
            this, {
                'click': this.trigger
            }, this.handlerOptions
        );
    }, 

    trigger: function(e) {
        var lonlat = fixmystreet.map.getLonLatFromViewPortPx(e.xy);
        if (fixmystreet.page == 'new') {
            /* Already have a purple pin */
            fixmystreet.markers.features[0].move(lonlat);
        } else {
            var markers = fms_markers_list( [ [ lonlat.lat, lonlat.lon, 'purple' ] ], false );
            fixmystreet.bbox_strategy.deactivate();
            fixmystreet.markers.removeAllFeatures();
            fixmystreet.markers.addFeatures( markers );
            fixmystreet_activate_drag();
        }
        fixmystreet_update_pin(lonlat);
        if (fixmystreet.page == 'new') {
            return;
        }
        $.getJSON('/report/new/ajax', {
                latitude: $('#fixmystreet\\.latitude').val(),
                longitude: $('#fixmystreet\\.longitude').val()
        }, function(data) {
            $('#councils_text').html(data.councils_text);
            $('#form_category_row').html(data.category);
            /* Need to reset this here as it gets removed when we replace
               the HTML for the dropdown */
            if ( data.has_open311 > 0 ) {
                $('#form_category').change( form_category_onchange );
            }
        });
        $('#side-form').show();
        $('#side').hide();
        $('#sub_map_links').hide();
        fixmystreet.page = 'new';
        location.hash = 'report';
    }
});

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

