var fixmystreet = fixmystreet || {};

(function(){
    // Retrieves the latitude/longitude from <inputs>
    // on the page and returns it as a LonLat in the
    // same projection as the map.
    fixmystreet.get_lonlat_from_dom = function() {
        var lonlat = new OpenLayers.LonLat(
            $('input[name="longitude"]').val(),
            $('input[name="latitude"]').val()
        );
        return lonlat.clone().transform(
            new OpenLayers.Projection("EPSG:4326"),
            fixmystreet.map.getProjectionObject()
        );
    };
})();

OpenLayers.Layer.VectorAsset = OpenLayers.Class(OpenLayers.Layer.Vector, {
    initialize: function(name, options) {
        OpenLayers.Layer.Vector.prototype.initialize.apply(this, arguments);
        // Update layer based upon new data from category change
        $(fixmystreet).on('assets:selected', this.checkSelected.bind(this));
        $(fixmystreet).on('assets:unselected', this.checkSelected.bind(this));
        $(fixmystreet).on('report_new:category_change', this.update_layer_visibility.bind(this));
    },

    relevant: function() {
      var category = $('select#form_category').val(),
          layer = this.fixmystreet;
      return OpenLayers.Util.indexOf(layer.asset_category, category) != -1 &&
        ( !layer.body || OpenLayers.Util.indexOf(fixmystreet.bodies, layer.body) != -1 );
    },

    update_layer_visibility: function() {
        if (!fixmystreet.map) {
          return;
        }

        if (!this.fixmystreet.always_visible) {
            // Show/hide the asset layer when the category is chosen
            if (this.relevant()) {
                this.setVisibility(true);
                if (this.fixmystreet.fault_layer) {
                    this.fixmystreet.fault_layer.setVisibility(true);
                }
                this.zoom_to_assets();
            } else {
                this.setVisibility(false);
                if (this.fixmystreet.fault_layer) {
                    this.fixmystreet.fault_layer.setVisibility(false);
                }
            }
        } else {
            if (this.fixmystreet.body) {
                this.setVisibility(OpenLayers.Util.indexOf(fixmystreet.bodies, this.fixmystreet.body) != -1 );
            }
        }
    },

    select_nearest_asset: function() {
        // The user's green marker might be on the map the first time we show the
        // assets, so snap it to the closest asset marker if so.
        if (!fixmystreet.markers.getVisibility() || !(this.getVisibility() && this.inRange)) {
            return;
        }
        var threshold = 50; // metres
        var marker = fixmystreet.markers.features[0];
        if (marker === undefined) {
            // No marker to be found so bail out
            return;
        }
        var nearest_feature = this.getNearestFeature(marker.geometry, threshold);
        if (nearest_feature) {
            this.get_select_control().select(nearest_feature);
        }
    },

    get_select_control: function() {
        var controls = fixmystreet.map.getControlsByClass('OpenLayers.Control.SelectFeature');
        for (var i=0; i<controls.length; i++) {
            var control = controls[i];
            if (control.layer == this && !control.hover) {
                return control;
            }
        }
    },

    zoom_to_assets: function() {
        // This function is called when the asset category is
        // selected, and will zoom the map in to the first level that
        // makes the asset layer visible if it's not already shown.
        if (!this.inRange && this.resolutions) {
            var firstVisibleResolution = this.resolutions[0];
            var zoomLevel = fixmystreet.map.getZoomForResolution(firstVisibleResolution);
            fixmystreet.map.zoomTo(zoomLevel);
        }
    },

    checkSelected: function(evt, lonlat) {
        if (!this.getVisibility()) {
          return;
        }
        if (this.fixmystreet.select_action) {
            if (fixmystreet.assets.selectedFeature()) {
                this.asset_found();
            } else {
                this.asset_not_found();
            }
        }
    },

    asset_found: function() {
        if (this.fixmystreet.actions) {
            this.fixmystreet.actions.asset_found.call(this, fixmystreet.assets.selectedFeature());
        }
    },

    asset_not_found: function() {
        if (this.fixmystreet.actions) {
            this.fixmystreet.actions.asset_not_found.call(this);
        }
    },

    assets_have_same_id: function(f1, f2) {
        var asset_id_field = this.fixmystreet.asset_id_field;
        return (f1.attributes[asset_id_field] == f2.attributes[asset_id_field]);
    },

    find_matching_feature: function(feature, layer) {
        if (!layer) {
            return false;
        }
        // When the WFS layer is reloaded the same features might be visible
        // but they'll be different instances of the class so we can't use
        // object identity comparisons.
        // This function will find the best matching feature based on its
        // attributes and distance from the original feature.
        var threshold = 1; // metres
        for (var i = 0; i < layer.features.length; i++) {
            var candidate = layer.features[i];
            var distance = candidate.geometry.distanceTo(feature.geometry);
            if (this.assets_have_same_id(feature, candidate) && distance <= threshold) {
                return candidate;
            }
        }
    },

    CLASS_NAME: 'OpenLayers.Layer.VectorAsset'
});

