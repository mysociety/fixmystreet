(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.staging.mysociety.org/mapserver/lincs",
        // url: "https://confirmdev.eu.ngrok.io/tilmastaging/mapserver/lincs",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    format_class: OpenLayers.Format.GML.v3.MultiCurveFix,
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'Confirm_CA',
    attributes: {
        central_asset_id: 'Confirm_CA',
        asset_details: 'Asset_Id'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "SL_Bollards"
        }
    },
    asset_category: "Bollards (lit)",
    asset_item: 'bollard'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "SL_Street_Light_Units"
        }
    },
    asset_category: "Street light",
    asset_item: 'street light'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "SL_Street_Light_Units"
        }
    },
    asset_category: "Street light",
    asset_item: 'street light',
    filter_key: 'Type',
    filter_value: [
        "SL: Bulkhead Lighting", "SL: Refuge Beacon", "SL: Street Lighting Unit"
    ]
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "SL_Street_Light_Units"
        }
    },
    asset_category: "Subway light",
    asset_item: 'light',
    filter_key: 'Type',
    filter_value: "SL: Subway Lighting Unit"
}));

function get_barrier_stylemap() {
    return new OpenLayers.StyleMap({
        'default': new OpenLayers.Style({
            strokeColor: "#000000",
            strokeOpacity: 0.9,
            strokeWidth: 4
        }),
        'select': new OpenLayers.Style({
            strokeColor: "#55BB00",
            strokeOpacity: 1,
            strokeWidth: 8
        }),
        'hover': new OpenLayers.Style({
            strokeWidth: 6,
            strokeOpacity: 1,
            strokeColor: "#FFFF00",
            cursor: 'pointer'
        })
    });
}

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Safety_Barriers"
        }
    },
    asset_category: "Roadside safety barrier",
    asset_item: 'barrier',
    filter_key: 'Type',
    filter_value: "ST: Safety Barrier",
    stylemap: get_barrier_stylemap(),
    max_resolution: 1.194328566789627
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Safety_Barriers"
        }
    },
    asset_category: "Safety fence",
    asset_item: 'fence',
    filter_key: 'Type',
    filter_value: "ST: Safety Fences",
    stylemap: get_barrier_stylemap(),
    max_resolution: 1.194328566789627
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "LCC_Drainage-GulliesOffletsManholes"
        }
    },
    asset_category: "Blocked drainage item",
    asset_item: 'drain'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "ST_All_Structures"
        }
    },
    asset_category: "Dyke/Ditch/Culvert defect",
    asset_item: 'culvert',
    filter_key: 'Type',
    filter_value: [
        "ST: Culvert 1 Cell", "ST: Culvert 2+ Cells", "ST: Culvert/Pipe"
    ]
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "SL_Lit_Signs"
        }
    },
    asset_category: "Sign (lit)",
    asset_item: 'street sign'
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "ST_All_Structures"
        }
    },
    asset_category: "Bridge",
    asset_item: 'bridge',
    filter_key: 'Type',
    filter_value: [
        "ST: Bridge", "ST: Bridge Ped/Cycle 1 Span",
        "ST: Bridge Ped/Cycle 2+ Spans", "ST: Bridge Vehicular 1 Span",
        "ST: Bridge Vehicular 2-3 Spans", "ST: Bridge Vehicular 4+ Spans"
    ]
}));

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "NSG"
        }
    },
    always_visible: true,
    non_interactive: true,
    usrn: {
        attribute: 'Site_Code',
        field: 'site_code'
    },
    stylemap: new OpenLayers.StyleMap({
        'default': new OpenLayers.Style({
            fill: false,
            stroke: false
        })
    })

}));

})();
