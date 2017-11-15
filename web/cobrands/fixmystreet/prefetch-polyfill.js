(function(){
    function has_prefetch() {
        // IE11 + Edge support prefetch, but do not support relList.supports, sigh
        var ua = navigator.userAgent;
        if (ua.indexOf('Edge/') > -1 || ua.indexOf('Trident/7') > -1) {
            return true;
        }
        // e.g. Firefox + Chrome will pass this test, and Safari will fail.
        var l = document.createElement("link"),
            rl = l.relList;
        if (rl && rl.supports) {
            return rl.supports('prefetch');
        }
    }

    // If we don't support the <link rel="prefetch">s in the header, manually
    // prefetch them by storing them in images.
    if (!has_prefetch()) {
        var links = document.getElementsByTagName('link'),
            llen = links.length;
        for (var x = 0; x < llen; x++) {
            var link = links[x];
            if (link.nodeName === "LINK" && link.rel && link.rel === 'prefetch') {
                (new Image()).src = link.href;
            }
        }
    }
})();
