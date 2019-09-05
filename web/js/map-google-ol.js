$(function(){
    $('#map_layer_toggle').on('click', function(e){
        e.preventDefault();
        var $t = $(this), text = $t.text();
        if (text == translation_strings.map_map) {
            $t.text(translation_strings.map_satellite);
            fixmystreet.map.setBaseLayer(fixmystreet.map.layers[0]);
        } else {
            $t.text(translation_strings.map_map);
            fixmystreet.map.setBaseLayer(fixmystreet.map.layers[1]);
        }
    });
    // jshint undef:false
    if (typeof fixmystreet_google_default !== 'undefined' && fixmystreet_google_default == 'satellite') {
        $('#map_layer_toggle').click();
    }
});

fixmystreet.maps.config = function() {
    fixmystreet.controls = [
        new OpenLayers.Control.ArgParserFMS(),
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.PermalinkFMS('map'),
        new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' })
    ];

    fixmystreet.map_type = OpenLayers.Layer.Google;
    fixmystreet.map_options = {
        zoomDuration: 10
    };

    var road_layer = {}; // Empty object defaults to standard road layer

    function apply_map_styles() {
        // jshint undef:false
        var styledMapType = new google.maps.StyledMapType(fixmystreet_google_maps_custom_style);
        // jshint undef:true
        this.mapObject.mapTypes.set('styled', styledMapType);
        this.mapObject.setMapTypeId('styled');
    }
    // If you want to apply a custom style to the road map (for example from
    // a service such as snazzymaps.com) then define that style as a top-level
    // variable called fixmystreet_google_maps_custom_style (you might have to
    // override the maps/google-ol.html template to include your own JS file)
    // and it'll automatically be applied.
    if (typeof fixmystreet_google_maps_custom_style !== 'undefined') {
        road_layer = { type: 'styled', eventListeners: { added: apply_map_styles } };
    }

    fixmystreet.layer_options = [
        road_layer,
        { type: google.maps.MapTypeId.HYBRID }
    ];
};
