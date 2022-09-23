(function(){

if (!fixmystreet.maps) {
    return;
}

fixmystreet.assets.lincolnshire = {};
fixmystreet.assets.lincolnshire.barrier_stylemap = new OpenLayers.StyleMap({
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
fixmystreet.assets.lincolnshire.llpg_stylemap = new OpenLayers.StyleMap({
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

})();
