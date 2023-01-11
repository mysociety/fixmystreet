(function(){

if (!fixmystreet.maps || !window.OpenLayers) {
    return;
}

var banes_defaults = {
    http_options: {
        url: "https://data.bathnes.gov.uk/geoserver/fms/ows",
        params: {
            mapsource: "BathNES/WFS",
            SERVICE: "WFS",
            VERSION: "1.0.0",
            REQUEST: "GetFeature",
            TYPENAME: "",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700",
            outputFormat: 'application/json'
        }
    },
    format_class: OpenLayers.Format.GeoJSON,
    format_options: {ignoreExtraDims: true},
    asset_category: "",
    asset_item: "asset",
    asset_type: 'spot',
    max_resolution: 4.777314267158508,
    asset_id_field: 'feature_no',
    attributes: null,
    geometryName: 'msGeometry',
    body: "Bath and North East Somerset Council",
    srsName: "EPSG:27700"
};

var llpg_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillOpacity: 0,
        strokeColor: "#000000",
        strokeOpacity: 0.25,
        strokeWidth: 2,
        pointRadius: 10,

        label: '${label_text}',
        labelOutlineColor: "white",
        labelOutlineWidth: 2,
        fontSize: '11px',
        fontWeight: 'bold'
    })
});


fixmystreet.assets.add(banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "LLPG"
        }
    },
    // LLPG is only to be shown when fully zoomed in
    max_resolution: 0.5971642833948135,
    stylemap: llpg_stylemap,
    non_interactive: true,
    always_visible: true
});


// Some normally-invisible layers are visible to staff, so replace their
// stylemaps accordingly.
var replacement_stylemaps = {
    "Adopted Highways": new OpenLayers.StyleMap({
        'default': new OpenLayers.Style({
            fill: true,
            fillOpacity: 0,
            // strokeColor: "#55BB00",
            strokeColor: "#FFFF00",
            strokeOpacity: 0.5,
            strokeWidth: 2,
            title: '${description}\n${notes}'
        })
    }),
    "Parks and Grounds": new OpenLayers.StyleMap({
        'default': new OpenLayers.Style({
            fill: false,
            strokeColor: "#008800",
            strokeOpacity: 0.5,
            strokeWidth: 2,
            title: '${site_name}'
        })
    })
};

$.each(fixmystreet.assets.layers, function() {
    if (typeof replacement_stylemaps[this.name] !== 'undefined') {
        this.styleMap = replacement_stylemaps[this.name];
    }
});

})();
