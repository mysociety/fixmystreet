function position_map_box() {
    var map_pos = 'fixed', map_height = '100%';
    if ($('html').hasClass('ie6')) {
        map_pos = 'absolute';
        map_height = $(window).height();
    }
    $('#map_box').prependTo('.wrapper').css({
        zIndex: 0, position: map_pos,
        top: 0, left: 0, right: 0, bottom: 0,
        width: '100%', height: map_height,
        margin: 0
    });
}

function map_fix() {}
var slide_wards_down = 0;
