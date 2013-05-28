$(document).bind("mobileinit", function(){
    $.mobile.hashListeningEnabled = false;
    $.mobile.ajaxEnabled = false;
    $.mobile.linkBindingEnabled = false;
    $.mobile.pushStateEnabled = false;
    $.mobile.ignoreContentEnabled = true;
    $.mobile.defaultPageTransition = 'slide';
    $.mobile.buttonMarkup.hoverDelay = 0;
});
