function position_map_box() {
    var map_pos = 'absolute', map_height = $('.wrapper').height();
    // on the all reports page the height of the wrapper leads to a very
    // large map so we set a maximum size
    if ( map_height > 600 ) {
        map_height = 600;
    }
    $('#map_box').prependTo('.wrapper').css({
        zIndex: 0, position: map_pos,
        top: 1, left: $('.wrapper').left,
        right: 0, bottom: $('.wrapper').bottom + 1,
        width: '898px', height: map_height,
        margin: 0
    });
}

function map_fix() {
    var height = $('.wrapper').height() - 3;
    if ( height > 600 ) {
        height = 600;
    }
    $('#map_box').height(height);
}

var slide_wards_down = 1;
