// A minimized version of this is inline in the header.

var fixmystreet = fixmystreet || {};
fixmystreet.page = '[% page %]';
fixmystreet.cobrand = '[% c.cobrand.moniker %]';

(function(D){
    var E = D.documentElement;
    E.className = E.className.replace(/\bno-js\b/, 'js');
    var ie8 = E.className.indexOf('ie8') > -1;
    var type = Modernizr.mq('(min-width: 48em)') || ie8 ? 'desktop' : 'mobile';
    if ('IntersectionObserver' in window) {
        E.className += ' lazyload';
    }
    if (type == 'mobile') {
        E.className += ' mobile[% " map-fullscreen only-map map-reporting" IF page == "around" %]';
    }
})(document);
