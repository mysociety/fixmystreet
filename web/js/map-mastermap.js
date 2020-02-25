fixmystreet.maps.config = (function(original) {
    return function(){
        original();
        fixmystreet.map_type = OpenLayers.Layer.MasterMap;
    };
})(fixmystreet.maps.config);

OpenLayers.Layer.MasterMap = OpenLayers.Class(OpenLayers.Layer.BingUK, {
    get_urls: function(bounds, z) {
        if (z < 17) {
            return OpenLayers.Layer.BingUK.prototype.get_urls.apply(this, arguments);
        }

        var urls = [];
        var servers = [ '', 'a.', 'b.', 'c.' ];
        var layer = fixmystreet.staging ? 'mastermap-staging' : 'mastermap';
        var base = "//{S}tilma.mysociety.org/" + layer + "/${z}/${x}/${y}.png";
        for (var i=0; i < servers.length; i++) {
            urls.push( base.replace('{S}', servers[i]) );
        }
        return urls;
    },

    CLASS_NAME: "OpenLayers.Layer.MasterMap"
});
