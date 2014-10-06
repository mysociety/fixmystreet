function set_map_config(perm) {
    fixmystreet.controls = [
        new OpenLayers.Control.ArgParser(),
        //new OpenLayers.Control.LayerSwitcher(),
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.Permalink(),
        new OpenLayers.Control.PanZoomFMS()
    ];
    fixmystreet.map_type = OpenLayers.Layer.Stamen;
    fixmystreet.layer_style = 'toner-lite';
}
