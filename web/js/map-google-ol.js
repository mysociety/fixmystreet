$(function(){
    $('#map_layer_toggle').toggle(function(){
        $(this).text(translation_strings.map_satellite);
        fixmystreet.map.setBaseLayer(fixmystreet.map.layers[1]);
    }, function(){
        $(this).text(translation_strings.map_map);
        fixmystreet.map.setBaseLayer(fixmystreet.map.layers[0]);
    });
});

function set_map_config(perm) {
    var permalink_id;
    if ($('#map_permalink').length) {
        permalink_id = 'map_permalink';
    }

    fixmystreet.controls = [
        new OpenLayers.Control.ArgParser(),
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.PermalinkFMS(permalink_id),
        new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' })
    ];

    fixmystreet.map_type = OpenLayers.Layer.Google;
    fixmystreet.map_options = {
        zoomDuration: 10
    };
    fixmystreet.layer_options = [
        { type: google.maps.MapTypeId.HYBRID },
        {}
    ];
}

