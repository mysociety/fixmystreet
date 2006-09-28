/*
 * js.js
 * Neighbourhood Fix-It JavaScript
 * 
 * TODO
 * Updating tiles from server as they rotate around, can't seem to think of this straight...
 * Get pins to disappear when they're not over the map!
 * Try and put back dragging, I suppose
 * Selection of pin doesn't really need a server request, but I don't really care
 * Add callback to tileserver JSON, so don't have to use proxy
 * 
 */


window.onload = onLoad;

var x, y;
var tilewidth = 254;
var tileheight = 254;

function onLoad() {
    //var Log = new YAHOO.widget.LogReader();

    var compass = document.getElementById('compass');
    if (compass) {
        var points = document.getElementById('compass').getElementsByTagName('a');
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

// Load 6x6 grid of tiles around current 2x2
var urls_loaded = {
    success: function(o) {
        var tiles = eval(o.responseText);
	var drag = document.getElementById('drag');
	for (var i=0; i<6; i++) {
	    for (var j=0; j<6; j++) {
	        var id = i+'.'+j;
		var xx = x+j;
		var yy = y+5-i;
		var img = document.getElementById(id);
		if (img) {
		    if (!img.xx) img.xx = xx;
		    if (!img.yy) img.yy = yy;
		    if (!img.galleryimg) { img.galleryimg = false; }
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
		img.style.top = ((i-2)*tileheight) + 'px';
		img.style.left = ((j-2)*tilewidth) + 'px';
		img.galleryimg = false;
		img.xx = xx;
		img.yy = yy;
		img.alt = 'Loading...';
		drag.appendChild(img);
	    }
	}
    }

}
    var url = '/proxy.cgi?x=' + x + ';xm=' + (x+5) + ';y=' + y + ';ym=' + (y+5);
    var req = YAHOO.util.Connect.asyncRequest('GET', url, urls_loaded, null);
}

function image_rotate(img, x, y) {
    if (x) {
        img.style.left = (img.offsetLeft + x*tilewidth) + 'px';
	img.xx += x;
    }
    if (y) {
        img.style.top = (img.offsetTop + y*tileheight) + 'px';
	img.yy += y;
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
    // XXX Ugh, so that the server gets sent the right map co-ords. Needs more thinking about!
/*    var form = document.getElementById('mapForm');
    form.x.value += floor(x/tilewidth);
    form.y.value += floor(y/tileheight);
*/

    drag_x += dx;
    drag_y += dy;

    var newcols = {};
    for (var i=0; i<6; i++) {
        for (var j=0; j<6; j++) {
	    var id = i+'.'+j;
	    var xx = x+j;
	    var yy = y+5-i;
	    var img = document.getElementById(id);
            if (drag_x + img.offsetLeft > 762) {
	        image_rotate(img, -6, 0);
	    } else if (drag_x + img.offsetLeft < -508) {
	        image_rotate(img, 6, 0);
	    } else if (drag_y + img.offsetTop > 762) {
	        image_rotate(img, 0, -6);
	    } else if (drag_y + img.offsetTop < -508) {
	        image_rotate(img, 0, 6);
	    }
	}
    }

// XXX: Now has to fetch correct tiles from tileserver and overwrite
// correct images... Perhaps this is not right way to do it?

/*
    for (j in newcols) {
	var new_column = {
	    success: function(o) {
	        var tiles = eval(o.responseText);
		for (var i=0; i<6; i++) {
		    var tile = tiles[i][0];
		    alert(tile);
		}
	    }
	};
        var url = '/proxy.cgi?x=' + xx + ';xm=' + xx + ';y=' + y + ';ym=' + (y+5);
        var req = YAHOO.util.Connect.asyncRequest('GET', url, new_column, null);
    }
*/

}

// Floor always closer to 0
function floor(n) {
    if (n>=0) return Math.floor(n);
    else return Math.ceil(n);
}
