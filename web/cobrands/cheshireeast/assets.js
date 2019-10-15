(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.staging.mysociety.org/mapserver/cheshireeast",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    format_class: OpenLayers.Format.GML.v3.MultiCurveFix, // XXX Remove on merge
    max_resolution: 4.777314267158508,
    min_resolution: 0.5971642833948135,
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'site_code'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    body: "Cheshire East Council",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var streetlight_select = $.extend({
    label: "${feature_id}",
    labelOutlineColor: "white",
    labelOutlineWidth: 3,
    labelYOffset: 65,
    fontSize: '15px',
    fontWeight: 'bold'
}, fixmystreet.assets.style_default_select.defaultStyle);

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'select': new OpenLayers.Style(streetlight_select)
});

var labeled_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    stylemap: streetlight_stylemap,
    asset_type: 'spot',
    asset_id_field: 'central_as',
    actions: {
        asset_found: function(asset) {
          var id = asset.attributes.feature_id || '';
          if (id !== '') {
              var asset_name = this.fixmystreet.asset_item;
              $('.category_meta_message').html('You have selected ' + asset_name + ' <b>' + id + '</b>');
          } else {
              $('.category_meta_message').html(this.fixmystreet.asset_item_message);
          }
        },
        asset_not_found: function() {
           $('.category_meta_message').html(this.fixmystreet.asset_item_message);
        }
    }
});

fixmystreet.assets.add(labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "StreetLights"
        }
    },
    asset_group: 'Street lights',
    asset_item: 'street light',
    asset_item_message: 'You can pick a <b class="asset-spot">street light</b> from the map &raquo;'
});

var road_defaults = $.extend(true, {}, defaults, {
    stylemap: fixmystreet.assets.stylemap_invisible,
    always_visible: true,
    non_interactive: true
});

fixmystreet.assets.add(road_defaults, {
    http_options: {
        params: {
            TYPENAME: "AdoptedRoads"
        }
    },
    usrn: {
        attribute: 'site_code',
        field: 'site_code'
    }
});

fixmystreet.assets.add(road_defaults, {
    http_options: {
        params: {
            TYPENAME: "UnAdoptedRoads"
        }
    },
    road: true,
    all_categories: true,
    no_asset_msg_id: '#js-not-council-road',
    // The functions assume allow when found, disallow when not found, so we want the reverse
    actions: {
        found: fixmystreet.message_controller.road_not_found,
        not_found: fixmystreet.message_controller.road_found
    }
});

})();
