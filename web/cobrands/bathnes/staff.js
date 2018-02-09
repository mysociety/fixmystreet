(function(){

if (!fixmystreet.maps || !fixmystreet.maps.banes_defaults) {
    return;
}

var llpg_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillColor: "#FFFF00",
        fillOpacity: 0.6,
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

var highways_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: true,
        fillOpacity: 0,
        strokeColor: "#55BB00",
        strokeOpacity: 0.5,
        strokeWidth: 2,
        title: '${description}\n${notes}'
    })
    // Defining a 'hover' style means this layer will have hover
    // behaviour even if set as non_interactive.
    // 'hover': new OpenLayers.Style({
    //     strokeOpacity: 1,
    //     strokeWidth: 3
    // })

});


$(fixmystreet.add_assets($.extend(true, {}, fixmystreet.maps.banes_defaults, {
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
})));

$(fixmystreet.add_assets($.extend(true, {}, fixmystreet.maps.banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "AdoptedHighways"
        }
    },
    stylemap: highways_stylemap,
    non_interactive: true,
    always_visible: true
})));



})();
