// A minimized version of this is inline in the header.
// Note the commented out IF to pass the git hook; this
// needs adapting/including in the minimized version.

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
    if (type === 'mobile') {
        E.className += ' mobile';
//        [% IF page == "around" || page == "new" ~%]
        var isShortScreen = Modernizr.mq('(max-height: 30em)');
        if (!isShortScreen) {
            E.className += ' map-fullscreen only-map map-reporting';
        }
//        [%~ END %]
    }
})(document);
