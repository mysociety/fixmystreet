function position_map_box() {
    var map_pos = 'absolute', map_height = $('.wrapper').height();
    if ( !$('html').hasClass('ie6') && map_height < 677 ) {
        map_height = '677px';
    }
    $('#map_box').prependTo('.wrapper').css({
        zIndex: 0, position: map_pos,
        top: 1, left: $('.wrapper').left,
        right: 0, bottom: $('.wrapper').bottom + 1,
        width: '898px', height: map_height,
        margin: 0
    });
}
