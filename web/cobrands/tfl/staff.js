$(function() {
    if (!fixmystreet.map) {
        return;
    }

    if (fixmystreet.page !== 'report') {
        return;
    }

    for (var i = 0; i < fixmystreet.assets.layers.length; i++) {
        var layer = fixmystreet.assets.layers[i];
        if (layer.name === 'Red Routes') {
            fixmystreet.map.addLayer(layer);
            var pins_layer = fixmystreet.map.getLayersByName("Pins")[0];
            if (pins_layer) {
                layer.setZIndex(pins_layer.getZIndex()-1);
            }
        }
    }
});
