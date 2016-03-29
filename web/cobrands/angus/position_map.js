// Wrap custom functionality up in a closure to keep scopes tidy
var add_streetlights = (function() {
    var wfs_url = "https://data.angus.gov.uk/geoserver/services/wfs";
    var wfs_feature = "lighting_column_v";
    var wfs_fault_feature = "lighting_faults_v";
    var streetlight_category = "Street lighting";
    var max_resolution = 2.388657133579254;
    var min_resolution = 0.5971642833948135;

    var streetlight_layer = null;
    var streetlight_fault_layer = null;
    var select_feature_control;
    var hover_feature_control;
    var selected_feature = null;
    var fault_popup = null;

    function close_fault_popup() {
        if (!!fault_popup) {
            fixmystreet.map.removePopup(fault_popup);
            fault_popup.destroy();
            fault_popup = null;
        }
    }

    function streetlight_selected(e) {
        close_fault_popup();
        var lonlat = e.feature.geometry.getBounds().getCenterLonLat();

        // Check if there is a known fault with the light that's been clicked,
        // and disallow selection if so.
        var fault_feature = find_matching_feature(e.feature, streetlight_fault_layer);
        if (!!fault_feature) {
            fault_popup = new OpenLayers.Popup.FramedCloud("popup",
                e.feature.geometry.getBounds().getCenterLonLat(),
                null,
                "This fault (" + e.feature.attributes.n + ")<br />has been reported.",
                { size: new OpenLayers.Size(0, 0), offset: new OpenLayers.Pixel(0, 0) },
                true, close_fault_popup);
            fixmystreet.map.addPopup(fault_popup);
            select_feature_control.unselect(e.feature);
            return;
        }

        // Set the 'column id' extra field to the value of the light that was clicked
        var column_id = e.feature.attributes.n;
        $("#form_column_id").val(column_id);

        // Hide the normal markers layer to keep things simple, but
        // move the green marker to the point of the click to stop
        // it jumping around unexpectedly if the user deselects street light.
        fixmystreet.markers.setVisibility(false);
        fixmystreet.markers.features[0].move(lonlat);

        // Need to ensure the correct coords are used for the report
        // We can't call fixmystreet_update_pin because that refreshes the category list,
        // clobbering the value we stored in the #form_column_id field.
        lonlat.transform(
            fixmystreet.map.getProjectionObject(),
            new OpenLayers.Projection("EPSG:4326")
        );
        document.getElementById('fixmystreet.latitude').value = lonlat.lat || lonlat.y;
        document.getElementById('fixmystreet.longitude').value = lonlat.lon || lonlat.x;

        // Make sure the marker that was clicked is drawn on top of its neighbours
        var layer = e.feature.layer;
        var feature = e.feature;
        layer.eraseFeatures([feature]);
        layer.drawFeature(feature);

        // Keep track of selection in case layer is reloaded or hidden etc.
        selected_feature = feature.clone();
    }

    function streetlight_unselected(e) {
        fixmystreet.markers.setVisibility(true);
        $("#form_column_id").val("");
        selected_feature = null;
    }

    function find_matching_feature(feature, layer) {
        // When the WFS layer is reloaded the same features might be visible
        // but they'll be different instances of the class so we can't use
        // object identity comparisons.
        // This function will find the best matching feature based on its
        // attributes and distance from the original feature.
        var threshold = 1; // metres
        for (var i = 0; i < layer.features.length; i++) {
            var candidate = layer.features[i];
            var distance = candidate.geometry.distanceTo(feature.geometry);
            if (candidate.attributes.n == feature.attributes.n && distance <= threshold) {
                return candidate;
            }
        }
    }

    function check_zoom_message_visiblity() {
        var category = $("#problem_form select#form_category").val();
        if (category == streetlight_category) {
            var $p = $("#category_meta_message");

            if ($p.length === 0) {
                $p = $("<p>").prop("id", "category_meta_message");
                // #category_meta might not be here yet, but that's OK as the
                // element simply won't be added to the DOM.
                $p.insertAfter("#category_meta");
            }

            if (streetlight_layer.getVisibility() && streetlight_layer.inRange) {
                $p.html('Or pick a <b class="streetlight-spot">street light</b> from the map &raquo;');
            } else {
                $p.html('Or zoom in and pick a street light from the map');
            }

        } else {
            $("#category_meta_message").remove();
        }
    }

    function layer_visibilitychanged() {
        check_zoom_message_visiblity();
        select_nearest_streetlight();
    }

    function zoom_to_streetlights() {
        // This function is called when the street lighting category is
        // selected, and will zoom the map in to the first level that
        // makes the street light layer visible if it's not already shown.
        if (!streetlight_layer.inRange) {
            var firstVisibleResolution = streetlight_layer.resolutions[0];
            var zoomLevel = fixmystreet.map.getZoomForResolution(firstVisibleResolution);
            fixmystreet.map.zoomTo(zoomLevel);
        }
    }

    function select_nearest_streetlight() {
        // The user's green marker might be on the map the first time we show the
        // streetlights, so snap it to the closest streetlight marker if so.
        if (!fixmystreet.markers.getVisibility() || !(streetlight_layer.getVisibility() && streetlight_layer.inRange)) {
            return;
        }
        var threshold = 50; // metres
        var marker = fixmystreet.markers.features[0];
        if (marker === undefined) {
            // No marker to be found so bail out
            return;
        }
        var closest_feature;
        var closest_distance = null;
        for (var i = 0; i < streetlight_layer.features.length; i++) {
            var candidate = streetlight_layer.features[i];
            var distance = candidate.geometry.distanceTo(marker.geometry);
            if (closest_distance === null || distance < closest_distance) {
                closest_feature = candidate;
                closest_distance = distance;
            }
        }
        if (closest_distance <= threshold && !!closest_feature) {
            select_feature_control.select(closest_feature);
        }
    }

    function layer_loadend(e) {
        select_nearest_streetlight();
        // Preserve the selected marker when panning/zooming, if it's still on the map
        if (selected_feature !== null && !(selected_feature in this.selectedFeatures)) {
            var replacement_feature = find_matching_feature(selected_feature, streetlight_layer);
            if (!!replacement_feature) {
                select_feature_control.select(replacement_feature);
            }
        }
    }

    function get_streetlight_stylemap() {
        return new OpenLayers.StyleMap({
            'default': new OpenLayers.Style({
                fillColor: "#FFFF00",
                fillOpacity: 0.6,
                strokeColor: "#000000",
                strokeOpacity: 0.8,
                strokeWidth: 2,
                pointRadius: 6
            }),
            'select': new OpenLayers.Style({
                externalGraphic: fixmystreet.pin_prefix + "pin-spot.png",
                graphicWidth: 48,
                graphicHeight: 64,
                graphicXOffset: -24,
                graphicYOffset: -56,
                backgroundGraphic: fixmystreet.pin_prefix + "pin-shadow.png",
                backgroundWidth: 60,
                backgroundHeight: 30,
                backgroundXOffset: -7,
                backgroundYOffset: -22,
                popupYOffset: -40,
                graphicOpacity: 1.0
            }),
            'temporary': new OpenLayers.Style({
                fillColor: "#55BB00",
                fillOpacity: 0.8,
                strokeColor: "#000000",
                strokeOpacity: 1,
                strokeWidth: 2,
                pointRadius: 8,
                cursor: 'pointer'
            })
        });
    }

    function get_fault_stylemap() {
        return new OpenLayers.StyleMap({
            'default': new OpenLayers.Style({
                fillColor: "#FF6600",
                fillOpacity: 1,
                strokeColor: "#FF6600",
                strokeOpacity: 1,
                strokeWidth: 1.25,
                pointRadius: 8
            })
        });
    }

    function add_streetlights() {
        if (streetlight_layer !== null) {
            // Layer has already been added
            return;
        }
        if (window.fixmystreet === undefined) {
            // We're on a page without a map, yet somehow still got called...
            // Nothing to do.
            return;
        }
        if (fixmystreet.map === undefined) {
            // Map's not loaded yet, let's try again soon...
            setTimeout(add_streetlights, 250);
            return;
        }
        if (fixmystreet.page != 'new' && fixmystreet.page != 'around') {
            // We only want to show light markers when making a new report
            return;
        }

        // An interactive layer for selecting a street light
        var protocol = new OpenLayers.Protocol.WFS({
            version: "1.1.0",
            url:  wfs_url,
            featureType: wfs_feature,
            geometryName: "g"
        });
        streetlight_layer = new OpenLayers.Layer.Vector("WFS", {
            strategies: [new OpenLayers.Strategy.BBOX()],
            protocol: protocol,
            visibility: false,
            maxResolution: max_resolution,
            minResolution: min_resolution,
            styleMap: get_streetlight_stylemap()
        });
        fixmystreet.streetlight_layer = streetlight_layer;

        // A non-interactive layer to display existing street light faults
        var fault_protocol = new OpenLayers.Protocol.WFS({
            version: "1.1.0",
            url:  wfs_url,
            featureType: wfs_fault_feature,
            geometryName: "g"
        });
        streetlight_fault_layer = new OpenLayers.Layer.Vector("WFS", {
            strategies: [new OpenLayers.Strategy.BBOX()],
            protocol: fault_protocol,
            visibility: false,
            maxResolution: max_resolution,
            minResolution: min_resolution,
            styleMap: get_fault_stylemap()
        });

        // Set up handlers for selecting/unselecting markers and panning/zooming the map
        select_feature_control = new OpenLayers.Control.SelectFeature( streetlight_layer );
        streetlight_layer.events.register( 'featureselected', streetlight_layer, streetlight_selected);
        streetlight_layer.events.register( 'featureunselected', streetlight_layer, streetlight_unselected);
        streetlight_layer.events.register( 'loadend', streetlight_layer, layer_loadend);
        streetlight_layer.events.register( 'visibilitychanged', streetlight_layer, layer_visibilitychanged);
        fixmystreet.map.events.register( 'zoomend', streetlight_layer, check_zoom_message_visiblity);
        // Set up handlers for simply hovering over a street light marker
        hover_feature_control = new OpenLayers.Control.SelectFeature(
            streetlight_layer,
            {
                hover: true,
                highlightOnly: true,
                renderIntent: 'temporary'
            }
        );
        hover_feature_control.events.register('beforefeaturehighlighted', null, function(e) {
            // Don't let marker go from selected->hover state,
            // as it causes some mad flickering effect.
            if (e.feature.renderIntent == 'select') {
                return false;
            }
        });

        fixmystreet.map.addLayer(streetlight_layer);
        fixmystreet.map.addLayer(streetlight_fault_layer);
        fixmystreet.map.addControl( hover_feature_control );
        hover_feature_control.activate();
        fixmystreet.map.addControl( select_feature_control );
        select_feature_control.activate();

        // Make sure the fault markers always appear beneath the street lights
        streetlight_fault_layer.setZIndex(streetlight_layer.getZIndex()-1);

        // Show/hide the streetlight layer when the category is chosen
        $("#problem_form").on("change.category", "select#form_category", function(){
            var category = $(this).val();
            if (category == streetlight_category) {
                streetlight_layer.setVisibility(true);
                streetlight_fault_layer.setVisibility(true);
                zoom_to_streetlights();
            } else {
                streetlight_layer.setVisibility(false);
                streetlight_fault_layer.setVisibility(false);
            }
        });

        // Make sure the streetlights get hidden if the back button is pressed
        $(window).on('hashchange', function() {
            if (location.hash === '') {
                streetlight_layer.setVisibility(false);
                streetlight_fault_layer.setVisibility(false);
                fixmystreet.markers.setVisibility(true);
                fixmystreet.bbox_strategy.activate();
                fixmystreet.markers.refresh( { force: true } );
            }
        });
    }
    return add_streetlights;
})();

function position_map_box() {
    var $html = $('html');
    if ($html.hasClass('ie6')) {
        $('#map_box').prependTo('body').css({
            zIndex: 0, position: 'absolute',
            top: 0, left: 0, right: 0, bottom: 0,
            width: '100%', height: $(window).height(),
            margin: 0
        });
    } else {
        $('#map_box').prependTo('body').css({
            zIndex: 0, position: 'fixed',
            top: 0, left: 0, right: 0, bottom: 0,
            width: '100%', height: '100%',
            margin: 0
        });
    }
    add_streetlights();
}

function map_fix() {}
var slide_wards_down = 0;
