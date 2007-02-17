/*
 * js.js
 * Neighbourhood Fix-It JavaScript
 * 
 * TODO
 * Investigate jQuery
 * Tidy it all up
 * Selection of pin doesn't really need a server request, but I don't really care
 * 
 */

function compass_pan(e, a) {
    YAHOO.util.Event.preventDefault(e);
    pan(a.x, a.y);
}

YAHOO.util.Event.onContentReady('compass', function() {
    var ua=navigator.userAgent.toLowerCase();
    if (document.getElementById('mapForm') && /safari/.test(ua)) return;

    var points = this.getElementsByTagName('a');
    YAHOO.util.Event.addListener(points[1], 'click', compass_pan, { x:0, y:tileheight });
    YAHOO.util.Event.addListener(points[3], 'click', compass_pan, { x:tilewidth, y:0 });
    YAHOO.util.Event.addListener(points[4], 'click', compass_pan, { x:-tilewidth, y:0 });
    YAHOO.util.Event.addListener(points[6], 'click', compass_pan, { x:0, y:-tileheight });
    YAHOO.util.Event.addListener(points[0], 'click', compass_pan, { x:tilewidth, y:tileheight });
    YAHOO.util.Event.addListener(points[2], 'click', compass_pan, { x:-tilewidth, y:tileheight });
    YAHOO.util.Event.addListener(points[5], 'click', compass_pan, { x:tilewidth, y:-tileheight });
    YAHOO.util.Event.addListener(points[7], 'click', compass_pan, { x:-tilewidth, y:-tileheight });
});

YAHOO.util.Event.onContentReady('map', function() {
    var ua=navigator.userAgent.toLowerCase();
    if (document.getElementById('mapForm') && /safari/.test(ua)) return;

    new YAHOO.util.DDMap('map');
    update_tiles(0, 0, true);
});

YAHOO.util.Event.onContentReady('mapForm', function() {
    this.onsubmit = function() {
        this.x.value = x + 2;
        this.y.value = y + 2;
        return true;
    }
});

var timer;
function email_alert_close() {
    YAHOO.util.Dom.setStyle('email_alert_box', 'display', 'none');
}
YAHOO.util.Event.onContentReady('email_alert', function() {
    YAHOO.util.Event.addListener(this, 'click', function(e) {
        YAHOO.util.Event.preventDefault(e);
        if (YAHOO.util.Dom.getStyle('email_alert_box', 'display') == 'block') {
            email_alert_close();
        } else {
            var pos = YAHOO.util.Dom.getXY(this);
            pos[0] -= 20; pos[1] += 20;
            YAHOO.util.Dom.setStyle('email_alert_box', 'display', 'block');
            YAHOO.util.Dom.setXY('email_alert_box', pos);
            document.getElementById('alert_email').focus();
        }
    });
    YAHOO.util.Event.addListener(this, 'mouseout', function(e) {
        timer = window.setTimeout(email_alert_close, 2000);        
    });
    YAHOO.util.Event.addListener(this, 'mouseover', function(e) {
        window.clearTimeout(timer);
    });
});
YAHOO.util.Event.onContentReady('email_alert_box', function() {
    YAHOO.util.Event.addListener(this, 'mouseout', function(e) {
        timer = window.setTimeout(email_alert_close, 2000);        
    });
    YAHOO.util.Event.addListener(this, 'mouseover', function(e) {
        window.clearTimeout(timer);
    });
});

// I love the global
var tile_x = 0;
var tile_y = 0;
var tilewidth = 254;
var tileheight = 254;

var myAnim;
function pan(x, y) {
    if (!myAnim || !myAnim.isAnimated()) {
        myAnim = new YAHOO.util.Motion('drag', { points:{by:[x,y]} }, 10, YAHOO.util.Easing.easeOut);
        myAnim.useSeconds = false;
        myAnim.onTween.subscribe(function(){ update_tiles(x/10, y/10, false); });
        myAnim.onComplete.subscribe(function(){ cleanCache(); });
        myAnim.animate();
    }
}

function update_tiles(dx, dy, force) {
    dx = getInt(dx); dy = getInt(dy);
    if (!dx && !dy && !force) return;

    var old_drag_x = drag_x;
    var old_drag_y = drag_y;
    drag_x += dx;
    drag_y += dy;

    var drag = document.getElementById('drag');
    drag.style.left = drag_x + 'px';
    drag.style.top = drag_y + 'px';

    var horizontal = Math.floor(old_drag_x/tilewidth) - Math.floor(drag_x/tilewidth);
    var vertical = Math.floor(old_drag_y/tileheight) - Math.floor(drag_y/tileheight);
    if (!horizontal && !vertical && !force) return;

    x += horizontal;
    tile_x += horizontal;
    y -= vertical;
    tile_y += vertical;

    var url = '/tilma/tileserver/10k-full/' + x + '-' + (x+5) + ',' + y + '-' + (y+5) + '/JSON';
    var req = YAHOO.util.Connect.asyncRequest('GET', url, {
        success: urls_loaded, failure: urls_not_loaded,
        argument: [tile_x, tile_y]
    });
}

