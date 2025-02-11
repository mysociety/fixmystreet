(function(){

if (!fixmystreet.maps) {
    return;
}

// Track open popup for defect pins
var defect_popup;

function show_defect_popup(feature) {
    defect_popup = new OpenLayers.Popup.FramedCloud(
        "occDefects",
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
                if (feature.attributes.colour !== 'blue-work') {
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

// Builds date into financial year string of the form '20xx/xy'
fixmystreet.build_financial_year_string = function(date_obj) {
    var current_year = date_obj.getFullYear();
    var current_month = date_obj.getMonth();
    var current_date = date_obj.getDate();

    // The UK tax year starts on 6th April of one particular year, and runs
    // until 5th April of the next year.
    //
    // In JS, getMonth() is 0-indexed.
    // So April = 3, not 4.
    //
    // 'First half' = 6th April to end of December
    var in_first_half = (current_month == 3 && current_date >= 6) || current_month > 3;

    var year_str = '';
    if (in_first_half) {
        year_str += current_year;
        suffix = String(current_year + 1).substring(2);
        year_str += '/' + suffix;
    }
    else {
        year_str += (current_year - 1);
        suffix = String(current_year).substring(2);
        year_str += '/' + suffix;
    }

    return year_str;
};

var wfs_host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';
var proxy_base_url = "https://" + wfs_host + "/proxy/occ/";

// Roadworks
var oxfordshire_roadworks_defaults = {
    wfs_url: proxy_base_url + 'nsg/',
    wfs_feature: 'WFS_PROPOSED_SCHEMES',
    request: 'GetFeature',
    srsName: 'EPSG:27700',
    filter_key: 'FINANCIAL_YEAR_NAME',
    filter_value: [ fixmystreet.build_financial_year_string(new Date(Date.now())) ],
    format_class: OpenLayers.Format.GeoJSON,
    relevant: function(options) { if (options.category || options.group) { return true; } },
    asset_category: 1, // So that road relevant check passes, though not always_visible
    non_interactive: true,
    nearest_radius: 100,
    road: true,
    actions: {
        found: function(layer, feature) {
            roadworks_display_msg(layer, feature);
            return true;
        },
        not_found: function(layer) {
            $(".js-roadworks-oxf-page").remove();
        }
    }
};

function roadworks_display_msg(layer, feature) {
    var attr = feature.attributes;

    var $msg = $('<div id="oxhigh' + attr.WFS_PROPOSED_SCHEMES_UID + '" class="js-oxf-roadworks-message box-warning"><p>Highway Schemes are planned at this location, so you may not need to report your issue.</p></div>');

    var $dl = $("<dl></dl>").appendTo($msg);

    $dl.append($("<dt></dt>").text('Scheme Name'));
    $dl.append($("<dd></dd>").text(attr.SCHEME_NAME));

    $dl.append($("<dt></dt>").text('Highway Scheme Type'));
    $dl.append($("<dd></dd>").text(attr.TREATMENT_TYPES_NAME));

    $dl.append($("<dt></dt>").text('Scheme Status'));
    $dl.append($("<dd></dd>").text(attr.PIP_STATUS));

    $dl.append($("<dt></dt>").text('Locality'));
    $dl.append($("<dd></dd>").text(attr.LOCALITY_NAME));

    $dl.append($("<dt></dt>").text('Financial Year'));
    $dl.append($("<dd></dd>").text(attr.FINANCIAL_YEAR_NAME));

    $dl.append($("<dd></dd>").append(
        $(
            "<a href='https://www.oxfordshire.gov.uk/residents/roads-and-transport/roadworks/planned-road-maintenance'></a>"
        ).text(
            'Planned, routine and reactive road maintenance information | Oxfordshire County Council'
        )
    ));

    var id = $("#oxhigh" + attr.WFS_PROPOSED_SCHEMES_UID);
    var last_messages;
    if (id.length === 0) {
        var roadworks_page = $(".js-reporting-page.js-roadworks-page");
        if (roadworks_page.length) {
            var oxford_roadworks_messages = $(".js-oxf-roadworks-message");
            if (oxford_roadworks_messages.length) {
                oxford_roadworks_messages.after($msg);
            } else {
                last_messages = $(".js-roadworks-message");
                last_messages.after($msg);
            }
        } else {
            var oxford_roadworks_page = $(".js-reporting-page.js-roadworks-oxf-page");
            if (oxford_roadworks_page.length) {
                last_messages = $(".js-oxf-roadworks-message");
                last_messages.after($msg);
            } else {
                oxford_roadworks_page = $("<div class='js-roadworks-oxf-page'></div>");
                oxford_roadworks_page.html($msg);
                fixmystreet.pageController.addNextPage('oxfordroadworks', oxford_roadworks_page);
            }
        }
    }
}

fixmystreet.assets.add(oxfordshire_roadworks_defaults);

})();
