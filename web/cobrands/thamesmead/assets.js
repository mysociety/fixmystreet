(function(){

if (!fixmystreet.maps) {
    return;
}

var wfs_host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';
var tilma_url = "https://" + wfs_host + "/mapserver/thamesmead";

// This is required so that the found/not found actions are fired on category
// select and pin move rather than just on asset select/not select.
OpenLayers.Layer.ThamesmeadVectorAsset = OpenLayers.Class(OpenLayers.Layer.VectorAsset, {
    initialize: function() {
        OpenLayers.Layer.VectorAsset.prototype.initialize.apply(this, arguments);
        $(fixmystreet).on('maps:update_pin', this.checkSelected.bind(this));
        $(fixmystreet).on('report_new:category_change', this.checkSelected.bind(this));
    },

    CLASS_NAME: 'OpenLayers.Layer.ThamesmeadVectorAsset'
});

var defaults = {
    http_options: {
        url: tilma_url,
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    asset_type: 'area',
    asset_id_field: 'fid',
    attributes: {
        central_asset_id: 'fid',
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    select_action: true,
    body: "Thamesmead",
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    class: OpenLayers.Layer.ThamesmeadVectorAsset,
    actions: {
        asset_found: function() {
            $('.category_meta_message').html('');
            $('.js-reporting-page--next').prop('disabled', false);
        },
        asset_not_found: function() {
            var url_stem = new RegExp(/.*\?/);
            var fixmystreet_url = window.location.href.replace(url_stem, 'https://www.fixmystreet.com/report/new?');
            $('.category_meta_message').html('<p>Please pick a highlighted area from the map to report an issue to Thamesmead/Peabody.</p><p>If your issue is not on a highlighted area, or you can\'t see a highlighted area, click <a href=' + fixmystreet_url + '>Here</a> to report your issue to the local council</p>').show();
            $('.js-reporting-page--next').prop('disabled', true);
        }
    }
};

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "hardsurfaces"
        }
    },
    asset_item: 'Thamesmead managed hard surface',
    asset_group: 'Hard surfaces/paths/road (Peabody)',
    asset_id_field: 'ogc_fid',
    attributes: {
        central_asset_id: 'ogc_fid',
    },
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "grass"
        }
    },
    asset_item: 'Thamesmead managed grass areas',
    asset_group: 'Grass and grass areas (Peabody)',
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "water"
        }
    },
    asset_item: 'Thamesmead managed water areas',
    asset_group: 'Water areas (Peabody)',
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "treegroups"
        }
    },
    asset_item: 'Thamesmead managed trees',
    asset_group: 'Trees (Peabody)',
});

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "planting"
        }
    },
    asset_item: 'Thamesmead managed shrubs',
    asset_group: 'Planters and flower beds (Peabody)',
});

})();
