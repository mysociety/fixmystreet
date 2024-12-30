fixmystreet.inspect_form_no_scroll_on_load = 1;

// Chrome ignores autocomplete="off" on the title input, and incorrectly
// autocompletes it with the user's email address. For now we'll reset the title
// to empty if it contains an email address when the user has selected a
// category. Hopefully we can get rid of this eventually if Chrome changes its
// behaviour.
fixmystreet.fixChromeAutocomplete = function() {
    var title = document.getElementById("form_title");

    if (title) {
        if (
            title.value == "" ||
            /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@(?:\S{1,63})$/.test(title.value)
        ) {
            title.value = "";
        }
    }
};

// jQuery is not imported on every page.
if (window.$) {
    $(fixmystreet).on(
        "report_new:category_change",
        fixmystreet.fixChromeAutocomplete
    );
}

// Show the app badges if the app is not a PWABuilder progressive web app from
// the iOS App Store.
if (document.cookie.indexOf("app-platform=iOS App Store") === -1) {
    var fmsAppBadges = document.getElementsByClassName("fms-app-badges")[0];

    if (fmsAppBadges) {
        fmsAppBadges.style.display = "block";
    }
}

// Hide the default PWA installation banner since it covers important UI
// elements (https://github.com/mysociety/fixmystreet/issues/4153).
// deferredPrompt could be used to provide an in-app installation flow.
var deferredPrompt;

addEventListener("beforeinstallprompt", function (event) {
    event.preventDefault();

    deferredPrompt = event;
});
