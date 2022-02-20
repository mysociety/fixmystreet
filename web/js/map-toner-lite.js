fixmystreet.maps.config = function() {
    fixmystreet.maps.controls.unshift( new OpenLayers.Control.AttributionFMS() );

    fixmystreet.layer_options = [ {
        maxResolution: 156543.03390625/Math.pow(2, fixmystreet.zoomOffset)
    } ];
    fixmystreet.layer_name = 'toner-lite';

    // The Stamen JS returns HTTP urls, fix that
    stamen.tile.getProvider('toner-lite').url = 'https://stamen-tiles-{S}a.ssl.fastly.net/toner-lite/{Z}/{X}/{Y}.png';
};
