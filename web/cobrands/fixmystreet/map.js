var fixmystreet = fixmystreet || {};

(function(){

    var map_data = document.getElementById('js-map-data'),
        map_keys = [ 'area', 'all_pins', 'latitude', 'longitude', 'zoomToBounds', 'zoom', 'pin_prefix', 'numZoomLevels', 'zoomOffset', 'map_type', 'key' ],
        numeric = { zoom: 1, numZoomLevels: 1, zoomOffset: 1 },
        pin_keys = [ 'lat', 'lon', 'colour', 'id', 'title', 'type' ];

    if (!map_data) {
        return;
    }

    $.each(map_keys, function(i, v) {
        fixmystreet[v] = map_data.getAttribute('data-' + v);
        if (numeric[v]) {
            fixmystreet[v] = +fixmystreet[v];
        }
    });

    fixmystreet.area = fixmystreet.area ? fixmystreet.area.split(',') : [];
    if (fixmystreet.map_type) {
        var s = fixmystreet.map_type.split('.');
        var obj = window;
        for (var i=0; i<s.length; i++) {
            obj = obj[s[i]];
        }
        fixmystreet.map_type = obj;
    }

    fixmystreet.pins = [];
    $('.js-pin').each(function(i, pin) {
        var arr = [];
        $.each(pin_keys, function(i, v) {
            arr.push(pin.getAttribute('data-' + v));
        });
        fixmystreet.pins.push(arr);
    });

})();
