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

OpenLayers.Layer.VectorBase = OpenLayers.Class(OpenLayers.Layer.Vector, {
    initialize: function(name, options) {
        OpenLayers.Layer.Vector.prototype.initialize.apply(this, arguments);
        // Update layer based upon new data from category change
        $(fixmystreet).on('assets:unselected', this.checkSelected.bind(this));
        $(fixmystreet).on('report_new:category_change', this.update_layer_visibility.bind(this));
        $(fixmystreet).on('inspect_form:asset_change', this.update_layer_visibility.bind(this));
    },

    relevant: function(category, group) {
      var selected = fixmystreet.reporting.selectedCategory();
      group = group || $('#inspect_category_group').val() || selected.group || '';
      category = category || $('#inspect_form_category').val() || selected.category || '';
      var layer = this.fixmystreet,
          relevant;
      if (layer.relevant) {
          relevant = layer.relevant({category: category, group: group});
      } else if (layer.asset_group) {
          // Check both group and category because e.g. Isle of Wight has
          // layers attached with groups that should also apply to categories
          // with the same name
          relevant = (OpenLayers.Util.indexOf(layer.asset_group, group) != -1 || OpenLayers.Util.indexOf(layer.asset_group, category) != -1);
      }
      // if not already relevant, check asset_category next. Doing this independently
      // of asset_group allows config to specific both asset_group and asset_category
      // and layer will be relevant if either match.
      if (!relevant && layer.asset_category) {
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
                this.zoom_to_assets();
            } else {
                this.setVisibility(false);
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
        if ( this.fixmystreet.snap_threshold || this.fixmystreet.snap_threshold === "0" ) {
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
            if (window.selected_problem_id) {
                var feature = fixmystreet.maps.get_marker_by_id(window.selected_problem_id);
                var center = feature.geometry.getBounds().getCenterLonLat();
                fixmystreet.map.setCenter(center, zoomLevel);
            } else {
                fixmystreet.map.zoomTo(zoomLevel);
            }
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
        if (!this.getVisibility()) {
          return;
        }
        var feature = fixmystreet.assets.selectedFeature();
        if (feature) {
            this.setAttributeFields(feature);
        }
    },

    setAttributeFields: function(feature, no_action) {
        if (!this.fixmystreet.attributes) {
            return;
        }
        // If we have a select layer with multiple asset layers, it is possible
        // on category change that we get called on one asset layer with a
        // selected asset from another layer. We do not want to confuse this.
        if (this !== feature.layer) {
            return;
        }
        // Set the extra fields to the value of the selected feature
        var $mobile_display = $('#change_asset_mobile').text('');
        $.each(this.fixmystreet.attributes, function(field_name, attribute_name) {
            var $field = $("#form_" + field_name);
            var $inspect_fields = $('[id^=category_][id$=form_' + field_name + ']');
            var value;
            if (typeof attribute_name === 'function') {
                value = attribute_name.apply(feature);
            } else {
                value = feature.attributes[attribute_name];
            }
            $field.val(value);
            $inspect_fields.val(value);
            $mobile_display.append(field_name + ': ' + value + '<br>');
        });

        if (!no_action && this.fixmystreet.actions && this.fixmystreet.actions.attribute_set) {
            this.fixmystreet.actions.attribute_set.call(this, feature);
        }
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
        if (fixmystreet.assets.selectedFeature()) {
            this.asset_found();
        } else {
            this.asset_not_found();
        }
    },

    asset_found: function() {
        if (this.fixmystreet.actions && this.fixmystreet.actions.asset_found) {
            this.fixmystreet.actions.asset_found.call(this, fixmystreet.assets.selectedFeature());
        }
    },

    asset_not_found: function() {
        if (this.fixmystreet.actions && this.fixmystreet.actions.asset_not_found) {
            this.fixmystreet.actions.asset_not_found.call(this);
        }
    },

    assets_have_same_id: function(f1, f2) {
        var asset_id_field = this.fixmystreet.asset_id_field;
        return (f1.attributes[asset_id_field] == f2.attributes[asset_id_field]);
    },

    construct_selected_asset_message: function(asset) {
        var id = asset.attributes[this.fixmystreet.feature_code] || '';
        if (id === '') {
            return;
        }
        var data = { id: id, name: this.fixmystreet.asset_item };
        if (this.fixmystreet.construct_asset_name) {
            data = this.fixmystreet.construct_asset_name(id) || data;
        }
        return 'You have selected ' + data.name + ' <b>' + data.id + '</b>';
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

    CLASS_NAME: 'OpenLayers.Layer.VectorBase'
});

/* For some reason the changeCategory event does not work if only present in Asset,
 * but then fires twice on the right function if included in Nearest. So split the
 * addition of this event into both classes */

OpenLayers.Layer.VectorAsset = OpenLayers.Class(OpenLayers.Layer.VectorBase, {
    initialize: function(name, options) {
        OpenLayers.Layer.VectorBase.prototype.initialize.apply(this, arguments);
        $(fixmystreet).on('assets:selected', this.checkSelected.bind(this));
        $(fixmystreet).on('report_new:category_change', this.changeCategory.bind(this));
    },
    CLASS_NAME: 'OpenLayers.Layer.VectorAsset'
});

// This is required so that the found/not found actions are fired on category
// select and pin move rather than just on asset select/not select.
OpenLayers.Layer.VectorAssetMove = OpenLayers.Class(OpenLayers.Layer.VectorBase, {
    initialize: function(name, options) {
        OpenLayers.Layer.VectorBase.prototype.initialize.apply(this, arguments);
        $(fixmystreet).on('maps:update_pin', this.checkSelected.bind(this));
        $(fixmystreet).on('report_new:category_change', this.changeCategory.bind(this));
        $(fixmystreet).on('report_new:category_change', this.checkSelected.bind(this));
    },

    CLASS_NAME: 'OpenLayers.Layer.VectorAssetMove'
});

// Handles layers such as USRN, TfL roads, and the like
OpenLayers.Layer.VectorNearest = OpenLayers.Class(OpenLayers.Layer.VectorBase, {
    selected_feature: null,

    initialize: function(name, options) {
        OpenLayers.Layer.VectorBase.prototype.initialize.apply(this, arguments);
        $(fixmystreet).on('assets:selected', this.checkSelected.bind(this));
        $(fixmystreet).on('maps:update_pin', this.checkFeature.bind(this));
        $(fixmystreet).on('report_new:category_change', this.changeCategory.bind(this));
    },

    checkFeature: function(evt, lonlat) {
        if (!this.getVisibility()) {
          return;
        }
        this.getNearest(lonlat);
        this.updateUSRNField();
        if (this.fixmystreet.road) {
            var valid_category = this.fixmystreet.always_visible || ((this.fixmystreet.asset_category || this.fixmystreet.asset_group) && this.relevant());
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
            var nearest = this.getFeaturesWithinDistance(point, parseFloat(this.fixmystreet.nearest_radius) || 10);
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

/*
 * Adds the layer to the map and sets up event handlers and whatnot.
 * Called as part of fixmystreet.assets.init for each asset layer on the map.
 */
function init_asset_layer(layer, pins_layer) {
    layer.update_layer_visibility();
    if (layer.fixmystreet.asset_category || layer.fixmystreet.asset_group) {
        fixmystreet.map.events.register( 'zoomend', layer, check_zoom_message_visibility);
    }

    // Don't cover the existing pins layer
    if (pins_layer) {
        layer.setZIndex(pins_layer.getZIndex()-1);
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

function asset_selected(e) {
    var lonlat = e.feature.geometry.getBounds().getCenterLonLat();

    var layer = e.feature.layer;
    var feature = e.feature;

    // Keep track of selection in case layer is reloaded or hidden etc.
    selected_feature = feature.clone();
    selected_feature.layer = feature.layer;

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
    if (selected_feature && selected_feature.layer !== this) {
        // The selected feature has already changed to something in a different
        // layer, so we don't want to mess that up by clearing it
        return;
    }
    fixmystreet.markers.setVisibility(true);
    selected_feature = null;
    this.clearAttributeFields();
    $(fixmystreet).trigger('assets:unselected');
}

function check_zoom_message_visibility() {
    if (this.fixmystreet.non_interactive && !this.fixmystreet.display_zoom_message) {
        return;
    }
    if (this.relevant()) {
        if (this.getVisibility() && $('html').hasClass('mobile')) {
            fixmystreet.pageController.addMapPage(this);
        }

        if (this.getVisibility() && this.inRange) {
            delete this.map_messaging.zoom;
            this.map_messaging.asset = get_asset_pick_message.call(this);
        } else {
            delete this.map_messaging.asset;
            this.map_messaging.zoom = 'Zoom in to pick a ' + this.fixmystreet.asset_item + ' from the map';
        }
    } else {
        delete this.map_messaging.zoom;
        delete this.map_messaging.asset;
        $('#' + this.id + '_map').remove();
    }
}

function get_asset_pick_message() {
    var message;
    if (typeof this.fixmystreet.asset_item_message !== 'undefined') {
        message = this.fixmystreet.asset_item_message;
        message = message.replace(/ITEM/g, this.fixmystreet.asset_item);
    } else {
        message = 'You can pick a <b class="asset-' + this.fixmystreet.asset_type + '">' + this.fixmystreet.asset_item + '</b> from the map &raquo;';
    }
    return message;
}

var lastVisible = 0;

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
        var ctl = this.get_select_control();
        if (ctl) {
            ctl.unselectAll();
        }
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
        // Deactivating 2 controls means the pin layer z-index ends up being 1 too high...?
        fixmystreet.map.resetLayersZIndex();
    }

    check_zoom_message_visibility.call(this);
    var layers = fixmystreet.map.getLayersBy('assets', true);
    var visible = 0;
    for (var i = 0; i<layers.length; i++) {
        if (!layers[i].fixmystreet.always_visible && layers[i].getVisibility()) {
            visible++;
        }
    }
    if (visible === 0 || visible > lastVisible) {
        // We're either switching WFS layers (so going 1->2->1 or 1->0->1 or
        // even 1->2->3->2) or switching off WFS layer (so going 1->0).
        // Whichever way, we want to show the marker again.
        fixmystreet.markers.setVisibility(true);
    }
    lastVisible = visible;
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
        'hover': fixmystreet.assets.style_default_hover
    });
}

function construct_protocol_options(options) {
    var protocol_options;
    if (options.http_wfs_url) {
        var srsname = options.srsName.replace(':', '::');
        options.http_options = {
            url: options.http_wfs_url,
            params: {
                SERVICE: "WFS",
                VERSION: "1.1.0",
                REQUEST: "GetFeature",
                SRSNAME: "urn:ogc:def:crs:" + srsname,
                TYPENAME: options.wfs_feature
            }
        };
        if (options.propertyNames) {
            options.http_options.params.propertyName = options.propertyNames.join(',');
        }
    }
    if (options.http_options !== undefined) {
        protocol_options = options.http_options;
        OpenLayers.Util.applyDefaults(options, {
            format_class: OpenLayers.Format.GML.v3,
            format_options: {}
        });
        /* Set this to the right namespace if you have multiple feature types
         * being returned, as otherwise only one will be parsed */
        if (options.wfs_feature_ns) {
            options.format_options.featureNS = options.wfs_feature_ns;
            options.format_options.featureType = options.wfs_feature;
        }
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
    var StrategyClass = options.strategy_class || OpenLayers.Strategy.FixMyStreet;

    var max_resolution = options.max_resolution;
    if (typeof max_resolution === 'object') {
        max_resolution = parseFloat(max_resolution[fixmystreet.cobrand]);
    } else {
        max_resolution = parseFloat(max_resolution);
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

    if (options.filter) {
        layer_options.filter = options.filter;
    } else if (options.filter_key) {
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
    }

    // If using HTTP WFS, add a strategy filter to the layer,
    // to filter the incoming results after being received.
    if (layer_options.filter && options.http_options) {
        layer_options.strategies.push(new OpenLayers.Strategy.Filter({filter: layer_options.filter}));
    }

    return layer_options;
}

function construct_layer_class(options) {
    var default_class = (options.usrn || options.road) ? OpenLayers.Layer.VectorNearest : OpenLayers.Layer.VectorAsset;

    var layer_class = options.class || default_class;

    return layer_class;
}

function update_floating_button_messaging(layer, messaging) {
    var id = 'js-responsibility-message-' + layer.id;
    var message = messaging.zoom || (layer.fixmystreet.asset_message_when_disabled ? messaging.asset : messaging.responsibility || messaging.asset);
    var obj = $('#' + id);
    if (message) {
        var $div = $('<div id="' + id + '" class="js-floating-button-message"></div>').html(message);
        if (obj.length) {
            obj.replaceWith($div);
        } else {
            if ($('html').hasClass('mobile') && !layer.fixmystreet.asset_message_immediate) {
                $div.appendTo('#map_box');
            } else {
                $div.appendTo('.js-reporting-page--active .pre-button-messaging');
            }
        }
        if (messaging.responsibility) {
            $div.addClass('js-not-an-asset');
        } else {
            $div.removeClass('js-not-an-asset');
        }
    } else {
        obj.remove();
    }
    $('.js-reporting-page--active').css('padding-bottom', $('.js-reporting-page--active .pre-button-messaging').height());
}

function construct_asset_layer(options) {
    // An interactive layer for selecting an asset (e.g. street light)
    var protocol_options = construct_protocol_options(options);
    var protocol_class = construct_protocol_class(options);
    var protocol = new protocol_class(protocol_options);

    var layer_options = construct_layer_options(options, protocol);
    var layer_class = construct_layer_class(options);
    var asset_layer = new layer_class(options.name || "WFS", layer_options);

    asset_layer.map_messaging = new Proxy({}, {
        set: function(target, prop, value) {
            target[prop] = value;
            update_floating_button_messaging(asset_layer, target);
            return true;
        },
        deleteProperty: function(target, prop) {
            delete target[prop];
            update_floating_button_messaging(asset_layer, target);
            return true;
        },
    });

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
var pin_prefix = fixmystreet.pin_prefix || (map_data ? map_data.getAttribute('data-pin_prefix') : '/i/pins/');

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

    style_default_hover: new OpenLayers.Style({
        fillColor: "#55BB00",
        fillOpacity: 0.8,
        strokeColor: "#000000",
        strokeOpacity: 1,
        strokeWidth: 2,
        pointRadius: 8,
        cursor: 'pointer'
    }),

    style_default_select: new OpenLayers.Style({
        externalGraphic: pin_prefix + "spot.png",
        fillColor: "#55BB00",
        graphicWidth: 48,
        graphicHeight: 64,
        graphicXOffset: -24,
        graphicYOffset: -56,
        backgroundGraphic: pin_prefix + "shadow/pin.png",
        backgroundWidth: 60,
        backgroundHeight: 30,
        backgroundXOffset: -7,
        backgroundYOffset: -22,
        popupYOffset: -40,
        graphicOpacity: 1.0
    }),

    construct_named_select_style: function(label) {
        var f = $.extend({
            label: label,
            labelOutlineColor: "white",
            labelOutlineWidth: 3,
            labelYOffset: 65,
            fontSize: '15px',
            fontWeight: 'bold'
        }, fixmystreet.assets.style_default_select.defaultStyle);
        return new OpenLayers.Style(f);
    },
    named_select_action_found: function(asset) {
        var fn = this.fixmystreet.construct_selected_asset_message || this.construct_selected_asset_message;
        var message = fn.call(this, asset) || get_asset_pick_message.call(this);
        this.map_messaging.asset = message;
    },
    named_select_action_not_found: function() {
        this.map_messaging.asset = get_asset_pick_message.call(this);
    },

    selectedFeature: function() {
        return selected_feature;
    },

/*

add() is used to add an asset layer to the map.
It takes a large number of arguments, in two parameters that are merged
together (more for use by the calling code if they e.g. share defaults for each
layer). All arguments are added under the 'fixmystreet' attribute on the layer.

Protocol/data
=============
geometryName - the name of the geometry layer in the data.

WFS layers
----------
Shared options:
    srsName - the SRS of the layer
    propertyNames - a list of which attributes to fetch, if not the default
    wfs_feature - which layer to use within the WFS server

There are two ways of specifying the URL of the WFS layer. You can use wfs_url
or you can use http_wfs_url - the former will make an XML POST request and so
need an OPTIONS pre-flight request; the latter will make a GET request and does
not. However, server-side filtering with filter_key/value can only be used with
wfs_url.

Other HTTP layers
-----------------
http_options - If present, OpenLayers.Protocol.HTTP will be used with the
    properties provided. Most common will be url and params, occasionally
    headers.
format_class - defaults to GML.v3; GeoJSON is common.
format_options - will be passed to the format class when constructed
protocol_class - defaults to HTTP, might need to override to e.g. change the
    name of the 'bbox' parameter

Layer
=====
name - The name for the layer, defaulting to "WFS".
strategy_class - defaults to OpenLayers.Strategy.FixMyStreet
max_resolution - either a number, or a hash mapping cobrand to number. This
    provides the maximum resolution at which an asset layer will be displayed
    (and when first shown, the map may zoom in to this level). The hash is for
    the case where a cobrand shows a different map with different resolutions.
    Run `fixmystreet.map.getResolution()` in the browser's js console to see the
    current resolution.
stylemap - defaults to the default OpenLayers.StyleMap of yellow dots that turn
    green when hovered, and have a 'selected pin' if selected
    You can use fixmystreet.assets.stylemap_invisible for a transparent layer.
srsName - also used here to set the projection of the layer
filter_key/filter_value - filter the data on a particular attribute and
    value/values (filter_value can be a scalar, array, or function). If
    non-HTTP WFS, this can be passed to the server for server-side filtering;
    otherwise the filtering is done after fetching.
attribution - rarely used, an attribution string to use on the map
min_resolution - rarely used, default 0.00001 if max_resolution given

Class
-----
By default, if usrn or road are specified (see below), the
OpenLayers.Layer.VectorNearest class is used, otherwise
OpenLayers.Layer.VectorAsset. This can be overridden using the class attribute.
There is a VectorAssetMove class, which is the same as VectorAsset but fires
checkSelected on category select and pin move as well.

Behaviour
=========
non_interactive - boolean, if set, assets cannot be selected. They can still be
    hovered if a hover style is present.

Relevance
---------
relevant - a function, which if present is called with the current category and
    group and returns whether the layer is relevant or not
asset_group - a string or array of strings containing groups relevant to the
    layer
asset_category - a string or array of strings containing categories relevant to
    the layer
body - if present, as well as the above, this string must match one of the
    fixmystreet.bodies (the relevant body/bodies for the location/chosen
    category). This is so .com only matches on relevant layers for the current
    location.

Visibility
----------
always_visible - boolean, the layer is always 'visible' (though its style could
    still be invisible!) - as long as body matches. If false, check Relevance
    to decide visibility.
snap_threshold - defaults to 50. When a layer becomes visible (if not always
    so), it tries to select the nearest asset to the marker, looking as far as
    this threshold. Set to 0 to disable.

On zoom or visibility change, we check about displaying a message. If the layer
is Relevant, we show a message about picking an asset or zooming in. If the
layer is non_interactive, display_zoom_message needs to be set for this message
to be shown. On mobile, an extra map step is added to enable asset selection.

NB: not found functions (see below) are called when a layer becomes invisible.

asset_item - the name of the type of asset e.g. 'street light'. Used in a few
    places
asset_type - the type, used as a class prefixed by 'asset-' in the default 'You
    can pick a...' message.
asset_item_message - if present, used as the 'You can pick a...' message, with
    ITEM replaced with asset_item

VectorAsset
-----------
actions.asset_found/actions.asset_not_found - if present, then asset selection
will call the former with the asset, and asset deselection will call the
latter.
attributes - a hash of field to attribute. On asset selection, if attribute is
    a function, it is called with the feature; otherwise it is looked up in the
    feature's attributes. Then the input with the field name is set (and
    inspector asset mobile display). On deselection, the attribute fields are
    cleared.
disable_pin_snapping - if true, none of the asset selection code runs
    (including pin move), except the setting of attribute fields
asset_id_field - set to the name of an attribute that is used to decide if two
    assets are the same (upon map move or layer load, layer may refresh but
    want to keep the same asset selected if possible)

On category change, updates layer visibility, and if a feature is selected,
sets the attribute fields.

VectorAssetMove
---------------
This also calls asset_found/asset_not_found on category change/pin move.
You will need to use this class if you need the functions to fire as soon as
the layer is displayed (e.g. if asset selection is mandatory, to show the
select an asset message).

VectorNearest
-------------
On pin update or category change, the nearest feature is looked for.

nearest_radius - how far to look for the nearest feature, default 10
usrn - if present, as either an object of attribute/field keys or an array of
    such objects, updates an input with the field key to the value of the
    attribute with the attribute key (by default, or calls getUSRN with the
    nearest feature if present)
road - boolean; if present:
    If there is a nearest feature, and either always_visible is set or it is a
    Relevant category/group, call actions.found with the nearest feature (if
    actions.found exists), otherwise call only_send with the body.
    If not, call actions.not_found (if present), otherwise call
    remove_only_send.

Found / Not Found standard functions
====================================

Selected asset ID
-----------------
fixmystreet.assets.construct_named_select_style(LABEL) -
    Used as the 'select' part of a stylemap to show an asset's ID above the pin
    when selected. Provide a template of what you want displayed, e.g.
    "${feature_id}".

fixmystreet.assets.named_select_action_found(asset) /
fixmystreet.assets.named_select_action_not_found() -
    These can be provided to asset_found/asset_not_found in order to show a
    message with the asset's ID in the sidebar when selected.

The default message is "You have selected <asset_item> <ID>."

construct_selected_asset_message - if present, called over the default message
    constructor, to return the message to be shown instead.
feature_code - the default message constructor looks up the value of this
    attribute to use as the asset ID.
construct_asset_name - if present, called with the above ID, to return ID and
    string to be used as asset_item instead of the default.

*/
    add: function(default_options, options) {
        if (!document.getElementById('map')) {
            return;
        }

        if (options && options.length) {
            // A list of layers
            var layers_added = [];
            $.each(options, function(i, l) {
                var opts = $.extend(true, {}, default_options, l);
                layers_added.push(fixmystreet.assets.add_layer(opts));
            });
            fixmystreet.assets.add_controls(layers_added, default_options);
            return;
        }

        options = $.extend(true, {}, default_options, options);

        var cls = construct_layer_class(options);
        var staff_report_page = ((fixmystreet.page == 'report' || fixmystreet.page == 'reports') && fixmystreet.staff_set_up);
        if (staff_report_page && cls === OpenLayers.Layer.VectorNearest) {
            // Only care about asset layers on report page when staff
            return;
        }

        var asset_layer = this.add_layer(options);
        this.add_controls([asset_layer], options);
        return asset_layer;
    },

    add_layer: function(options) {
        // Upgrade `asset_category` and `asset_group` to an array, in the case
        // that this layer is only associated with a single category/group.
        if (options.asset_category && !OpenLayers.Util.isArray(options.asset_category)) {
            options.asset_category = [ options.asset_category ];
        }
        if (options.asset_group && !OpenLayers.Util.isArray(options.asset_group)) {
            options.asset_group = [ options.asset_group ];
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
            var visibility = fixmystreet.bodies && options.body ? fixmystreet.bodies.indexOf(options.body) != -1 : true;
            asset_layer.setVisibility(visibility);
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
        var staff_report_page = ((fixmystreet.page == 'report' || fixmystreet.page == 'reports') && fixmystreet.staff_set_up);
        if (fixmystreet.page != 'new' && fixmystreet.page != 'around' && !staff_report_page) {
            // We only want to show asset markers when making a new report
            // or if an inspector is editing a report
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

        var asset_layer;
        for (var i = 0; i < fixmystreet.assets.layers.length; i++) {
            asset_layer = fixmystreet.assets.layers[i];
            var controls = asset_layer.controls || [];
            for (var j = 0; j < controls.length; j++) {
                fixmystreet.map.addControl(controls[j]);
            }
            fixmystreet.map.addLayer(asset_layer);
        }

        var pins_layer = fixmystreet.map.getLayersByName("Pins")[0];
        for (i = 0; i < fixmystreet.assets.layers.length; i++) {
            asset_layer = fixmystreet.assets.layers[i];
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

Message controller
------------------
fixmystreet.message_controller is a group of functions to handle things
such as categories where an asset must be selected or the pin must be on
a road (responsibility message); it also handles categories/questions
set to disable the form (stopper message).

On category change, it checks to see if there is a stopper from a
category/question, and if so, adds a message and disables the report
form.

For responsibility messages, any .js-update-coordinates link will have
its parameters replaced with the current latitude/longitude; any
.js-roads-asset can be replaced with the current layer asset_item/type.

In all the below, the message matched/used is as follows:
* If no_asset_message is provided (either a string, or a hash with ID keys plus
  "default" if you have multiple messages for the one layer), one is
  automatically constructed and used.
* Otherwise, you provide no_asset_msg_id of an ID of a div present in the HTML
  to use (they are in report/new/roads_message.html), or it defaults to
  #js-not-an-asset.
* If you have multiple messages for the one layer (see e.g.
  fixmystreet.assets.buckinghamshire.street_found), you can specify a
  no_asset_msgs_class to make sure they all get hidden correctly.

.asset_found / .asset_not_found - used with VectorAsset actions;
  found will hide matching messages, and enable the report form (unless a
  stopper message or a responsibility message is being shown).
  not found will disable the report form, hide matching messages, and,
  if no stopper message, then show the relevant message ID.

.road_found / .road_not_found - used with VectorNearest actions;
  road_found(layer, feature, [criterion], [msg_id]): If an asset is
  selected, hide messages/enable form as above. If no criterion function
  is supplied, or it returns true, do the same. Otherwise, mark this
  body as do not send, and if it's the only body (or Bucks special case)
  disable the form and show the message given as msg_id (or if not present,
  default as above).
  road_not_found(layer, [criterion]): If an asset is selected, hide
  messages/enable form as above. Otherwise, if it's the only body or the
  criterion passes, disable form/show message as above.

.add_ignored_body - called with a body name if staff can ignore stopper
  messages for that body

*/

fixmystreet.message_controller = (function() {
    var stopperId = 'js-category-stopper',
        stoppers = [],
        ignored_bodies = [];

    // This shows an error message because e.g. an asset isn't selected or a road hasn't been clicked
    function show_responsibility_error(id, layer) {
        var layer_data = layer.fixmystreet;

        var cls = 'js-roads-layer-' + layer.id;
        var div;
        if (layer_data.no_asset_message !== undefined) {
            id = id || '#' + cls;
            var message = layer_data.no_asset_message[id] || layer_data.no_asset_message["default"] || layer_data.no_asset_message;
            div = $('<div/>').html(message);
        } else {
            id = id || '#js-not-an-asset';
            div = $(id);
        }

        var asset_strings = div.find('.js-roads-asset');
        if (layer_data.asset_item) {
            asset_strings.html('a <b class="asset-' + layer_data.asset_type + '">' + layer_data.asset_item + '</b>');
        } else {
            asset_strings.html(asset_strings.data('original'));
        }
        $('.js-update-coordinates').attr('href', function(i, href) {
            var he_arg;
            if (href.indexOf('?') != -1) {
                he_arg = href.indexOf('&he_referral=1');
                href = href.substring(0, href.indexOf('?'));
            }
            href += '?' + OpenLayers.Util.getParameterString({
                latitude: $('#fixmystreet\\.latitude').val(),
                longitude: $('#fixmystreet\\.longitude').val()
            });
            if (he_arg != -1) {
                href += '&he_referral=1';
            }
            return href;
        });

        var msg = div.html();
        if ($('html').hasClass('mobile')) {
            $("body").addClass("map-with-crosshairs2");
        }
        layer.map_messaging.responsibility = msg;
    }

    // This hides the asset/road not found message
    function hide_responsibility_errors(id, layer) {
        delete layer.map_messaging.responsibility;
    }

    // Show the reporting form, unless the road responsibility message is visible.
    function enable_report_form() {
        if ( $('.js-not-an-asset').length ) {
            return;
        }
        if (hide_continue_button()) {
            $('.js-reporting-page--next').show();
        }
        $('.js-reporting-page--next').prop('disabled', false);
        $("#mob_ok, #toggle-fullscreen").removeClass('hidden-js');
    }

    // This hides the reporting form, apart from the category selection
    // And perhaps the category_extras unless asked not to
    function disable_report_form(type) {
        if ($('html').hasClass('mobile') && type !== 'stopper') {
            $("#mob_ok, #toggle-fullscreen").addClass('hidden-js');
        } else {
            $('.js-reporting-page--next').prop('disabled', true);
            if (hide_continue_button()) {
                $('.js-reporting-page--next').hide();
            }
        }
    }

    function hide_continue_button() {
        var cobrands_to_hide = ['hart', 'surrey'];
        if (cobrands_to_hide.indexOf(fixmystreet.cobrand) !== -1) {
            return 1;
        }
    }

    // This hides the responsibility message, and (unless a
    // stopper message or dupes are shown) reenables the report form
    function responsibility_off(layer, type) {
        var layer_data = layer.fixmystreet;
        var id = layer_data.no_asset_msg_id;
        hide_responsibility_errors(id, layer);
        if (!document.getElementById(stopperId)) {
            enable_report_form();
            if (type === 'road') {
                $('#' + layer.id + '_map').remove();
            }
        }
    }

    // This disables the report form and (unless a stopper
    // message is shown) shows a responsibility message
    function responsibility_on(layer, type, override_id) {
        var layer_data = layer.fixmystreet;
        var id = override_id || layer_data.no_asset_msg_id;
        disable_report_form(type);
        if (type === 'road') {
            fixmystreet.pageController.addMapPage(layer);
        }
        hide_responsibility_errors(id, layer);
        if (!document.getElementById(stopperId)) {
            show_responsibility_error(id, layer);
        }
    }

    function is_only_body(body) {
        if (fixmystreet.bodies && fixmystreet.bodies.length == 1 && fixmystreet.bodies[0] == body) {
            return true;
        }
        return false;
    }

    function is_matching_stopper(stopper, i) {
        var body = $('#form_category_fieldset').data('body');

        if (OpenLayers.Util.indexOf(ignored_bodies, body) > -1) {
            return false;
        }

        var category = fixmystreet.reporting.selectedCategory().category;
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

    function check_for_stopper() {
        var only_send = fixmystreet.body_overrides.get_only_send();
        if (only_send == 'National Highways') {
            // If we're sending to National Highways, this message doesn't matter
            return;
        }

        var $id = $('#' + stopperId);
        var matching = $.grep(stoppers, is_matching_stopper);
        if (!matching.length) {
            $id.remove();
            enable_report_form();
            return;
        }

        var stopper = matching[0]; // Assume only one match possible at present
        var $msg;
        if (typeof stopper.message === 'function') {
            $msg = stopper.message();
        } else {
            $msg = $('<div class="js-stopper-notice box-warning">' + stopper.message + '</div>');
        }
        $msg.attr('id', stopperId);
        $msg.attr('role', 'alert');
        $msg.attr('aria-live', 'assertive');

        // XXX Will this need to move the message from one 'page' to another ever?
        if ($id.length) {
            $id.replaceWith($msg);
        } else {
            $msg.prependTo('.js-reporting-page--active .pre-button-messaging');
        }
        $('.js-reporting-page--active').css('padding-bottom', $('.js-reporting-page--active .pre-button-messaging').height());
        disable_report_form('stopper');
    }

    $(fixmystreet).on('report_new:category_change', check_for_stopper);

    return {
        asset_found: function() {
            responsibility_off(this, 'asset');
            return ($('#' + stopperId).length);
        },

        asset_not_found: function() {
            if (!this.visibility) {
                responsibility_off(this, 'asset');
            } else {
                responsibility_on(this, 'asset');
            }
        },

        // A road was found; if some roads should still cause disabling/message,
        // then you should pass in a criterion function to test the found feature,
        // plus an ID of the message to be shown
        road_found: function(layer, feature, criterion, msg_id) {
            if (fixmystreet.assets.selectedFeature()) {
                responsibility_off(layer, 'road');
            } else if (!criterion || criterion(feature)) {
                responsibility_off(layer, 'road');
            } else {
                fixmystreet.body_overrides.do_not_send(layer.fixmystreet.body);
                var selected = fixmystreet.reporting.selectedCategory();
                if (is_only_body(layer.fixmystreet.body)) {
                    responsibility_on(layer, 'road', msg_id);
                }
                else if (layer.fixmystreet.body == 'Buckinghamshire Council' &&
                    selected.group == 'Grass, hedges and weeds') {
                    // Special case for Bucks' 'Grass' layer
                    responsibility_on(layer, 'road', msg_id);
                }
            }
        },

        // If a feature wasn't found at the location they've clicked, it's
        // probably a field or something. Show an error to that effect,
        // unless an asset is selected.
        road_not_found: function(layer, criterion) {
            // don't show the message if clicking on a National Highways road
            if (fixmystreet.body_overrides.get_only_send() == 'National Highways' || !layer.visibility) {
                responsibility_off(layer, 'road');
            } else if (fixmystreet.assets.selectedFeature()) {
                fixmystreet.body_overrides.allow_send(layer.fixmystreet.body);
                responsibility_off(layer, 'road');
            } else if ( (criterion && criterion()) || is_only_body(layer.fixmystreet.body) ) {
                responsibility_on(layer, 'road');
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
        }
    };

})();
