function position_map_box() {
    var $html = $('html');
    var bromley_right;
    if ($html.hasClass('ie6') || $html.hasClass('ie7')) {
        bromley_right = '-480px';
    } else {
        bromley_right = '0em';
    }
    // Do the same as CSS (in case resized from mobile).
    $('#map_box').prependTo('.content').css({
        zIndex: 1, position: 'absolute',
        top: '1em', left: '', right: bromley_right, bottom: '',
        width: '464px', height: '464px',
        margin: 0
    });
}

function map_fix() {}
var slide_wards_down = 1;
