(function(){
    if (!document.querySelector) { return; }
    if ( -1 !== navigator.userAgent.indexOf('Google Page Speed')) { return; }
    if (document.cookie.indexOf('has_seen_country_message') !== -1) { return; }

    /* Front page banner for other countries */
    var request = new XMLHttpRequest();
    request.open('GET', 'https://gaze.mysociety.org/gaze-rest?f=get_country_from_ip', true);
    request.onreadystatechange = function() {
        if (this.readyState === 4) {
            if (this.status >= 200 && this.status < 400) {
                var data = this.responseText;
                if ( data && data != 'GB\n' ) {
                    var banner = document.createElement('div');
                    banner.className = 'top_banner top_banner--country';
                    var close = document.createElement('a');
                    close.className = 'top_banner__close';
                    close.innerHTML = 'Close';
                    close.href = '#';
                    close.onclick = function(e) {
                        document.querySelector('.top_banner--country').style.display = 'none';
                        var t = new Date(); t.setFullYear(t.getFullYear() + 1);
                        document.cookie = 'has_seen_country_message=1; path=/; expires=' + t.toUTCString();
                    };
                    var p = document.createElement('p');
                    p.innerHTML = 'This site is for reporting <strong>problems in the UK</strong>. There are FixMyStreet sites <a href="http://fixmystreet.org/sites/">all over the world</a>, or you could set up your own using the <a href="http://fixmystreet.org/">FixMyStreet Platform</a>.';
                    banner.appendChild(close);
                    banner.appendChild(p);
                    document.body.insertBefore(banner, document.body.firstChild);
                    document.querySelector('.top_banner--country').style.display = 'block';
                }
            }
        }
    };
    request.send();
    request = null;

})();
