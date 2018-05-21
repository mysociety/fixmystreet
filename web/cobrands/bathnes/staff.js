(function(){

if (!fixmystreet.maps || !fixmystreet.maps.banes_defaults) {
    return;
}

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


fixmystreet.assets.add($.extend(true, {}, fixmystreet.maps.banes_defaults, {
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
}));


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
