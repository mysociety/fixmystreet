var fixmystreet = fixmystreet || {};

(function(){

    var map_data = document.getElementById('js-map-data'),
        map_keys = [ 'area', 'all_pins', 'latitude', 'longitude', 'zoomToBounds', 'zoom', 'pin_prefix', 'pin_new_report_colour', 'numZoomLevels', 'zoomOffset', 'map_type', 'key' ],
        numeric = { zoom: 1, numZoomLevels: 1, zoomOffset: 1, id: 1 },
        pin_keys = [ 'lat', 'lon', 'colour', 'id', 'title', 'type' ];

    if (!map_data) {
        return;
    }

    $.each(map_keys, function(i, key) {
        fixmystreet[key] = map_data.getAttribute('data-' + key);
        if (numeric[key]) {
            fixmystreet[key] = +fixmystreet[key];
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
        $.each(pin_keys, function(i, key) {
            var val = pin.getAttribute('data-' + key);
            if (numeric[key]) {
                val = +val;
            }
            arr.push(val);
        });
        fixmystreet.pins.push(arr);
    });

})();
