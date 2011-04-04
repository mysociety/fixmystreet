function set_map_config(perm) {
    fixmystreet.controls = [
        new OpenLayers.Control.ArgParser(),
        perm,
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.PanPanel()
    ];
    fixmystreet.map_type = OpenLayers.Layer.Tilma;
    fixmystreet.layer_options = {
        maxResolution: fixmystreet.maxResolution,
        tileSize: new OpenLayers.Size(fixmystreet.tilewidth, fixmystreet.tileheight),
        map_type: fixmystreet.tile_type,
        numZoomLevels: 1,
        zoomOffset: 0
    };
}

OpenLayers.Layer.Tilma = OpenLayers.Class(OpenLayers.Layer.XYZ, {
    initialize: function(name, options) {
        var url = "http://tilma.mysociety.org/tileserver/${type}/${x},${y}/png";
        options = OpenLayers.Util.extend({
            transitionEffect: "resize",
            numZoomLevels: 1,
            projection: "EPSG:27700",
            units: "m",
            maxExtent: new OpenLayers.Bounds(0, 0, 700000, 1300000)
        }, options);
        var newArguments = [name, url, options];
        OpenLayers.Layer.XYZ.prototype.initialize.apply(this, newArguments);
    },

    getURL: function (bounds) {
        var res = this.map.getResolution();
        var x = Math.round(bounds.left / (res * this.tileSize.w));
        var y = Math.round(bounds.bottom / (res * this.tileSize.h));
        var path = OpenLayers.String.format(this.url, {'x': x, 'y': y, 'type': this.map_type});
        return path;
    },

    CLASS_NAME: "OpenLayers.Layer.Tilma"
});
