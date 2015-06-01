function resize_map() {
    var container = $(".content").closest('.container');
    var content_width = $(".content").width();
    var width = container.width() - content_width;
    var left = ((document.body.clientWidth - width) / 2) + (content_width /2);
    $("#map_box").css({left: left, width: width+'px'});
}

function position_map_box() {
    $('#map_box').prependTo($(".content").closest('.container')).css({
        zIndex: 0,
        top: 0, right: 0, bottom: 0, left:auto,
        height: '100%', width: '50%', margin: 0
    });
    $(window).resize(resize_map);
    resize_map();
}

function map_fix() {}

var slide_wards_down = 0;
