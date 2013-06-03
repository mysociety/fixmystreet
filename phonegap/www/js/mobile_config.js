$(document).bind("mobileinit", function(){
    $.mobile.hashListeningEnabled = false;
    $.mobile.ajaxEnabled = false;
    $.mobile.linkBindingEnabled = false;
    $.mobile.pushStateEnabled = false;
    $.mobile.ignoreContentEnabled = true;
    $.mobile.defaultPageTransition = 'slide';
    $.mobile.buttonMarkup.hoverDelay = 0;
    // turn of scrollTop support as that stops annoying post
    // transition 1 px jumps on iOS
    $.support.scrollTop = 0;
});