function urls_not_loaded(o) { /* Nothing yet */ }

// Load 6x6 grid of tiles around current 2x2
function urls_loaded(o) {
    var tiles = eval(o.responseText);
    var drag = document.getElementById('drag');
    for (var i=0; i<6; i++) {
        var ii = (i + o.argument[1]);
        for (var j=0; j<6; j++) {
            if (tiles[i][j] == null) continue;
            var jj = (j + o.argument[0]);
            var id = 't'+ii+'.'+jj;
            var xx = x+j;
            var yy = y+5-i;
            var img = document.getElementById(id);
            if (img) {
                if (!img.galleryimg) { img.galleryimg = false; }
                img.onclick = drag_check;
                tileCache[id] = { x: xx, y: yy, t: img };
                continue;
            }
            img = cloneNode();
            img.style.top = ((ii-2)*tileheight) + 'px';
            img.style.left = ((jj-2)*tilewidth) + 'px';
            img.name = 'tile_' + xx + '.' + yy;
            img.id = id;
            if (browser) {
                img.style.visibility = 'hidden';
                img.onload=function() { this.style.visibility = 'visible'; }
            }
            img.src = 'http://tilma.mysociety.org/tileserver/10k-full/' + tiles[i][j];
            tileCache[id] = { x: xx, y: yy, t: img };
            drag.appendChild(img);
        }
    }
}

var imgElCache;
function cloneNode() {
    var img = null;
    if (!imgElCache) {
        var form = document.getElementById('mapForm');
        if (form) {
            img = imgElCache = document.createElement('input');
            img.type = 'image';
        } else {
            img = imgElCache = document.createElement('img');
        }
        img.onclick = drag_check;
        img.style.position = 'absolute';
        img.style.width = tilewidth + 'px';
        img.style.height = tileheight + 'px';
        img.galleryimg = false;
        img.alt = 'Loading...';
    } else {
        img = imgElCache.cloneNode(true);
    }
    return img;
}

var tileCache=[];
function cleanCache() {
    for (var i in tileCache) {
        if (tileCache[i].x < x || tileCache[i].x > x+5 || tileCache[i].y < y || tileCache[i].y > y+5) {
            var t = tileCache[i].t;
            t.parentNode.removeChild(t); // de-leak?
            delete tileCache[i];
        }
    }
}

/* Called every mousemove, so on first call, overwrite itself with quicker version */
function get_posn(ev) {
    var posx, posy;
    if (ev.pageX || ev.pageY) {
        get_posn = function(e) {
            return { x: e.pageX, y: e.pageY };
        };
    } else if (ev.clientX || ev.clientY) {
        get_posn = function(e) {
            return {
                x: e.clientX + document.body.scrollLeft + document.documentElement.scrollLeft,
                y: e.clientY + document.body.scrollTop + document.documentElement.scrollTop
            };
        };
    } else {
        get_posn = function(e) {
            return { x: undef, y: undef };
        };
    }
    return get_posn(ev);
}

function setCursor(s) {
    var drag = document.getElementById('drag');
    var inputs = drag.getElementsByTagName('input');
    for (var i=0; i<inputs.length; i++) {
        inputs[i].style.cursor = s;
    }
}

var in_drag = false;
function drag_check(e) {
    if (in_drag) {
        in_drag = false;
        return false;
    }
    return true;
}

/* Simpler version of DDProxy */
var mouse_pos = {};
YAHOO.util.DDMap = function(id, sGroup, config) {
    this.init(id, sGroup, config);
};
YAHOO.extend(YAHOO.util.DDMap, YAHOO.util.DD, {
    scroll: false,
    b4MouseDown: function(e) { },
    startDrag: function(x, y) {
        mouse_pos = { x: x, y: y };
        setCursor('move');
        in_drag = true;
    },
    b4Drag: function(e) { },
    onDrag: function(e) {
        var point = get_posn(e);
        if (point == mouse_pos) return false;
        var dx = point.x-mouse_pos.x;
        var dy = point.y-mouse_pos.y;
        mouse_pos = point;
        update_tiles(dx, dy, false);
    },
    endDrag: function(e) {
        setCursor('crosshair');
        cleanCache();
    },
    toString: function() {
        return ("DDMap " + this.id);
    }
});

var browser = 1;
var ua=navigator.userAgent.toLowerCase();
if (!/opera|safari|gecko/.test(ua) && typeof document.all!='undefined')
    browser=0;

function getInt(n) {
    n = parseInt(n); return (isNaN(n) ? 0 : n);
}

