function set_map_config(perm) {
    fixmystreet.controls = [
        new OpenLayers.Control.ArgParser(),
        //new OpenLayers.Control.LayerSwitcher(),
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.Permalink(),
        new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' })
    ];
    fixmystreet.map_type = OpenLayers.Layer.Stamen;
    fixmystreet.layer_options = [ {
        maxResolution: 156543.03390625/Math.pow(2, fixmystreet.zoomOffset)
    } ];
    fixmystreet.layer_style = 'toner-lite';
}
