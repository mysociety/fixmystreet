(function(){

if (!fixmystreet.maps || !fixmystreet.maps.banes_defaults) {
    return;
}

var llpg_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillColor: "#FFFF00",
        fillOpacity: 0.6,
        strokeColor: "#000000",
        strokeOpacity: 0.8,
        strokeWidth: 2,
        pointRadius: 10,

        label: '${label_text}',
        labelOutlineColor: "white",
        labelOutlineWidth: 2,
        fontSize: '11px',
        fontWeight: 'bold'
    }),
    // 'select': new OpenLayers.Style({
    //     externalGraphic: fixmystreet.pin_prefix + "pin-spot.png",
    //     fillColor: "#55BB00",
    //     graphicWidth: 48,
    //     graphicHeight: 64,
    //     graphicXOffset: -24,
    //     graphicYOffset: -56,
    //     backgroundGraphic: fixmystreet.pin_prefix + "pin-shadow.png",
    //     backgroundWidth: 60,
    //     backgroundHeight: 30,
    //     backgroundXOffset: -7,
    //     backgroundYOffset: -22,
    //     popupYOffset: -40,
    //     graphicOpacity: 1.0
    // }),
    // 'temporary': new OpenLayers.Style({
    //     fillColor: "#55BB00",
    //     fillOpacity: 0.8,
    //     strokeColor: "#000000",
    //     strokeOpacity: 1,
    //     strokeWidth: 2,
    //     pointRadius: 8,
    //     cursor: 'pointer'
    // })
});


$(fixmystreet.add_assets($.extend(true, {}, fixmystreet.maps.banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "LLPG"
        }
    },
    max_resolution: 0.5971642833948135,
    min_resolution: 0.5971642833948135,
    stylemap: llpg_stylemap,
    non_interactive: true,
    always_visible: true
})));

})();
