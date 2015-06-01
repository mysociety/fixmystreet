function position_map_box() {
    var container = $(".content").closest('.container');
    var content_width = $(".content").width();

    var width = container.width() - content_width;
    var left = ((window.screen.width - width) / 2) + (content_width /2);
    $('#map_box').prependTo(container).css({
        zIndex: 0, position: 'fixed',
        top: 0, left: left, right: 0, bottom: 0,
        width: width+'px', height: '100%',
        margin: 0
    });
}

function map_fix() {}

var slide_wards_down = 0;
