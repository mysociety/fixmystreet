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
var x, y;
var tile_x, tile_y;
var tilewidth = 254;
var tileheight = 254;

function onLoad() {
    //var Log = new YAHOO.widget.LogReader();
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
    x = parseInt(form.x.value, 10) - 2; /* Bottom left corner X,Y */
    y = parseInt(form.y.value, 10) - 2;
    tile_x = 0;
    tile_y = 0;
    var url = '/tilma/tileserver/10k-full-london/' + x + '-' + (x+5) + ',' + y + '-' + (y+5) + '/JSON?';
    var req = YAHOO.util.Connect.asyncRequest('GET', url, urls_loaded, null);
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
        update_tiles(x, y);
	var pins = YAHOO.util.Dom.getElementsByClassName('pin', 'img', 'content');
        myAnim = new YAHOO.util.Motion('drag', { points:{by:[x,y]} }, 1, YAHOO.util.Easing.easeBoth);
	myAnim.animate();
	for (var p in pins) {
            var a = new YAHOO.util.Anim(pins[p], { right:{by:-x}, top:{by:y} }, 1, YAHOO.util.Easing.easeBoth);
            a.animate();
	}
    }
}

var drag_x = 0;
var drag_y = 0;
function update_tiles(dx, dy) {
    drag_x += dx;
    drag_y += dy;

    var newcols = {};
    var horizontal = 0;
    var vertical = 0;
    for (var i=0; i<6; i++) {
        for (var j=0; j<6; j++) {
	    var id = i+'.'+j;
	    var img = document.getElementById(id);
            if (drag_x + img.offsetLeft > 762) {
                //img.src = '/i/grey.gif';
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

    var form = document.getElementById('mapForm');
    form.x.value = x + 2;
    form.y.value = y + 2;

    var url = '/tilma/tileserver/10k-full-london/' + x + '-' + (x+5) + ',' + y + '-' + (y+5) + '/JSON';
    var req = YAHOO.util.Connect.asyncRequest('GET', url, urls_loaded, null);
}

// Load 6x6 grid of tiles around current 2x2
var urls_loaded = {
    success: function(o) {
        var tiles = eval(o.responseText);
	var drag = document.getElementById('drag');
	for (var i=0; i<6; i++) {
	    var ii = (i + tile_y) % 6;
	    for (var j=0; j<6; j++) {
	        var jj = (j + tile_x) % 6;
	        var id = ii+'.'+jj;
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

