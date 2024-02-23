(function(){

if (!fixmystreet.maps) {
    return;
}

// Track open popup for defect pins
var defect_popup;

function show_defect_popup(feature) {
    defect_popup = new OpenLayers.Popup.FramedCloud(
        "gccDefects",
        feature.geometry.getBounds().getCenterLonLat(),
        null,
        feature.attributes.title.replace("\n", "<br />"),
        { size: new OpenLayers.Size(0, 0), offset: new OpenLayers.Pixel(6, -46) },
        true,
        close_defect_popup
    );
    fixmystreet.map.addPopup(defect_popup);

    // On mobile the popup is obscured by the crosshairs, so hide them (and
    // the "Start new report here" button) when the popup is shown
    if ($('html').hasClass('mobile')) {
        $(".map-crosshairs, .map-mobile-report-button").addClass("hidden");

        // after a short delay (to ignore any `maps:click` events that trigger
        // during the current handler code) add a callback to close the popup
        // when the map is clicked.
        window.setTimeout(function() {
            $(fixmystreet).on('maps:click', close_defect_popup);
        }, 500);
    }
}

function close_defect_popup() {
    if (!!defect_popup) {
        fixmystreet.map.removePopup(defect_popup);
        defect_popup.destroy();
        defect_popup = null;
    }

    if ($('html').hasClass('mobile')) {
        // Don't forget to restore the crosshair/new report button
        $(".map-crosshairs, .map-mobile-report-button").removeClass("hidden");

        // and remove the callback handler for clicking the map
        $(fixmystreet).off('maps:click', close_defect_popup);
    }
}

// Handle clicks on defect pins when showing duplicates
function setup_defect_popup() {
    var select_defect = new OpenLayers.Control.SelectFeature(
        fixmystreet.markers,
        {
            hover: true,
            clickFeature: function (feature) {
                close_defect_popup();
                if (feature.attributes.id >= 0) {
                    // We're only interested in defects
                    return;
                }
                show_defect_popup(feature);
            }
        }
    );
    fixmystreet.map.addControl(select_defect);
    select_defect.activate();
}

function handle_marker_click(e, feature) {
    close_defect_popup();

    // Show popups for defects, which have negative fake IDs
    if (feature.attributes.id < 0) {
        show_defect_popup(feature);
    }
}

$(fixmystreet).on('maps:render_duplicates', setup_defect_popup);
$(fixmystreet).on('maps:marker_click', handle_marker_click);

if (!$('html').hasClass('mobile')) {
    // Prevent the popup being closed as soon as it's opened on mobile.
    // Mobile reports are started with the crosshair & button so no
    // need to deal with getting the popup out of the way.
    $(fixmystreet).on('maps:click', close_defect_popup);
}

$(function() {
    if (fixmystreet.page == 'reports') {
        // Refresh markers on page load so that defects are loaded in over AJAX.
        fixmystreet.markers.events.triggerEvent('refresh');
    }
});

})();
