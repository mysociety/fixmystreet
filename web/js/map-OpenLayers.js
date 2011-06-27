YAHOO.util.Event.onContentReady('map', function() {

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

    fixmystreet.markers = new OpenLayers.Layer.Markers("Markers");
    var cols = { 'red':'R', 'green':'G', 'blue':'B', 'purple':'P' };
    for (var i=0; i<fixmystreet.pins.length; i++) {
        var pin = fixmystreet.pins[i];
        var src = '/i/pin' + cols[pin[2]] + '.gif';
        var size = new OpenLayers.Size(32, 59);
        var offset = new OpenLayers.Pixel(-3, -size.h-2);
        var icon = new OpenLayers.Icon(src, size, offset);
        var loc = new OpenLayers.LonLat(pin[1], pin[0]);
        loc.transform(
            new OpenLayers.Projection("EPSG:4326"),
            fixmystreet.map.getProjectionObject()
        );
        var marker = new OpenLayers.Marker(loc, icon);
        if (pin[3]) {
            marker.id = pin[3];
            marker.events.register('click', marker, function(evt) {
                window.location = '/report/' + this.id;
                OpenLayers.Event.stop(evt);
            });
        }
        fixmystreet.markers.addMarker(marker);
    }
    fixmystreet.map.addLayer(fixmystreet.markers);

});

YAHOO.util.Event.addListener('hide_pins_link', 'click', function(e) {
    YAHOO.util.Event.preventDefault(e);
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

        href += separator + OpenLayers.Util.getParameterString(this.createParams(null, this.map.getZoom()+fixmystreet.ZOOM_OFFSET));
        if (this.anchor && !this.element) {
            window.location.href = href;
        }
        else {
            this.element.href = href;
        }
    }
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
        lonlat.transform(
            fixmystreet.map.getProjectionObject(),
            new OpenLayers.Projection("EPSG:4326")
        );
        document.getElementById('fixmystreet.latitude').value = lonlat.lat;
        document.getElementById('fixmystreet.longitude').value = lonlat.lon;
        document.getElementById('mapForm').submit();
    }
});

