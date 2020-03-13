(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    wfs_url: "https://tilma.mysociety.org/mapserver/lincs",
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    asset_id_field: 'Confirm_CA',
    attributes: {
        central_asset_id: 'Confirm_CA',
        asset_details: 'Asset_Id'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    body: "Lincolnshire County Council"
};

fixmystreet.assets.add(defaults, {
    wfs_feature: "SL_Bollards",
    asset_category: "Bollards (lit)",
    asset_item: 'bollard'
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "SL_Street_Light_Units",
    asset_category: "Street light",
    asset_item: 'street light',
    filter_key: 'Type',
    filter_value: [
        "SL: Bulkhead Lighting", "SL: Refuge Beacon", "SL: Street Lighting Unit"
    ]
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "SL_Street_Light_Units",
    asset_category: "Subway light",
    asset_item: 'light',
    filter_key: 'Type',
    filter_value: "SL: Subway Lighting Unit"
});

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

fixmystreet.assets.add(defaults, {
    wfs_feature: "Safety_Barriers",
    asset_category: ["Roadside safety barrier", "Missing safety fence"],
    asset_item: 'barrier or fence',
    filter_key: 'Type',
    filter_value: "ST: Safety Barrier",
    stylemap: get_barrier_stylemap(),
    max_resolution: 1.194328566789627
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "LCC_Drainage-GulliesOffletsManholes",
    asset_category: "Blocked drain",
    asset_item: 'drain'
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "ST_All_Structures",
    asset_category: "Damaged dyke, ditch or culvert",
    asset_item: 'culvert',
    filter_key: 'Type',
    filter_value: [
        "ST: Culvert 1 Cell", "ST: Culvert 2+ Cells", "ST: Culvert/Pipe"
    ]
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "SL_Lit_Signs",
    asset_category: "Sign (lit)",
    asset_item: 'street sign'
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "ST_All_Structures",
    asset_category: [
        "Bridge",
        "Bridge or Structure"
    ],
    asset_item: 'bridge',
    filter_key: 'Type',
    filter_value: [
        "ST: Bridge", "ST: Bridge Ped/Cycle 1 Span",
        "ST: Bridge Ped/Cycle 2+ Spans", "ST: Bridge Vehicular 1 Span",
        "ST: Bridge Vehicular 2-3 Spans", "ST: Bridge Vehicular 4+ Spans"
    ]
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "Carriageway",
    asset_category: [
        "Damaged/missing cats eye",
        "Damaged road edge, encroaches less than 100mm",
        "Damaged road edge, encroaches more than 100mm",
        "Loose chippings",
        "Manhole/drain cover on road/cycleway",
        "Obstruction on road/cycleway",
        "Pothole on road/cycleway",
        "Road markings faded/missing",
        "Road surface issue"
    ],
    asset_item: 'road',
    asset_item_message: null,
    disable_pin_snapping: true,
    stylemap: fixmystreet.assets.stylemap_invisible
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "NSG",
    always_visible: true,
    non_interactive: true,
    max_resolution: 9.554628534317017,
    usrn: {
        attribute: 'Site_Code',
        field: 'site_code'
    },
    nearest_radius: 20,
    stylemap: fixmystreet.assets.stylemap_invisible
});

var llpg_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillOpacity: 0,
        strokeColor: "#000000",
        strokeOpacity: 0.25,
        strokeWidth: 2,
        pointRadius: 10,

        label: "${label}",
        labelOutlineColor: "white",
        labelOutlineWidth: 2,
        fontSize: '11px',
        fontWeight: 'bold'
    })
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "LLPG",
    // LLPG is only to be shown when fully zoomed in
    max_resolution: 0.5971642833948135,
    stylemap: llpg_stylemap,
    non_interactive: true,
    always_visible: true
});

})();
