// A minimized version of this is inline in the header.

var fixmystreet = fixmystreet || {};

(function(D){
    var E = D.documentElement;
    E.className = E.className.replace(/\bno-js\b/, 'js');
    var iel8 = E.className.indexOf('iel8') > -1;
    var type = Modernizr.mq('(min-width: 48em)') || iel8 ? 'desktop' : 'mobile';
    var meta = D.getElementById('js-meta-data');
    fixmystreet.page = meta.getAttribute('data-page');
    fixmystreet.cobrand = meta.getAttribute('data-cobrand');
    if (type == 'mobile') {
        E.className += ' mobile';
        if (fixmystreet.page == 'around') {
            E.className += ' map-fullscreen only-map map-reporting';
        }
    }
})(document);
