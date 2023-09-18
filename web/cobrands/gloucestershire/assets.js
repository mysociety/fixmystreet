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
}

function close_defect_popup() {
    if (!!defect_popup) {
        fixmystreet.map.removePopup(defect_popup);
        defect_popup.destroy();
        defect_popup = null;
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
$(fixmystreet).on('maps:click', close_defect_popup);

$(function() {
    if (fixmystreet.page == 'reports') {
        // Refresh markers on page load so that defects are loaded in over AJAX.
        fixmystreet.markers.events.triggerEvent('refresh');
    }
});

})();
