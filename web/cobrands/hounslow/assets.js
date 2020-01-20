(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.mysociety.org/mapserver/hounslow",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    asset_type: 'spot',
    max_resolution: {
        'hounslow': 0.5291677250021167,
        'fixmystreet': 1.194328566789627
    },
    asset_id_field: 'CentralAssetId',
    attributes: {
        central_asset_id: 'CentralAssetId',
        asset_details: 'FeatureId'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    body: "Hounslow Borough Council"
};

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "bins"
        }
    },
    asset_category: "Litter Bins",
    asset_item: 'bin'
}));

// Disabled for now as the data is quite out of date and causing problems
// sending reports.
// fixmystreet.assets.add($.extend(true, {}, defaults, {
//     http_options: {
//         params: {
//             TYPENAME: "trees"
//         }
//     },
//     asset_id_field: 'central_asset_id',
//     attributes: {
//         central_asset_id: 'central_asset_id',
//         asset_details: 'asset_number'
//     },
//     asset_category: [
//         "Tree Danger/Obstruction",
//         "Branches overhanging",
//         "Damage By Tree",
//         "Dead/Dying/Diseased",
//         "Dying or dangerous tree",
//         "Empty tree Pit",
//         "Fallen or leaning tree",
//         "General Maintenance and pruning",
//         "Illuminated Traffic signal obstructed by vegetation",
//         "Traffic signal obstructed by vegetation",
//         "Pest: Tree/Shrub",
//         "Pests in trees and shrubs",
//         "Tree Branches Overhanging",
//         "Tree Maintenance",
//         "Tree causing damage to property",
//         "Tree obstructing street light",
//         "Trees or shrubs blocking visibility",
//         "Trees or shrubs causing obstruction of highway",
//         "Trees"
//       ],
//     asset_item: 'tree'
// }));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "signs"
        }
    },
    asset_category: [
        "Sign Obstructed: Vegetation",
        "Missing sign",
        "Missing/ damaged traffic sign",
        "Sign or road marking missing following works",
        "Street nameplate damaged",
        "Traffic Sign obstructed (vegetation)",
        "Unlit sign knocked down"
    ],
    asset_item: 'sign'
}));

// "We do not want to show gullies as an asset layer, until we are
//  confident that the inventory is accurate."
// https://3.basecamp.com/4020879/buckets/10951425/todos/1780668464
// fixmystreet.assets.add($.extend(true, {}, defaults, {
//     http_options: {
//         params: {
//             TYPENAME: "gulleys"
//         }
//     },
//     asset_category: [
//         "Bad smell",
//         "Flooding",
//         "Blocked gully",
//         "Damaged/ cracked drain or man hole cover",
//         "Missing drain or man hole cover"
//     ],
//     asset_item: 'gulley'
// }));

var streetlight_select = $.extend({
    label: "${FeatureId}",
    labelOutlineColor: "white",
    labelOutlineWidth: 3,
    labelYOffset: 65,
    fontSize: '15px',
    fontWeight: 'bold'
}, fixmystreet.assets.style_default_select.defaultStyle);

// The label for street light markers should be everything after the final
// '/' in the feature's FeatureId attribute.
// This seems to be the easiest way to perform custom processing
// on style attributes in OpenLayers...
var select_style = new OpenLayers.Style(streetlight_select);
select_style.createLiterals = function() {
    var literals = Object.getPrototypeOf(this).createLiterals.apply(this, arguments);
    if (literals.label && literals.label.split) {
        literals.label = literals.label.split("/").slice(-1)[0];
    }
    return literals;
};

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'select': select_style
});

var labeled_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    stylemap: streetlight_stylemap,
    feature_code: 'FeatureId',
    actions: {
        asset_found: function(asset) {
          var id = asset.attributes[this.fixmystreet.feature_code] || '';
          if (id !== '' && id.split) {
              var code = id.split("/").slice(-1)[0];
              $('.category_meta_message').html('You have selected column <b>' + code + '</b>');
          } else {
              $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
          }
        },
        asset_not_found: function() {
           $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
        }
    }
});

fixmystreet.assets.add($.extend(true, {}, labeled_defaults, {
    http_options: {
        params: {
            TYPENAME: "lighting"
        }
    },
    asset_category: [
        "Damage to paintwork",
        "Damage to paintwork/ column",
        "Door Missing/ open",
        "Lights too bright/ dull",
        "New LED lights not working",
        "New LED lights too bright",
        "New LED lights too dull",
        "Not coming on/ faulty",
        "Street light leaning",
        "Street light not working",
        "Street light on during the day",
        "Street light wiring exposed",
        "Street lights on during the day",
        "Unauthorised sign",
        "Veg Obstructed: Street Light",
        "Zebra crossing beacon fault"
    ],
    asset_item: 'light'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "streets"
        }
    },
    max_resolution: {
        'hounslow': 6.614596562526458,
        'fixmystreet': 4.777314267158508
    },
    always_visible: true,
    non_interactive: true,
    usrn: {
        attribute: 'SITE_CODE',
        field: 'site_code'
    },
    stylemap: fixmystreet.assets.stylemap_invisible
}));


})();
