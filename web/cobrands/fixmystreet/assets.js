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
        $(fixmystreet).on('report_new:category_change', this.changeCategory.bind(this));
        $(fixmystreet).on('report_new:category_change', this.update_layer_visibility.bind(this));
    },

    relevant: function() {
      var category = $('select#form_category').val(),
          group = $('select#category_group').val(),
          layer = this.fixmystreet,
          relevant;
      if (layer.relevant) {
          relevant = layer.relevant({category: category, group: group});
      } else if (layer.asset_group) {
          relevant = (layer.asset_group === group);
      } else {
          relevant = (OpenLayers.Util.indexOf(layer.asset_category, category) != -1);
      }
      return relevant &&
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
        if ( this.fixmystreet.snap_threshold || this.fixmystreet.snap_threshold === 0 ) {
          threshold = this.fixmystreet.snap_threshold;
        }
        var marker = fixmystreet.markers.features[0];
        if (marker === undefined) {
            // No marker to be found so bail out
            return;
        }
        var features = this.getFeaturesWithinDistance(marker.geometry, threshold);
        if (features.length) {
            this.get_select_control().select(features[0]);
        }
    },

    get_select_control: function() {
        var controls = this.controls || [];
        for (var i = 0; i < controls.length; i++) {
            var control = controls[i];
            if (!control.hover) {
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

    // It's possible an asset has been selected before a category (e.g. if
    // assets are showing for a whole category group. So on category change,
    // make sure we check if any attribute fields need setting. We don't
    // clear if not, because that might clear e.g. attributes set by a layer
    // using `usrn`.
    changeCategory: function() {
        if (!fixmystreet.map) {
            return;
        }
        var feature = fixmystreet.assets.selectedFeature();
        if (feature) {
            this.setAttributeFields(feature);
        }
    },

    setAttributeFields: function(feature) {
        if (!this.fixmystreet.attributes) {
            return;
        }
        // Set the extra fields to the value of the selected feature
        $.each(this.fixmystreet.attributes, function(field_name, attribute_name) {
            var $field = $("#form_" + field_name);
            if (typeof attribute_name === 'function') {
                $field.val(attribute_name.apply(feature));
            } else {
                $field.val(feature.attributes[attribute_name]);
            }
        });
    },

    clearAttributeFields: function() {
        if (!this.fixmystreet.attributes) {
            return;
        }
        $.each(this.fixmystreet.attributes, function(field_name, attribute_name) {
            $("#form_" + field_name).val("");
        });
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
            var nearest = this.getFeaturesWithinDistance(point, this.fixmystreet.nearest_radius || 10);
            feature = nearest.length ? nearest[0] : null;
        }
        this.selected_feature = feature;
    },

    updateUSRNField: function() {
        if (this.fixmystreet.usrn) {
            if (!this.fixmystreet.usrn.length) {
                this.fixmystreet.usrn = [this.fixmystreet.usrn];
            }
            for (var i = 0; i < this.fixmystreet.usrn.length; i++) {
                var usrn = this.fixmystreet.usrn[i];
                var selected_usrn;
                if ( this.selected_feature ) {
                    selected_usrn = this.fixmystreet.getUSRN ?
                    this.fixmystreet.getUSRN(this.selected_feature) :
                    this.selected_feature.attributes[usrn.attribute];
                }
                $("input[name=" + usrn.field + "]").val(selected_usrn);
            }
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
    if (layer.fixmystreet.asset_category || layer.fixmystreet.asset_group) {
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

    if (layer.fixmystreet.usrn || layer.fixmystreet.road) {
        // If an asset layer only loads once a category is selected, or if the
        // user visits /report/new directly and doesn't change the pin
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

    // Hide the normal markers layer to keep things simple, but
    // move the green marker to the point of the click to stop
    // it jumping around unexpectedly if the user deselects the asset.
    fixmystreet.markers.setVisibility(false);
    fixmystreet.markers.features[0].move(lonlat);

    // Need to ensure the correct coords are used for the report
    fixmystreet.maps.update_pin(lonlat);

    this.setAttributeFields(feature);

    $(fixmystreet).trigger('assets:selected', [ lonlat ]);

    // Make sure the marker that was clicked is drawn on top of its neighbours
    layer.eraseFeatures([feature]);
    layer.drawFeature(feature);
}

function asset_unselected(e) {
    fixmystreet.markers.setVisibility(true);
    selected_feature = null;
    this.clearAttributeFields();
    $(fixmystreet).trigger('assets:unselected');
}

function check_zoom_message_visibility() {
    if (this.fixmystreet.non_interactive && !this.fixmystreet.display_zoom_message) {
        return;
    }
    var select = this.fixmystreet.asset_group ? 'category_group' : 'form_category';
    var category = $("select#" + select).val() || '',
        prefix = category.replace(/[^a-z]/gi, ''),
        id = "category_meta_message_" + prefix,
        $p = $('#' + id);
    if (this.relevant()) {
        if ($p.length === 0) {
            $p = $("<p>").prop("id", id).prop('class', 'category_meta_message');
            if ($('html').hasClass('mobile')) {
                $p.click(function() {
                    $("#mob_ok").trigger('click');
                }).addClass("btn");
            }
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

    } else if (this.fixmystreet.asset_group) {
        prefix = this.fixmystreet.asset_group.replace(/[^a-z]/gi, '');
        id = "category_meta_message_" + prefix;
        $p = $('#' + id);
        $p.remove();
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
        if (this.fixmystreet.display_zoom_message) {
            check_zoom_message_visibility.call(this);
        }
        return;
    } else if (!this.getVisibility()) {
        asset_unselected.call(this);
        this.asset_not_found(); // as trigger won't call on non-visible layers
    }

    var controls = this.controls || [];
    var j;
    if (this.getVisibility()) {
        for (j = 0; j < controls.length; j++) {
            controls[j].activate();
        }
    } else {
        for (j = 0; j < controls.length; j++) {
            controls[j].deactivate();
        }
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
    return new OpenLayers.StyleMap({
        'default': fixmystreet.assets.style_default,
        'select': fixmystreet.assets.style_default_select,
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

function construct_protocol_options(options) {
    var protocol_options;
    if (options.http_options !== undefined) {
        protocol_options = options.http_options;
        OpenLayers.Util.applyDefaults(options, {
            format_class: OpenLayers.Format.GML.v3,
            format_options: {}
        });
        if (options.geometryName) {
            options.format_options.geometryName = options.geometryName;
        }
        protocol_options.format = new options.format_class(options.format_options);
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
    }
    return protocol_options;
}

function construct_protocol_class(options) {
    if (options.http_options !== undefined) {
        return options.protocol_class || OpenLayers.Protocol.HTTP;
    } else {
        return OpenLayers.Protocol.WFS;
    }
}

function construct_layer_options(options, protocol) {
    var StrategyClass = options.strategy_class || OpenLayers.Strategy.BBOX;

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
        // If minimum resolution not specified, we only want to set a default
        // if max_resolution is specified, otherwise the default minimum will
        // be used to construct all the resolutions and it won't work
        minResolution: options.min_resolution || (max_resolution ? 0.00001 : undefined),
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
        // Add this filter to the layer, so it can potentially be
        // used in the request if non-HTTP WFS
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
        // If using HTTP WFS, add a strategy filter to the layer,
        // to filter the incoming results after being received.
        if (options.http_options) {
            layer_options.strategies.push(new OpenLayers.Strategy.Filter({filter: layer_options.filter}));
        }
    }

    return layer_options;
}

function construct_layer_class(options) {
    var default_class = (options.usrn || options.road) ? OpenLayers.Layer.VectorNearest : OpenLayers.Layer.VectorAsset;

    var layer_class = options.class || default_class;

    return layer_class;
}

function construct_fault_layer(options, protocol_options, layer_options) {
    if (!options.wfs_fault_feature) {
        return null;
    }

    // A non-interactive layer to display existing asset faults
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
    return asset_fault_layer;
}

function construct_asset_layer(options) {
    // An interactive layer for selecting an asset (e.g. street light)
    var protocol_options = construct_protocol_options(options);
    var protocol_class = construct_protocol_class(options);
    var protocol = new protocol_class(protocol_options);

    var layer_options = construct_layer_options(options, protocol);
    var layer_class = construct_layer_class(options);
    var asset_layer = new layer_class(options.name || "WFS", layer_options);

    var asset_fault_layer = construct_fault_layer(options, protocol_options, layer_options);
    if (asset_fault_layer) {
        asset_layer.fixmystreet.fault_layer = asset_fault_layer;
    }

    return asset_layer;
}

function construct_select_layer_events(asset_layer, options) {
    asset_layer.events.register( 'featureselected', asset_layer, asset_selected);
    asset_layer.events.register( 'featureunselected', asset_layer, asset_unselected);

    // When panning/zooming the map check that this layer is still correctly shown
    // and any selected marker is preserved
    asset_layer.events.register( 'loadend', asset_layer, layer_loadend);

    if (options.disable_pin_snapping) {
        // The pin is snapped to the centre of a feature by the select
        // handler. We can stop this handler from running, and the pin
        // being snapped, by returning false from a beforefeatureselected
        // event handler. This handler does need to make sure the
        // attributes of the clicked feature are applied to the extra
        // details form fields first though.
        asset_layer.events.register( 'beforefeatureselected', asset_layer, function(e) {
            var that = this;
            this.setAttributeFields(e.feature);

            // The next click on the map may not be on an asset - so
            // clear the fields for this layer when the pin is next
            // updated. If it is on an asset then the fields will be
            // set by whatever feature was selected.
            $(fixmystreet).one('maps:update_pin', function() {
                that.clearAttributeFields();
            });
            return false;
        });
    }
}

// Set up handler for selecting/unselecting markers
function construct_select_feature_control(asset_layers, options) {
    if (options.non_interactive) {
        return;
    }

    $.each(asset_layers, function(i, layer) {
        construct_select_layer_events(layer, options);
    });

    return new OpenLayers.Control.SelectFeature(asset_layers);
}

function construct_hover_feature_control(asset_layers, options) {
    // Even if an asset layer is marked as non-interactive it can still have
    // a hover style which we'll need to set up.
    if (options.non_interactive && !(options.stylemap && options.stylemap.styles.hover)) {
        return;
    }

    // Set up handlers for simply hovering over an asset marker
    var hover_feature_control = new OpenLayers.Control.SelectFeature(
        asset_layers,
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
    return hover_feature_control;
}

// fixmystreet.pin_prefix isn't always available here, due
// to file loading order, so get it from the DOM directly.
var map_data = document.getElementById('js-map-data');
var pin_prefix = fixmystreet.pin_prefix || (map_data ? map_data.getAttribute('data-pin_prefix') : '/i/');

fixmystreet.assets = {
    layers: [],
    controls: [],

    stylemap_invisible: new OpenLayers.StyleMap({
        'default': new OpenLayers.Style({
            fill: false,
            stroke: false
        })
    }),

    style_default: new OpenLayers.Style({
        fillColor: "#FFFF00",
        fillOpacity: 0.6,
        strokeColor: "#000000",
        strokeOpacity: 0.8,
        strokeWidth: 2,
        pointRadius: 6
    }),

    style_default_select: new OpenLayers.Style({
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

    selectedFeature: function() {
        return selected_feature;
    },

    add: function(default_options, options) {
        if (!document.getElementById('map')) {
            return;
        }

        options = $.extend(true, {}, default_options, options);
        var asset_layer = this.add_layer(options);
        this.add_controls([asset_layer], options);
        return asset_layer;
    },

    add_layer: function(options) {
        // Upgrade `asset_category` to an array, in the case that this layer is
        // only associated with a single category.
        if (options.asset_category && !OpenLayers.Util.isArray(options.asset_category)) {
            options.asset_category = [ options.asset_category ];
        }

        var asset_layer = construct_asset_layer(options);

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
        return asset_layer;
    },

    add_controls: function(asset_layers, options) {
        var select_feature_control = construct_select_feature_control(asset_layers, options);
        var hover_feature_control = construct_hover_feature_control(asset_layers, options);

        $.each(asset_layers, function(i, asset_layer) {
            asset_layer.controls = asset_layer.controls || [];
            if (hover_feature_control) {
                asset_layer.controls.push(hover_feature_control);
            }
            if (select_feature_control) {
                asset_layer.controls.push(select_feature_control);
            }
        });
    },

    init: function() {
        if (fixmystreet.page != 'new' && fixmystreet.page != 'around') {
            // We only want to show asset markers when making a new report
            return;
        }

        if (!fixmystreet.map) {
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
            var asset_layer = fixmystreet.assets.layers[i];
            var controls = asset_layer.controls || [];
            for (var j = 0; j < controls.length; j++) {
                fixmystreet.map.addControl(controls[j]);
            }
            init_asset_layer(asset_layer, pins_layer);
        }
    }
};

$(function() {
    fixmystreet.assets.init();
});

OpenLayers.Geometry.MultiPolygon.prototype.containsPoint = function(point) {
    var numPolygons = this.components.length;
    var contained = false;
    for(var i=0; i<numPolygons; ++i) {
        polygon = this.components[i].containsPoint(point);
        if (polygon) {
            contained = polygon;
            break;
        }
    }
    return contained;
};

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
 * Returns all features from this layer within a given distance (<threshold>
 * metres) of the given OpenLayers.Geometry.Point sorted by their distance
 * from the pin.
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
            candidate.distance = distance_m;
            features.push(candidate);
        }
    }
    features.sort(function(a,b) { return a.distance - b.distance; });
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
        do_not_send = fixmystreet.utils.csv_to_array(do_not_send)[0];
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

/*
Handling of the form-top messaging: This handles categories that hide the form
and show a message, and categories where assets must be selected or the pin
must be on a road, taking into account Highways England roads.
*/

fixmystreet.message_controller = (function() {
    var stopperId = 'js-category-stopper',
        stoppers = [],
        ignored_bodies = [];
        msg_after_bodies = [];

    // This shows an error message because e.g. an asset isn't selected or a road hasn't been clicked
    function show_responsibility_error(id, asset_item, asset_type) {
        $("#js-roads-responsibility").removeClass("hidden");
        $("#js-roads-responsibility .js-responsibility-message").addClass("hidden");
        var asset_strings = $(id).find('.js-roads-asset');
        if (asset_item) {
            asset_strings.html('a <b class="asset-' + asset_type + '">' + asset_item + '</b>');
        } else {
            asset_strings.html(asset_strings.data('original'));
        }
        $('.js-update-coordinates').attr('href', function(i, href) {
            if (href.indexOf('?') != -1) {
                href = href.substring(0, href.indexOf('?'));
            }
            href += '?' + OpenLayers.Util.getParameterString({
                latitude: $('#fixmystreet\\.latitude').val(),
                longitude: $('#fixmystreet\\.longitude').val()
            });
            return href;
        });
        $(id).removeClass("hidden");
    }

    // This hides the asset/road not found message
    function hide_responsibility_errors() {
        $("#js-roads-responsibility").addClass("hidden");
        $("#js-roads-responsibility .js-responsibility-message").addClass("hidden");
    }

    // This shows the reporting form
    function enable_report_form() {
        $(".js-hide-if-invalid-category").show();
        $(".js-hide-if-invalid-category_extras").show();
    }

    // This hides the reporting form, apart from the category selection
    // And perhaps the category_extras unless asked not to
    function disable_report_form(keep_category_extras) {
        $(".js-hide-if-invalid-category").hide();
        if (!keep_category_extras) {
            $(".js-hide-if-invalid-category_extras").hide();
        }
    }

    // This hides the responsibility message, and (unless a
    // stopper message or dupes are shown) reenables the report form
    function responsibility_off() {
        hide_responsibility_errors();
        if (!document.getElementById(stopperId) && !$('#js-duplicate-reports').is(':visible')) {
            enable_report_form();
        }
    }

    // This disables the report form and (unless a stopper
    // message is shown) shows a responsibility message
    function responsibility_on(id, asset_item, asset_type) {
        disable_report_form();
        hide_responsibility_errors();
        if (!document.getElementById(stopperId)) {
            show_responsibility_error(id, asset_item, asset_type);
        }
    }

    function is_only_body(body) {
        if (fixmystreet.bodies && fixmystreet.bodies.length == 1 && fixmystreet.bodies[0] == body) {
            return true;
        }
        return false;
    }

    function is_matching_stopper(stopper, i) {
        var body = $('#form_category').data('body');

        if (OpenLayers.Util.indexOf(ignored_bodies, body) > -1) {
            return false;
        }

        var category = $('#form_category').val();
        if (category != stopper.category) {
            return false;
        }

        if (stopper.answers) {
            var answer = $('#form_' + stopper.code).val();
            if (OpenLayers.Util.indexOf(stopper.answers, answer) > -1) {
                return true;
            }
            return false;
        } else {
            return true;
        }
    }

    function stopper_after(stopper) {
        var body =  fixmystreet.bodies[0];
        if (OpenLayers.Util.indexOf( msg_after_bodies, body) > -1 ) {
            return true;
        }
        return false;
    }

    function check_for_stopper() {
        var only_send = fixmystreet.body_overrides.get_only_send();
        if (only_send == 'Highways England') {
            // If we're sending to Highways England, this message doesn't matter
            return;
        }

        var $id = $('#' + stopperId);
        var matching = $.grep(stoppers, is_matching_stopper);
        if (!matching.length) {
            $id.remove();
            if ( !$('#js-roads-responsibility').is(':visible') && !$('#js-duplicate-reports').is(':visible') ) {
                enable_report_form();
            }
            return;
        }

        var stopper = matching[0]; // Assume only one match possible at present
        var $msg;
        if (typeof stopper.message === 'function') {
            $msg = stopper.message();
        } else {
            $msg = $('<div class="box-warning">' + stopper.message + '</div>');
        }
        $msg.attr('id', stopperId);
        $msg.attr('role', 'alert');
        $msg.attr('aria-live', 'assertive');

        if ($id.length) {
            $id.replaceWith($msg);
        } else {
            if (stopper_after(stopper)) {
                $msg.insertAfter('#js-post-category-messages');
            } else {
                $msg.insertBefore('#js-post-category-messages');
            }
            $msg[0].scrollIntoView();
        }
        disable_report_form(stopper.keep_category_extras);
    }

    $(fixmystreet).on('report_new:category_change', check_for_stopper);

    return {
        asset_found: function() {
            responsibility_off();
            return ($('#' + stopperId).length);
        },

        asset_not_found: function() {
            if (!this.visibility) {
                responsibility_off();
            } else {
                responsibility_on('#js-not-an-asset', this.fixmystreet.asset_item, this.fixmystreet.asset_type);
            }
        },

        // A road was found; if some roads should still cause disabling/message,
        // then you should pass in a criterion function to test the found feature,
        // plus an ID of the message to be shown
        road_found: function(layer, feature, criterion, msg_id) {
            if (fixmystreet.assets.selectedFeature()) {
                responsibility_off();
            } else if (!criterion || criterion(feature)) {
                responsibility_off();
            } else {
                fixmystreet.body_overrides.do_not_send(layer.fixmystreet.body);
                if (is_only_body(layer.fixmystreet.body)) {
                    responsibility_on(msg_id);
                }
            }
        },

        // If a feature wasn't found at the location they've clicked, it's
        // probably a field or something. Show an error to that effect,
        // unless an asset is selected.
        road_not_found: function(layer) {
            // don't show the message if clicking on a highways england road
            if (fixmystreet.body_overrides.get_only_send() == 'Highways England' || !layer.visibility) {
                responsibility_off();
            } else if (fixmystreet.assets.selectedFeature()) {
                fixmystreet.body_overrides.allow_send(layer.fixmystreet.body);
                responsibility_off();
            } else if (is_only_body(layer.fixmystreet.body)) {
                responsibility_on(layer.fixmystreet.no_asset_msg_id, layer.fixmystreet.asset_item, layer.fixmystreet.asset_type);
            }
        },

        register_category: function(params) {
            stoppers.push(params);
        },

        unregister_all_categories: function() {
            stoppers = [];
        },

        check_for_stopper: check_for_stopper,

        add_ignored_body: function(body) {
            ignored_bodies.push(body);
        },

        add_msg_after_bodies: function(body) {
            msg_after_bodies.push(body);
        }
    };

})();
