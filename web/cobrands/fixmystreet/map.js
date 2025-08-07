var fixmystreet = fixmystreet || {};

(function(){

    var map_data = document.getElementById('js-map-data'),
        map_keys = [ 'area', 'latitude', 'longitude', 'zoomToBounds', 'zoom', 'pin_prefix', 'pin_new_report_colour', 'numZoomLevels', 'zoomOffset', 'map_type', 'aerial_url', 'bodies', 'staging', 'os_licence', 'os_key', 'os_layer', 'os_url', 'os_oml_zoom_switch', 'os_premium' ],
        numeric = { zoom: 1, numZoomLevels: 1, zoomOffset: 1, id: 1, os_oml_zoom_switch: 1, os_premium: 1 },
        bool = { draggable: 1 },
        pin_keys = [ 'lat', 'lon', 'colour', 'id', 'title', 'type', 'draggable' ];

    if (!map_data) {
        return;
    }

    $.each(map_keys, function(i, key) {
        fixmystreet[key] = map_data.getAttribute('data-' + key);
        if (numeric[key]) {
            fixmystreet[key] = +fixmystreet[key];
        }
    });


    fixmystreet.bodies = fixmystreet.bodies ? fixmystreet.utils.csv_to_array(fixmystreet.bodies)[0] : [];

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
            if (bool[key]) {
                val = !!val;
            }
            // On mobile we need to force the "new report" pin (id 0) to not be draggable
            // as it interferes with the crosshair pinpointing mechanism.
            if (key === "draggable" && $("html").hasClass("mobile") && arr[3] == 0) {
                val = false;
            }
            arr.push(val);
        });
        fixmystreet.pins.push(arr);
    });

})();
