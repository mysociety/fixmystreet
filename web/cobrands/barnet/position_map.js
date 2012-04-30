function position_map_box() {
    var map_pos = 'absolute', map_height = '100%';
    if ($('html').hasClass('ie6')) {
        map_pos = 'absolute';
        map_height = $('.wrapper').height();
    }
    $('#map_box').prependTo('.wrapper').css({
        zIndex: 0, position: map_pos,
        top: 0, left: $('.wrapper').left,
        right: 0, bottom: $('.wrapper').bottom,
        width: '900px', height: map_height,
        margin: 0
    });
}