// Handles layers such as USRN, TfL roads, and the like
OpenLayers.Layer.VectorNearest = OpenLayers.Class(OpenLayers.Layer.VectorAsset, {
    selected_feature: null,

    initialize: function(name, options) {
        OpenLayers.Layer.VectorAsset.prototype.initialize.apply(this, arguments);
        $(fixmystreet).on('maps:update_pin', this.checkFeature.bind(this));
        $(fixmystreet).on('assets:selected', this.checkFeature.bind(this));
        // Update fields/etc from data now available from category change
        $(fixmystreet).on('report_new:category_change', this.changeCategory.bind(this));
    },

    checkFeature: function(evt, lonlat) {
        if (!this.getVisibility()) {
          return;
        }
        this.getNearest(lonlat);
        this.updateUSRNField();
        if (this.fixmystreet.road) {
            var valid_category = this.fixmystreet.all_categories || (this.fixmystreet.asset_category && this.relevant());
            if (!valid_category || !this.selected_feature) {
                this.road_not_found();
            } else {
                this.road_found();
            }
        }
    },

    getNearest: function(lonlat) {
        var point = new OpenLayers.Geometry.Point(lonlat.lon, lonlat.lat);
        var feature = this.getFeatureAtPoint(point);
        if (feature == null) {
            // The click wasn't directly over a road, try and find one nearby
            feature = this.getNearestFeature(point, this.fixmystreet.nearest_radius || 10);
        }
        this.selected_feature = feature;
    },

    updateUSRNField: function() {
        if (this.fixmystreet.usrn) {
            var usrn_field = this.fixmystreet.usrn.field;
            var selected_usrn;
            if ( this.selected_feature ) {
                selected_usrn = this.fixmystreet.getUSRN ?
                    this.fixmystreet.getUSRN(this.selected_feature) :
                    this.selected_feature.attributes[this.fixmystreet.usrn.attribute];
            }
            $("input[name=" + usrn_field + "]").val(selected_usrn);
        }
    },

    changeCategory: function() {
        if (!fixmystreet.map) {
            // Sometimes the category change event is fired before the map has
            // initialised, for example when visiting /report/new directly
            // on a cobrand with category groups enabled.
            return;
        }
        this.checkFeature(null, fixmystreet.get_lonlat_from_dom());
    },

    one_time_select: function() {
        // This function takes the current report lat/lon from hidden input
        // fields and uses that to look up a USRN from the USRN layer.
        // It's registered as an event handler by init_asset_layer below,
        // and is only intended to run the once (because if the user drags the
        // pin the usual USRN lookup event handler is run) so unregisters itself
        // immediately.
        this.events.unregister( 'loadend', this, this.one_time_select );
        this.checkFeature(null, fixmystreet.get_lonlat_from_dom());
    },

    road_found: function() {
        if (this.fixmystreet.actions && this.fixmystreet.actions.found) {
            this.fixmystreet.actions.found(this, this.selected_feature);
        } else if (!fixmystreet.assets.selectedFeature()) {
            fixmystreet.body_overrides.only_send(this.fixmystreet.body);
        }
    },

    road_not_found: function() {
        if (this.fixmystreet.actions && this.fixmystreet.actions.not_found) {
            this.fixmystreet.actions.not_found(this);
        } else {
            fixmystreet.body_overrides.remove_only_send();
        }
    },

    CLASS_NAME: 'OpenLayers.Layer.VectorNearest'
});

