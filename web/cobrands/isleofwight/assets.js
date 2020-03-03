(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: fixmystreet.staging ? "https://tilma.staging.mysociety.org/mapserver/iow": "https://tilma.mysociety.org/mapserver/iow",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    max_resolution: {
        'isleofwight': 0.5291677250021167,
        'fixmystreet': 1.194328566789627
    },
    attributes: {
        central_asset_id: 'central_asset_id',
        site_code: 'site_code'
    },
    asset_id_field: 'asset_id',
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    body: "Isle of Wight Council"
};

var pin_prefix = fixmystreet.pin_prefix || document.getElementById('js-map-data').getAttribute('data-pin_prefix');

var labeled_default = {
    fillColor: "#FFFF00",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.8,
    strokeWidth: 2,
    pointRadius: 6
};

var labeled_select = {
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

    label: "${asset_id}",
    labelOutlineColor: "white",
    labelOutlineWidth: 3,
    labelYOffset: 65,
    fontSize: '15px',
    fontWeight: 'bold'
};

var labeled_stylemap = new OpenLayers.StyleMap({
  'default': new OpenLayers.Style(labeled_default),
  'select': new OpenLayers.Style(labeled_select)
});

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "streets"
        }
    },
    always_visible: true,
    non_interactive: true,
    asset_type: 'area',
    max_resolution: {
        'isleofwight': 6.614596562526458,
        'fixmystreet': 4.777314267158508
    },
    usrn: {
        attribute: 'SITE_CODE',
        field: 'site_code'
    },
    stylemap: new OpenLayers.StyleMap({
        'default': new OpenLayers.Style({
            fill: false,
            strokeColor: "#5555FF",
            strokeOpacity: 0.1,
            strokeWidth: 7
        })
    })
}));

function not_found_msg_update() {
    $('.category_meta_message').html('Please select an item or a road/pavement/path on the map &raquo;');
    $('.category_meta_message').removeClass('meta-highlight');
    $("input[name=asset_details]").val('');
}

function found_item(layer, asset) {
  var id = asset.attributes.central_asset_id || '';
  if (id !== '') {
      var attrib = asset.attributes;
      var asset_name = attrib.feature_type_name + '; ' + attrib.site_name + '; ' + attrib.feature_location;
      $('.category_meta_message').html('You have selected ' + asset_name);
      $('.category_meta_message').addClass('meta-highlight');
      $("input[name=asset_details]").val(asset_name);
  } else {
      not_found_msg_update();
  }
}


var point_asset_defaults = $.extend(true, {}, defaults, {
    snap_threshold: 5,
    select_action: true,
    asset_type: 'spot',
    asset_item: "item",
    actions: {
        asset_found: function(asset) {
          found_item(this, asset);
        },
        asset_not_found: function() {
          not_found_msg_update();
        }
    }

});

var line_asset_defaults = $.extend(true, {}, defaults, {
    display_zoom_message: true,
    non_interactive: true,
    road: true,
    stylemap: fixmystreet.assets.stylemap_invisible,
    usrn: {
        attribute: 'site_code',
        field: 'site_code'
    },
    asset_item: 'road',
    actions: {
        found: function(layer, feature) {
          if ( fixmystreet.assets.selectedFeature() ) {
             return;
          }
          found_item(layer, feature);
        },
        not_found: function(layer) {
          if ( fixmystreet.assets.selectedFeature() ) {
             return;
          }
          not_found_msg_update();
        }
    }
});


var point_category_list = [
    //"Dog Fouling",
    "Manholes",
    "Trees & Hedges",
    //"Pavements/footpaths",
    //"Drainage",
    //"Car Parking",
    "Street Lighting",
    "Bus Stops",
    //"Flyposting",
    //"Potholes",
    //"Street Cleaning",
    "Bridges & Walls",
    "Traffic Lights",
    "Street Furniture",
    //"Roads/Highways",
    "Road Traffic Signs & Markings",
    "Grass Verges & Weeds",
    //"Flytipping",
    //"Graffiti",
    "Street Nameplates",
    //"Abandoned Vehicles"
];

var line_category_list = [
    "Dog Fouling",
    "Drainage",
    "Car Parking",
    "Pavements/footpaths",
    "Potholes",
    "Street Cleaning",
    "Roads/Highways",
    "Flytipping",
    "Abandoned Vehicles"
];

var layer_map = {
    "Dog Fouling": "Dog_Fouling",
    "Drainage": "Drainage_line",
    "Car Parking": "Car_Parks",
    "Trees & Hedges": "Trees_Hedges",
    "Pavements/footpaths": "Pavements_footpaths",
    "Street Lighting": "Street_Lighting",
    "Bus Stops": "Bus_Stops",
    "Street Cleaning": "Street_Cleaning",
    "Bridges & Walls": "Bridges_Walls",
    "Traffic Lights": "Traffic_Lights",
    "Street Furniture": "Street_Furniture",
    "Roads/Highways": "Roads_Highways",
    "Road Traffic Signs & Markings": "Road_Traffic_Signs_Markings",
    "Grass Verges & Weeds": "Grass_Verges_Weeds",
    "Street Nameplates": "Street_Nameplates",
    "Abandoned Vehicles": "Abandoned_Vehicles"
};

for (i = 0; i < point_category_list.length; i++) {
    cat = point_category_list[i];
    layer = layer_map[cat] || cat;

    fixmystreet.assets.add($.extend(true, {}, point_asset_defaults, {
        asset_group: cat,
        http_options: {
            params: {
                TYPENAME: layer
            }
        }
    }));
}

for (i = 0; i < line_category_list.length; i++) {
    cat = line_category_list[i];
    layer = layer_map[cat] || cat;

    fixmystreet.assets.add($.extend(true, {}, line_asset_defaults, {
        asset_group: cat,
        asset_category: [
            cat
        ],
        http_options: {
            params: {
                TYPENAME: layer
            }
        }
    }));
}

// non union layers
fixmystreet.assets.add($.extend(true, {}, point_asset_defaults, {
    asset_group: "Roads/Highways",
    http_options: {
        params: {
            TYPENAME: "Fords"
        }
    }
}));

fixmystreet.assets.add($.extend(true, {}, point_asset_defaults, {
    asset_group: "Roads/Highways",
    http_options: {
        params: {
            TYPENAME: "Furn-Grid_and_Stones"
        }
    }
}));


fixmystreet.assets.add($.extend(true, {}, point_asset_defaults, {
    asset_group: "Drainage",
    http_options: {
        params: {
            TYPENAME: "Drainage_spot"
        }
    }
}));

fixmystreet.assets.add($.extend(true, {}, point_asset_defaults, {
    asset_group: "Car Parking",
    http_options: {
        params: {
            TYPENAME: "Car_Parking"
        }
    }
}));

fixmystreet.assets.add($.extend(true, {}, line_asset_defaults, {
    asset_group: "Grass Verges & Weeds",
    asset_category: [
      "Grass Verges & Weeds"
    ],
    http_options: {
        params: {
            TYPENAME: "Verges-Natural"
        }
    }
}));

fixmystreet.assets.add($.extend(true, {}, point_asset_defaults, {
    asset_group: "Dog Fouling",
    http_options: {
        params: {
            TYPENAME: "Furn-Bins"
        }
    }
}));

fixmystreet.message_controller.add_msg_after_bodies(defaults.body);


})();
