(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.mysociety.org/mapserver/bexley",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    format_class: OpenLayers.Format.GML.v3.MultiCurveFix, // Not sure needed any more
    max_resolution: 4.777314267158508,
    min_resolution: 0.5971642833948135,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "London Borough of Bexley",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var streetlight_default = {
    fillColor: "#FFFF00",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.8,
    strokeWidth: 2,
    pointRadius: 6
};

var pin_prefix = fixmystreet.pin_prefix || document.getElementById('js-map-data').getAttribute('data-pin_prefix');

var streetlight_select = {
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
    graphicOpacity: 1.0,

    label: "${Unit_No}",
    labelOutlineColor: "white",
    labelOutlineWidth: 3,
    labelYOffset: 65,
    fontSize: '15px',
    fontWeight: 'bold'
};

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': new OpenLayers.Style(streetlight_default),
  'select': new OpenLayers.Style(streetlight_select)
});

var labeled_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    stylemap: streetlight_stylemap,
    feature_code: 'Unit_No',
    asset_type: 'spot',
    asset_id_field: 'Unit_ID',
    attributes: {
        UnitID: 'Unit_ID'
    },
    actions: {
        asset_found: function(asset) {
          var id = asset.attributes[this.fixmystreet.feature_code] || '';
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

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Streets",
        }
    },
    always_visible: true,
    non_interactive: true,
    nearest_radius: 20,
    usrn: {
        attribute: 'NSG_REF',
        field: 'NSGRef'
    },
    stylemap: new OpenLayers.StyleMap({
        'default': new OpenLayers.Style({
            fill: false,
            stroke: false
        })
    })
});

fixmystreet.assets.add(labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "Bollards"
        }
    },
    asset_category: ["Traffic bollard"],
    asset_item_message: 'Select the <b class="asset-spot"></b> on the map to pinpoint the exact location of a damaged traffic bollard.',
    asset_item: 'bollard'
});

fixmystreet.assets.add(labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "Lighting"
        }
    },
    asset_category: ["Lamp post", "Light in park or open space", "Underpass light", "Light in multi-storey car park", "Light in outside car park"],
    asset_item_message: 'Please pinpoint the exact location for the street lighting fault.',
    asset_item: 'street light'
});

// We need to trigger the below function on subcategory change also
$(function(){
    $("#problem_form").on("change.category", "#form_DALocation", function() {
        $(fixmystreet).trigger('report_new:category_change', [ $('#form_category') ]);
    });
});

fixmystreet.message_controller.register_category({
    body: defaults.body,
    category: function() {
        var cat = $('#form_category').val();
        if (cat === 'Dead animal') {
            var where = $('#form_DALocation').val();
            if (where === 'Garden' || where === 'Other private property') {
                return true;
            }
        }
        return false;
    },
    keep_category_extras: true,
    message: 'Please follow the link below to pay to remove a dead animal from a private property.'
});

})();

