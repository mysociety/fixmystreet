/*
 * js.js
 * Neighbourhood Fix-It JavaScript
 * 
 * TODO
 * Get pins to disappear when they're not over the map!
 * Try and put back dragging? Not sure.
 * Selection of pin doesn't really need a server request, but I don't really care
 * 
 */


window.onload = onLoad;

// I love the global
var tile_x = 0;
var tile_y = 0;
var tilewidth = 254;
var tileheight = 254;

var in_drag;
function onLoad() {
    // var Log = new YAHOO.widget.LogReader();
    var compass = document.getElementById('compass');
    if (compass) {
        var points = compass.getElementsByTagName('a');
        points[1].onclick = function() { pan(0, tileheight); return false; };
        points[3].onclick = function() { pan(tilewidth, 0); return false; };
        points[4].onclick = function() { pan(-tilewidth, 0); return false; };
        points[6].onclick = function() { pan(0, -tileheight); return false; };
        points[0].onclick = function() { pan(tilewidth, tileheight); return false; };
        points[2].onclick = function() { pan(-tilewidth, tileheight); return false; };
        points[5].onclick = function() { pan(tilewidth, -tileheight); return false; };
        points[7].onclick = function() { pan(-tilewidth, -tileheight); return false; };
    }

    var form = document.getElementById('mapForm');
    if (form) {
        form.onsubmit = form_submit;

	var drag = document.getElementById('drag');
	var inputs = drag.getElementsByTagName('input');
	for (var i=0; i<inputs.length; i++) {
		inputs[i].onclick = drag_check;
	}
	
        var url = '/tilma/tileserver/10k-full-london/' + x + '-' + (x+5) + ',' + y + '-' + (y+5) + '/JSON';
        var req = mySociety.asyncRequest(url, urls_loaded);

        var map = document.getElementById('map');
        map.onmousedown = drag_start;
        document.onmouseout = drag_end_out;

    }
}

/*
    var targ = '';
    if (!e) e = window.event;
    if (e.target) targ = e.target;
    else if (e.srcElement) targ = e.srcElement;
    if (targ.nodeType == 3) // defeat Safari bug
        targ = targ.parentNode;
*/

function form_submit() {
    this.x.value = x + 2;
    this.y.value = y + 2;
    return true;
}

function image_rotate(img, x, y) {
    if (x) {
        img.style.left = (img.offsetLeft + x*tilewidth) + 'px';
	//img.xx += x;
    }
    if (y) {
        img.style.top = (img.offsetTop + y*tileheight) + 'px';
	//img.yy += y;
    }
}

var myAnim;
function pan(x, y) {
    if (!myAnim || !myAnim.isAnimated()) {
        update_tiles(x, y, true);
        myAnim = new YAHOO.util.Motion('drag', { points:{by:[x,y]} }, 1, YAHOO.util.Easing.easeBoth);
	myAnim.animate();
    }
}

var drag_x = 0;
var drag_y = 0;
function update_tiles(dx, dy, noMove) {
    drag_x += dx;
    drag_y += dy;

    if (!noMove) {
        var drag = document.getElementById('drag');
        drag.style.left = drag_x + 'px';
        drag.style.top = drag_y + 'px';
    }

    var horizontal = 0;
    var vertical = 0;
    for (var i=0; i<6; i++) {
        for (var j=0; j<6; j++) {
	    var id = 't'+i+'.'+j;
	    var img = document.getElementById(id);
            if (drag_x + img.offsetLeft > 762) {
                img.src = '/i/grey.gif';
	        image_rotate(img, -6, 0);
		horizontal--;
	    } else if (drag_x + img.offsetLeft < -508) {
                img.src = '/i/grey.gif';
	        image_rotate(img, 6, 0);
		horizontal++;
	    }
	    if (drag_y + img.offsetTop > 762) {
                img.src = '/i/grey.gif';
	        image_rotate(img, 0, -6);
		vertical--;
	    } else if (drag_y + img.offsetTop < -508) {
                img.src = '/i/grey.gif';
	        image_rotate(img, 0, 6);
		vertical++;
	    }
	}
    }
    var horizontal = floor(horizontal/6);
    x += horizontal;
    tile_x = mod((tile_x + horizontal), 6);
    var vertical = floor(vertical/6);
    y -= vertical;
    tile_y = mod((tile_y + vertical), 6);

    var url = '/tilma/tileserver/10k-full-london/' + x + '-' + (x+5) + ',' + y + '-' + (y+5) + '/JSON';
    var req = mySociety.asyncRequest(url, urls_loaded);
}

