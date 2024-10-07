var fixmystreet = fixmystreet || {};

fixmystreet.geolocate = function(element, success_callback) {
    element.addEventListener('click', function(e) {
        var link = this;
        e.preventDefault();
        link.className += ' loading';
        navigator.geolocation.getCurrentPosition(function(pos) {
            link.className = link.className.replace(/loading/, ' ');
            success_callback(pos);
        }, function(err) {
            link.className = link.className.replace(/loading/, ' ');
            if (err.code === 1) { // User said no
                link.innerHTML = translation_strings.geolocation_declined;
            } else if (err.code === 2) { // No position
                link.innerHTML = translation_strings.geolocation_no_position;
            } else if (err.code === 3) { // Too long
                link.innerHTML = translation_strings.geolocation_no_result;
            } else { // Unknown
                link.innerHTML = translation_strings.geolocation_unknown;
            }
        }, {
            enableHighAccuracy: true,
            timeout: 10000
        });
    });
};

(function() {
    var links = document.getElementsByClassName('js-geolocate-link');
    if (!links.length) { return; }
    var https = window.location.protocol.toLowerCase() === 'https:';
    if ('geolocation' in navigator && https && window.addEventListener) {
        Array.prototype.forEach.call(links, function(link) {
            fixmystreet.geolocate(link, function(pos) {
                var latitude = pos.coords.latitude.toFixed(6);
                var longitude = pos.coords.longitude.toFixed(6);
                var coords = 'lat=' + latitude + '&lon=' + longitude;
                location.href = link.href + (link.href.indexOf('?') > -1 ? ';' : '?') + coords;
            });
        });
    } else {
        Array.prototype.forEach.call(links, function(link) {
            link.style.display = 'none';
        });
    }
})();
