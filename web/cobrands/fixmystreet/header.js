// A minimized version of this is inline in the header.

var fixmystreet = fixmystreet || {};

(function(D){
    var E = D.documentElement;
    E.className = E.className.replace(/\bno-js\b/, 'js');
    var ie8 = E.className.indexOf('ie8') > -1;
    var type = Modernizr.mq('(min-width: 48em)') || ie8 ? 'desktop' : 'mobile';
    var meta = D.getElementById('js-meta-data');
    if ('IntersectionObserver' in window) {
        E.className += ' lazyload';
    }
    fixmystreet.page = meta.getAttribute('data-page');
    fixmystreet.cobrand = meta.getAttribute('data-cobrand');
    if (type == 'mobile') {
        E.className += ' mobile';
        if (fixmystreet.page == 'around') {
            E.className += ' map-fullscreen only-map map-reporting';
        }
    }
})(document);