// Load 6x6 grid of tiles around current 2x2
function urls_loaded(o) {
    if (o.readyState != 4) return;
    var tiles = eval(o.responseText);
    var drag = document.getElementById('drag');
    for (var i=0; i<6; i++) {
        var ii = (i + tile_y) % 6;
        for (var j=0; j<6; j++) {
            var jj = (j + tile_x) % 6;
	    var id = 't'+ii+'.'+jj;
	    var xx = x+j;
	    var yy = y+5-i;
	    var img = document.getElementById(id);
	    if (img) {
		if (!img.galleryimg) { img.galleryimg = false; }
                img.src = 'http://tilma.mysociety.org/tileserver/10k-full-london/' + tiles[i][j];
	        img.name = 'tile_' + xx + '.' + yy;
	        //if (!img.xx) img.xx = xx;
	        //if (!img.yy) img.yy = yy;
	        continue;
	    }
	    img = document.createElement('input');
	    img.type = 'image';
            img.src = 'http://tilma.mysociety.org/tileserver/10k-full-london/' + tiles[i][j];
	    img.name = 'tile_' + xx + '.' + yy;
	    img.id = id;
	    img.onclick = drag_check;
	    img.style.position = 'absolute';
	    img.style.width = tilewidth + 'px';
	    img.style.height = tileheight + 'px';
	    img.style.top = ((ii-2)*tileheight) + 'px';
	    img.style.left = ((jj-2)*tilewidth) + 'px';
	    img.galleryimg = false;
	    //img.xx = xx;
	    //img.yy = yy;
	    img.alt = 'Loading...';
            drag.appendChild(img);
        }
    }
}

// Floor always closer to 0
function floor(n) {
    if (n>=0) return Math.floor(n);
    return Math.ceil(n);
}

// Mod always to positive result
function mod(m, n) {
    if (m>=0) return m % n;
    return (m % n) + n;
}

/* Dragging */

var last_mouse_pos = {};
var mouse_pos = {};
function drag_move(e) {
    if (!e) var e = window.event;
    //if (e.stopPropagation) e.stopPropagation();
    var point = get_posn(e);
    in_drag = true;
    last_mouse_pos = mouse_pos;
    mouse_pos = point;
    update_tiles(mouse_pos.x-last_mouse_pos.x, mouse_pos.y-last_mouse_pos.y);
    return false;
}

function drag_check() {
    if (in_drag) {
        in_drag=false;
	return false;
    }
    return true;
}

function drag_start(e) {
    if (!e) var e = window.event;
    //if (e.stopPropagation) e.stopPropagation();
    var point = get_posn(e);
    mouse_pos = point;
    setCursor('move');
    document.onmousemove = drag_move;
    document.onmouseup = drag_end;
    return false;
}


function drag_end(e) {
    if (!e) var e = window.event;
    if (e.stopPropagation) e.stopPropagation();
    document.onmousemove = null;
    document.onmouseup = null;
    setCursor('crosshair');
    //if (in_drag) return false; // XXX I don't understand!
}

function drag_end_out(e) {
    if (!e) var e = window.event;
    //if (e.stopPropagation) e.stopPropagation();
    var relTarg;
    if (e.relatedTarget) { relTarg = e.relatedTarget; }
    else if (e.toElement) { relTarg = e.toElement; }
    if (!relTarg) {
        // mouse out to unknown = left the window?
        document.onmousemove = null;
        document.onmouseup = null;
        setCursor('crosshair');
    }
    return false;
}

function get_posn(e) {
    var posx, posy;
    if (e.pageX || e.pageY) {
        posx = e.pageX;
        posy = e.pageY;
    } else if (e.clientX || e.clientY) {
        posx = e.clientX;
        if (document.documentElement && document.documentElement.scrollLeft) {
            posx += document.documentElement.scrollLeft;
        } else {
            posx += document.body.scrollLeft;
        }
        posy = e.clientY;
        if (document.documentElement && document.documentElement.scrollTop) {
            posy += document.documentElement.scrollTop;
        } else {
            posy += document.body.scrollTop;
        }
    }
    return { x:posx, y:posy };
}

function setCursor(s) {
    var drag = document.getElementById('drag');
    var inputs = drag.getElementsByTagName('input');
    for (var i=0; i<inputs.length; i++) {
        inputs[i].style.cursor = s;
    }
}