(function(){

var selected_feature = null;
var fault_popup = null;

/*
 * Adds the layer to the map and sets up event handlers and whatnot.
 * Called as part of fixmystreet.assets.init for each asset layer on the map.
 */
function init_asset_layer(layer, pins_layer) {
    layer.update_layer_visibility();
    fixmystreet.map.addLayer(layer);
    if (layer.fixmystreet.asset_category) {
        fixmystreet.map.events.register( 'zoomend', layer, check_zoom_message_visibility);
    }

    // Don't cover the existing pins layer
    if (pins_layer) {
        layer.setZIndex(pins_layer.getZIndex()-1);
    }

    // Make sure the fault markers always appear beneath the linked assets
    if (layer.fixmystreet.fault_layer) {
        fixmystreet.map.addLayer(layer.fixmystreet.fault_layer);
        layer.fixmystreet.fault_layer.setZIndex(layer.getZIndex()-1);
    }

    if (fixmystreet.page == 'new' && (layer.fixmystreet.usrn || layer.fixmystreet.road)) {
        // If the user visits /report/new directly and doesn't change the pin
        // location, then the assets:selected/maps:update_pin events are never
        // fired and USRN's checkFeature is never called. This results in a
        // report whose location was never looked up against the USRN layer,
        // which can cause issues for Open311 endpoints that require a USRN
        // value.
        // To prevent this situation we register an event handler that looks up
        // the new report's lat/lon against the USRN layer, calls usrn.select
        // and then unregisters itself.
        layer.events.register( 'loadend', layer, layer.one_time_select );
    }

}

function close_fault_popup() {
    if (!!fault_popup) {
        fixmystreet.map.removePopup(fault_popup);
        fault_popup.destroy();
        fault_popup = null;
    }
}

function asset_selected(e) {
    close_fault_popup();
    var lonlat = e.feature.geometry.getBounds().getCenterLonLat();

    var layer = e.feature.layer;
    var feature = e.feature;

    // Check if there is a known fault with the asset that's been clicked,
    // and disallow selection if so.
    var fault_feature = layer.find_matching_feature(feature, this.fixmystreet.fault_layer);
    if (!!fault_feature) {
        fault_popup = new OpenLayers.Popup.FramedCloud("popup",
            e.feature.geometry.getBounds().getCenterLonLat(),
            null,
            "This fault (" + e.feature.attributes[this.fixmystreet.asset_id_field] + ")<br />has been reported.",
            { size: new OpenLayers.Size(0, 0), offset: new OpenLayers.Pixel(0, 0) },
            true, close_fault_popup);
        fixmystreet.map.addPopup(fault_popup);
        this.get_select_control().unselect(e.feature);
        return;
    }

    // Keep track of selection in case layer is reloaded or hidden etc.
    selected_feature = feature.clone();

    // Pick up the USRN for the location of this asset. NB we do this *before*
    // handling the attributes on the selected feature in case the feature has
    // its own USRN which should take precedence.
    $(fixmystreet).trigger('assets:selected', [ lonlat ]);

    if (this.fixmystreet.attributes) {
        set_fields_from_attributes(this.fixmystreet.attributes, feature);
    }

    // Hide the normal markers layer to keep things simple, but
    // move the green marker to the point of the click to stop
    // it jumping around unexpectedly if the user deselects the asset.
    fixmystreet.markers.setVisibility(false);
    fixmystreet.markers.features[0].move(lonlat);

    // Need to ensure the correct coords are used for the report
    fixmystreet.maps.update_pin(lonlat);

    // Make sure the marker that was clicked is drawn on top of its neighbours
    layer.eraseFeatures([feature]);
    layer.drawFeature(feature);
}

function asset_unselected(e) {
    fixmystreet.markers.setVisibility(true);
    selected_feature = null;
    if (this.fixmystreet.attributes) {
        clear_fields_for_attributes(this.fixmystreet.attributes);
    }
    $(fixmystreet).trigger('assets:unselected');
}

function set_fields_from_attributes(attributes, feature) {
    // Set the extra fields to the value of the selected feature
    $.each(attributes, function (field_name, attribute_name) {
        var $field = $("#form_" + field_name);
        if (typeof attribute_name === 'function') {
            $field.val(attribute_name.apply(feature));
        } else {
            $field.val(feature.attributes[attribute_name]);
        }
    });
}

function clear_fields_for_attributes(attributes) {
    $.each(attributes, function (field_name, attribute_name) {
        $("#form_" + field_name).val("");
    });
}

function check_zoom_message_visibility() {
    if (this.fixmystreet.non_interactive) {
        return;
    }
    var category = $("select#form_category").val(),
        prefix = category.replace(/[^a-z]/gi, ''),
        id = "category_meta_message_" + prefix,
        $p = $('#' + id);
    if (this.relevant()) {
        if ($p.length === 0) {
            $p = $("<p>").prop("id", id).prop('class', 'category_meta_message');
            $p.prependTo('#js-post-category-messages');
        }

        if (this.getVisibility() && this.inRange) {
            if (typeof this.fixmystreet.asset_item_message !== 'undefined') {
                $p.html(this.fixmystreet.asset_item_message);
            } else {
                $p.html('You can pick a <b class="asset-' + this.fixmystreet.asset_type + '">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
            }
        } else {
            $p.html('Zoom in to pick a ' + this.fixmystreet.asset_item + ' from the map');
        }

    } else {
        $.each(this.fixmystreet.asset_category, function(i, c) {
            var prefix = c.replace(/[^a-z]/gi, ''),
                id = "category_meta_message_" + prefix,
                $p = $('#' + id);
            $p.remove();
        });
    }
}

function layer_visibilitychanged() {
    if (this.fixmystreet.road) {
        if (!this.getVisibility()) {
            this.road_not_found();
        }
        return;
    } else if (!this.getVisibility()) {
        this.asset_not_found();
    }

    check_zoom_message_visibility.call(this);
    var layers = fixmystreet.map.getLayersBy('assets', true);
    var visible = 0;
    for (var i = 0; i<layers.length; i++) {
        if (!layers[i].fixmystreet.always_visible && layers[i].getVisibility()) {
            visible++;
        }
    }
    if (visible === 2 || visible === 0) {
        // We're either switching WFS layers (so going 1->2->1 or 1->0->1)
        // or switching off WFS layer (so going 1->0). Either way, we want
        // to show the marker again.
        fixmystreet.markers.setVisibility(true);
    }
    if (!this.fixmystreet.non_interactive) {
        this.select_nearest_asset();
    }
}


function layer_loadend() {
    this.select_nearest_asset();
    // Preserve the selected marker when panning/zooming, if it's still on the map
    if (selected_feature !== null) {
        // Can't use (selected_feature in this.selectedFeatures) as it's a clone
        var found = false;
        for (var i=0; i < this.selectedFeatures.length; i++) {
            if (this.assets_have_same_id(selected_feature, this.selectedFeatures[i])) {
                found = true;
                break;
            }
        }
        if (!found) {
            var replacement_feature = this.find_matching_feature(selected_feature, this);
            if (!!replacement_feature) {
                this.get_select_control().select(replacement_feature);
            }
        }
    }
}

function get_asset_stylemap() {
    // fixmystreet.pin_prefix isn't always available here (e.g. on /report/new),
    // so get it from the DOM directly
    var pin_prefix = fixmystreet.pin_prefix || document.getElementById('js-map-data').getAttribute('data-pin_prefix');

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
            externalGraphic: pin_prefix + "pin-spot.png",
            fillColor: "#55BB00",
            graphicWidth: 48,
            graphicHeight: 64,
            graphicXOffset: -24,
            graphicYOffset: -56,
            backgroundGraphic: pin_prefix + "pin-shadow.png",
            backgroundWidth: 60,
            backgroundHeight: 30,
            backgroundXOffset: -7,
            backgroundYOffset: -22,
            popupYOffset: -40,
            graphicOpacity: 1.0
        }),
        'hover': new OpenLayers.Style({
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

fixmystreet.assets = {
    layers: [],
    controls: [],

    selectedFeature: function() {
        return selected_feature;
    },

    add: function(options) {
        var asset_fault_layer = null;

        // An interactive layer for selecting an asset (e.g. street light)
        var protocol_options;
        var protocol;
        if (options.http_options !== undefined) {
            protocol_options = options.http_options;
            OpenLayers.Util.applyDefaults(options, {
                format_class: OpenLayers.Format.GML,
                format_options: {}
            });
            if (options.geometryName) {
                options.format_options.geometryName = options.geometryName;
            }
            protocol_options.format = new options.format_class(options.format_options);
            var protocol_class = options.protocol_class || OpenLayers.Protocol.HTTP;
            protocol = new protocol_class(protocol_options);
        } else {
            protocol_options = {
                version: "1.1.0",
                url: options.wfs_url,
                featureType: options.wfs_feature,
                geometryName: options.geometryName
            };
            if (options.srsName !== undefined) {
                protocol_options.srsName = options.srsName;
            } else if (fixmystreet.wmts_config) {
                protocol_options.srsName = fixmystreet.wmts_config.map_projection;
            }
            if (options.propertyNames) {
                protocol_options.propertyNames = options.propertyNames;
            }
            protocol = new OpenLayers.Protocol.WFS(protocol_options);
        }
        var StrategyClass = options.strategy_class || OpenLayers.Strategy.BBOX;

        // Upgrade `asset_category` to an array, in the case that this layer is
        // only associated with a single category.
        if (options.asset_category && !OpenLayers.Util.isArray(options.asset_category)) {
            options.asset_category = [ options.asset_category ];
        }

        var max_resolution = options.max_resolution;
        if (typeof max_resolution === 'object') {
            max_resolution = max_resolution[fixmystreet.cobrand];
        }

        var layer_options = {
            fixmystreet: options,
            strategies: [new StrategyClass()],
            protocol: protocol,
            visibility: false,
            maxResolution: max_resolution,
            minResolution: options.min_resolution,
            styleMap: options.stylemap || get_asset_stylemap(),
            assets: true
        };
        if (options.attribution !== undefined) {
            layer_options.attribution = options.attribution;
        }
        if (options.srsName !== undefined) {
            layer_options.projection = new OpenLayers.Projection(options.srsName);
        } else if (fixmystreet.wmts_config) {
            layer_options.projection = new OpenLayers.Projection(fixmystreet.wmts_config.map_projection);
        }
        if (options.filter_key) {
            // Add this filter to the layer, so it can potentially be used
            // in the request (though only Bristol currently does this).
            if (OpenLayers.Util.isArray(options.filter_value)) {
                layer_options.filter = new OpenLayers.Filter.Logical({
                    type: OpenLayers.Filter.Logical.OR,
                    filters: $.map(options.filter_value, function(value) {
                        return new OpenLayers.Filter.Comparison({
                            type: OpenLayers.Filter.Comparison.EQUAL_TO,
                            property: options.filter_key,
                            value: value
                        });
                    })
                });
            } else if (typeof options.filter_value === 'function') {
                layer_options.filter = new OpenLayers.Filter.FeatureId({
                    type: OpenLayers.Filter.Function,
                    evaluate: options.filter_value
                });
            } else {
                layer_options.filter = new OpenLayers.Filter.Comparison({
                    type: OpenLayers.Filter.Comparison.EQUAL_TO,
                    property: options.filter_key,
                    value: options.filter_value
                });
            }
            // Add a strategy filter to the layer, to filter the incoming results
            // after they are received. Bristol does not need this, but has to ask
            // for the filter data in its response so it doesn't then disappear.
            layer_options.strategies.push(new OpenLayers.Strategy.Filter({filter: layer_options.filter}));
        }

        var layer_class = options.class || OpenLayers.Layer.VectorAsset;
        if (options.usrn || options.road) {
            layer_class = OpenLayers.Layer.VectorNearest;
        }
        var asset_layer = new layer_class(options.name || "WFS", layer_options);

        // A non-interactive layer to display existing asset faults
        if (options.wfs_fault_feature) {
            var po = {
                featureType: options.wfs_fault_feature
            };
            OpenLayers.Util.applyDefaults(po, protocol_options);
            var fault_protocol = new OpenLayers.Protocol.WFS(po);
            var lo = {
                strategies: [new OpenLayers.Strategy.BBOX()],
                protocol: fault_protocol,
                styleMap: get_fault_stylemap(),
                assets: true
            };
            OpenLayers.Util.applyDefaults(lo, layer_options);
            asset_fault_layer = new OpenLayers.Layer.Vector("WFS", lo);
            asset_fault_layer.events.register( 'loadstart', null, fixmystreet.maps.loading_spinner.show);
            asset_fault_layer.events.register( 'loadend', null, fixmystreet.maps.loading_spinner.hide);
            asset_layer.fixmystreet.fault_layer = asset_fault_layer;
        }

        var hover_feature_control, select_feature_control;
        if (!options.non_interactive) {
            // Set up handlers for selecting/unselecting markers
            select_feature_control = new OpenLayers.Control.SelectFeature( asset_layer );
            asset_layer.events.register( 'featureselected', asset_layer, asset_selected);
            asset_layer.events.register( 'featureunselected', asset_layer, asset_unselected);
            if (options.disable_pin_snapping) {
                // The pin is snapped to the centre of a feature by the select
                // handler. We can stop this handler from running, and the pin
                // being snapped, by returning false from a beforefeatureselected
                // event handler. This handler does need to make sure the
                // attributes of the clicked feature are applied to the extra
                // details form fields first though.
                asset_layer.events.register( 'beforefeatureselected', asset_layer, function(e) {
                    var attributes = this.fixmystreet.attributes;
                    if (attributes) {
                        set_fields_from_attributes(attributes, e.feature);
                    }

                    // The next click on the map may not be on an asset - so
                    // clear the fields for this layer when the pin is next
                    // updated. If it is on an asset then the fields will be
                    // set by whatever feature was selected.
                    $(fixmystreet).one('maps:update_pin', function() {
                        if (attributes) {
                            clear_fields_for_attributes(attributes);
                        }
                    });
                    return false;
                });
            }
            // When panning/zooming the map check that this layer is still correctly shown
            // and any selected marker is preserved
            asset_layer.events.register( 'loadend', asset_layer, layer_loadend);
        }

        // Even if an asset layer is marked as non-interactive it can still have
        // a hover style which we'll need to set up.
        if (!options.non_interactive || (options.stylemap && options.stylemap.styles.hover)) {
            // Set up handlers for simply hovering over an asset marker
            hover_feature_control = new OpenLayers.Control.SelectFeature(
                asset_layer,
                {
                    hover: true,
                    highlightOnly: true,
                    renderIntent: 'hover'
                }
            );
            hover_feature_control.events.register('beforefeaturehighlighted', null, function(e) {
                // Don't let marker go from selected->hover state,
                // as it causes some mad flickering effect.
                if (e.feature.renderIntent == 'select') {
                    return false;
                }
            });
        }

        if (!options.always_visible || options.road) {
            asset_layer.events.register( 'visibilitychanged', asset_layer, layer_visibilitychanged);
        }

        // Make sure the user knows something is happening (some asset layers can be sllooowwww)
        asset_layer.events.register( 'loadstart', null, fixmystreet.maps.loading_spinner.show);
        asset_layer.events.register( 'loadend', null, fixmystreet.maps.loading_spinner.hide);

        fixmystreet.assets.layers.push(asset_layer);
        if (options.always_visible) {
            asset_layer.setVisibility(true);
        }
        if (hover_feature_control) {
            fixmystreet.assets.controls.push(hover_feature_control);
        }
        if (select_feature_control) {
            fixmystreet.assets.controls.push(select_feature_control);
        }
    },

    init: function() {
        if (fixmystreet.page != 'new' && fixmystreet.page != 'around') {
            // We only want to show asset markers when making a new report
            return;
        }

        // Make sure the assets get hidden if the back button is pressed
        fixmystreet.maps.display_around = (function(original) {
            function hide_assets() {
                for (var i = 0; i < fixmystreet.assets.layers.length; i++) {
                    var layer = fixmystreet.assets.layers[i];
                    if (!layer.fixmystreet.always_visible) {
                        layer.setVisibility(false);
                    }
                }
                fixmystreet.markers.setVisibility(true);
                original.apply(fixmystreet.maps);
            }
            return hide_assets;
        })(fixmystreet.maps.display_around);

        var pins_layer = fixmystreet.map.getLayersByName("Pins")[0];
        for (var i = 0; i < fixmystreet.assets.layers.length; i++) {
            init_asset_layer(fixmystreet.assets.layers[i], pins_layer);
        }

        for (i = 0; i < fixmystreet.assets.controls.length; i++) {
            fixmystreet.map.addControl(fixmystreet.assets.controls[i]);
            fixmystreet.assets.controls[i].activate();
        }
    }
};

$(function() {
    fixmystreet.assets.init();
});

OpenLayers.Layer.Vector.prototype.getFeatureAtPoint = function(point) {
    for (var i = 0; i < this.features.length; i++) {
        var feature = this.features[i];
        if (!feature.geometry || !feature.geometry.containsPoint) {
            continue;
        }
        if (feature.geometry.containsPoint(point)) {
            return feature;
        }
    }
    return null;
};


/*
 * Returns this layer's feature that's closest to the given
 * OpenLayers.Geometry.Point, as long as it's within <threshold> metres.
 * Returns null if no feature meeting these criteria is found.
 */
OpenLayers.Layer.Vector.prototype.getNearestFeature = function(point, threshold) {
    var nearest_feature = null;
    var nearest_distance = null;
    for (var i = 0; i < this.features.length; i++) {
        var candidate = this.features[i];
        if (!candidate.geometry || !candidate.geometry.distanceTo) {
            continue;
        }
        var details = candidate.geometry.distanceTo(point, {details: true});
        if (nearest_distance === null || details.distance < nearest_distance) {
            nearest_distance = details.distance;
            // The units used for details.distance aren't metres, they're
            // whatever the map projection uses. Convert to metres in order to
            // draw a meaningful comparison to the threshold value.
            var p1 = new OpenLayers.Geometry.Point(details.x0, details.y0);
            var p2 = new OpenLayers.Geometry.Point(details.x1, details.y1);
            var line = new OpenLayers.Geometry.LineString([p1, p2]);
            var distance_m = line.getGeodesicLength(this.map.getProjectionObject());

            if (distance_m <= threshold) {
                nearest_feature = candidate;
            }
        }
    }
    return nearest_feature;
};


/*
 * Returns all features from this layer within a given distance (<threshold>
 * metres) of the given OpenLayers.Geometry.Point.
 * Returns an empty list if no features meeting these criteria is found.
 */
OpenLayers.Layer.Vector.prototype.getFeaturesWithinDistance = function(point, threshold) {
    var features = [];
    for (var i = 0; i < this.features.length; i++) {
        var candidate = this.features[i];
        if (!candidate.geometry || !candidate.geometry.distanceTo) {
            continue;
        }
        var details = candidate.geometry.distanceTo(point, {details: true});
        // The units used for details.distance aren't metres, they're
        // whatever the map projection uses. Convert to metres in order to
        // draw a meaningful comparison to the threshold value.
        var p1 = new OpenLayers.Geometry.Point(details.x0, details.y0);
        var p2 = new OpenLayers.Geometry.Point(details.x1, details.y1);
        var line = new OpenLayers.Geometry.LineString([p1, p2]);
        var distance_m = line.getGeodesicLength(this.map.getProjectionObject());
        if (distance_m <= threshold) {
            features.push(candidate);
        }
    }
    return features;
};


/*
 * MapServer 6 (the version available on Debian Wheezy) outputs incorrect
 * GML for MultiCurve geometries - see https://github.com/mapserver/mapserver/issues/4924
 * The end result is that features with 'curveMembers' elements in their
 * geometries will be missing from the map as the default GML parser doesn't
 * know how to handle these elements.
 * This subclass works around the problem by parsing 'curveMembers' elements.
 */
OpenLayers.Format.GML.v3.MultiCurveFix = OpenLayers.Class(OpenLayers.Format.GML.v3, {
    readers: $.extend(true, {}, OpenLayers.Format.GML.v3.prototype.readers, {
        "gml": {
            "curveMembers": function(node, obj) {
                this.readChildNodes(node, obj);
            }
        }
    }),

    CLASS_NAME: "OpenLayers.Format.GML.v3.MultiCurveFix"
});

OpenLayers.Request.XMLHttpRequest.prototype.setRequestHeader = function(sName, sValue) {
    if (sName.toLowerCase() == 'x-requested-with') {
        return;
    }
    if (!this._headers) {
        this._headers = {};
    }
    this._headers[sName] = sValue;
    return this._object.setRequestHeader(sName, sValue);
};
})();

/* Handling of body override functionality */

fixmystreet.body_overrides = (function(){

var do_not_send = [];
var only_send = '';

function update() {
    $('#do_not_send').val(fixmystreet.utils.array_to_csv_line(do_not_send));
    $('#single_body_only').val(only_send);
    $(fixmystreet).trigger('body_overrides:change');
}

return {
    clear: function() {
        do_not_send = [];
        update();
    },
    only_send: function(body) {
        only_send = body;
        update();
    },
    remove_only_send: function() {
        only_send = '';
        update();
    },
    do_not_send: function(body) {
        do_not_send.push(body);
        update();
    },
    allow_send: function(body) {
        do_not_send = $.grep(do_not_send, function(a) { return a !== body; });
        update();
    },
    get_only_send: function() {
      return only_send;
    }
};

})();

$(fixmystreet).on('body_overrides:change', function() {
    var single_body_only = $('#single_body_only').val(),
        do_not_send = $('#do_not_send').val(),
        bodies = fixmystreet.bodies;

    if (single_body_only) {
        bodies = [ single_body_only ];
    }

    if (do_not_send) {
        do_not_send = fixmystreet.utils.csv_to_array(do_not_send);
        var lookup = {};
        $.map(do_not_send, function(val) {
            lookup[val] = 1;
        });
        bodies = OpenLayers.Array.filter(bodies, function(b) {
            return !lookup[b];
        });
    }

    fixmystreet.update_public_councils_text(
        $('#js-councils_text').html(), bodies);
});
