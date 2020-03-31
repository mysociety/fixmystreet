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
    max_resolution: 4.777314267158508,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "London Borough of Bexley",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var streetlight_stylemap = new OpenLayers.StyleMap({
  'default': fixmystreet.assets.style_default,
  'select': fixmystreet.assets.construct_named_select_style("${Unit_No}")
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
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

var road_defaults = $.extend(true, {}, defaults, {
    stylemap: fixmystreet.assets.stylemap_invisible,
    always_visible: true,
    non_interactive: true
});

fixmystreet.assets.add(road_defaults, {
    http_options: {
        params: {
            TYPENAME: "Streets",
        }
    },
    nearest_radius: 100,
    usrn: [
        {
            attribute: 'UPRN',
            field: 'uprn'
        },
        {
            attribute: 'NSG_REF',
            field: 'NSGRef'
        },
        {
            attribute: 'NSG_REF',
            field: 'site_code'
        }
    ]
});

fixmystreet.assets.add(defaults, {
    http_options: {
        url: "https://tilma.mysociety.org/mapserver/bexley",
        params: {
            TYPENAME: "Trees"
        }
    },
    asset_id_field: 'central_as',
    attributes: {
        central_asset_id: 'central_as',
        site_code: 'site_code'
    },
    asset_type: 'spot',
    asset_category: ['Street', 'TPO enquiry'],
    asset_item: 'tree'
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

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Toilets"
        }
    },
    asset_type: 'spot',
    asset_category: ["Public toilets"],
    asset_item: 'public toilet'
});

})();

