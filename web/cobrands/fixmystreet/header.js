// A minimized version of this is inline in the header.

var fixmystreet = fixmystreet || {};
fixmystreet.page = '[% page %]';
fixmystreet.cobrand = '[% c.cobrand.moniker %]';

(function(D){
    var E = D.documentElement;
    E.className = E.className.replace(/\bno-js\b/, 'js');
    var type = Modernizr.mq('(min-width: 48em)') ? 'desktop' : 'mobile';
    if ('IntersectionObserver' in window) {
        E.className += ' lazyload';
    }
    var isShortScreen = Modernizr.mq('(max-height: 30em)');
    if (!isShortScreen) {
        if (type === 'mobile') {
            E.className += ' mobile[% " map-fullscreen only-map map-reporting" IF page == "around" || page == "new" %]';
        }
    }
})(document);
