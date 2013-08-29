/**
 * Position the map box correctly on window resize.
 *
 * Called from fixmystreet.js when the window 'resize' event is fired
 * and the page is transitioning to a desktop version.
 */
function position_map_box() {
    var $html = $('html');
    var oxfordshire_right;
    if ($html.hasClass('ie6') || $html.hasClass('ie7')) {
        oxfordshire_right = '-480px';
    } else {
        oxfordshire_right = '0em';
    }

    var map_box_width = "956px";
    var map_box_height = "600px";
    // Do the same as CSS (in case resized from mobile).
    $('#map_box').prependTo('.wrapper').css({
        zIndex: 1, position: 'absolute',
        top: '1em', left: '', right: oxfordshire_right, bottom: '',
        width: map_box_width, height: map_box_height,
        margin: "0 1em"
    });
}

function map_fix() {}
var slide_wards_down = 1;
