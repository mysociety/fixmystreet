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

fixmystreet.assets.add($.extend(true, {}, defaults, {
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
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Bollards"
        }
    },
    asset_type: 'spot',
    asset_id_field: 'Unit_ID',
    attributes: {
        UnitID: 'Unit_ID'
    },
    asset_category: ["Damaged sign, bollard etc."],
    asset_item: 'bollard'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Lighting"
        }
    },
    asset_type: 'spot',
    asset_id_field: 'Unit_ID',
    attributes: {
        UnitID: 'Unit_ID'
    },
    asset_category: ["Lamp post", "Light in park or open space", "Zebra crossing light", "Traffic sign light", "Underpass light", "Keep left bollard", "Light in multi-storey car park", "Light in outside car park"],
    asset_item: 'street light'
}));

})();

