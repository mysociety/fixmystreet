(function () {
    var scriptElement = document.createElement("script");
    scriptElement.type = "text/javascript";
    if (navigator.userAgent.match(/(iPhone|iPod|iPad)/)) {
	scriptElement.src = 'cordova-ios-2.1.0.js';
    } else if (navigator.userAgent.match(/Android/)) {
	scriptElement.src = 'cordova-android-2.1.0.js';
    } else {
        alert("Unknown platform - userAgent is: " + navigator.userAgent);
    }
    $('head').prepend(scriptElement);
})();
