fixmystreet.maps.config = function() {
    var permalink_id;
    if ($('#map_permalink').length) {
        permalink_id = 'map_permalink';
    }
    fixmystreet.controls = [
        new OpenLayers.Control.ArgParserFMS(),
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.PermalinkFMS(permalink_id),
        new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' })
    ];
    fixmystreet.layer_options = [ {
        maxResolution: 156543.03390625/Math.pow(2, fixmystreet.zoomOffset)
    } ];
    fixmystreet.layer_name = 'toner-lite';

    // The Stamen JS returns HTTP urls, fix that
    stamen.tile.getProvider('toner-lite').url = 'https://stamen-tiles-{S}a.ssl.fastly.net/toner-lite/{Z}/{X}/{Y}.png';
};
