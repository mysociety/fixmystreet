function position_map_box() {
    var $html = $('html');
    if ($html.hasClass('ie6')) {
        $('#map_box').prependTo('body').css({
            zIndex: 0, position: 'absolute',
            top: 0, left: 0, right: 0, bottom: 0,
            width: '100%', height: $(window).height(),
            margin: 0
        });
    } else {
        // Move the map into the content div and remove inline CSS.
        $('#map_box').prependTo('.container > .content').removeAttr('style');
    }
}

function map_fix() {}
var slide_wards_down = 0;
