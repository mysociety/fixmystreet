fixmystreet.maps.config = (function(original) {
    return function(){
        original();
        fixmystreet.map_type = OpenLayers.Layer.Bexley;
    };
})(fixmystreet.maps.config);

OpenLayers.Layer.Bexley = OpenLayers.Class(OpenLayers.Layer.BingUK, {
    get_urls: function(bounds, z) {
        if (z < 17) {
            return OpenLayers.Layer.BingUK.prototype.get_urls.apply(this, arguments);
        }

        var urls = [];
        var servers = [ '', 'a.', 'b.', 'c.' ];
        var base = "//{S}tilma.mysociety.org/bexley/${z}/${x}/${y}.png";
        for (var i=0; i < servers.length; i++) {
            urls.push( base.replace('{S}', servers[i]) );
        }
        return urls;
    },

    CLASS_NAME: "OpenLayers.Layer.Bexley"
});
