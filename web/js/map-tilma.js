/*
 * map-tilma.js
 * JavaScript specifically for the tilma based maps
 */

function compass_pan(e, a) {
    YAHOO.util.Event.preventDefault(e);
    if (a.home) {
        a.x = a.orig_x-drag_x;
        a.y = a.orig_y-drag_y;
    }
    pan(a.x, a.y);
}

YAHOO.util.Event.onContentReady('compass', function() {
    var ua=navigator.userAgent.toLowerCase();
    // if (document.getElementById('mapForm') && (/safari/.test(ua) || /Konqueror/.test(ua))) return;
    if (document.getElementById('map').offsetWidth > 510) return;

    var points = this.getElementsByTagName('a');
    YAHOO.util.Event.addListener(points[1], 'click', compass_pan, { x:0, y:fixmystreet.tileheight });
    YAHOO.util.Event.addListener(points[3], 'click', compass_pan, { x:fixmystreet.tilewidth, y:0 });
    YAHOO.util.Event.addListener(points[5], 'click', compass_pan, { x:-fixmystreet.tilewidth, y:0 });
    YAHOO.util.Event.addListener(points[7], 'click', compass_pan, { x:0, y:-fixmystreet.tileheight });
    YAHOO.util.Event.addListener(points[0], 'click', compass_pan, { x:fixmystreet.tilewidth, y:fixmystreet.tileheight });
    YAHOO.util.Event.addListener(points[2], 'click', compass_pan, { x:-fixmystreet.tilewidth, y:fixmystreet.tileheight });
    YAHOO.util.Event.addListener(points[6], 'click', compass_pan, { x:fixmystreet.tilewidth, y:-fixmystreet.tileheight });
    YAHOO.util.Event.addListener(points[8], 'click', compass_pan, { x:-fixmystreet.tilewidth, y:-fixmystreet.tileheight });
    YAHOO.util.Event.addListener(points[4], 'click', compass_pan, { home:1, orig_x:drag_x, orig_y:drag_y });
});

YAHOO.util.Event.onContentReady('map', function() {
    var ua=navigator.userAgent.toLowerCase();
    // if (document.getElementById('mapForm') && (/safari/.test(ua) || /Konqueror/.test(ua))) return;
    if (document.getElementById('map').offsetWidth > 510) return;
    new YAHOO.util.DDMap('map');
    update_tiles(fixmystreet.start_x, fixmystreet.start_y, true);
});


YAHOO.util.Event.addListener('hide_pins_link', 'click', function(e) {
    YAHOO.util.Event.preventDefault(e);
    if (this.innerHTML == 'Show pins') {
        YAHOO.util.Dom.setStyle('pins', 'display', 'block');
        this.innerHTML = 'Hide pins';
    } else if (this.innerHTML == 'Dangos pinnau') {
        YAHOO.util.Dom.setStyle('pins', 'display', 'block');
        this.innerHTML = 'Cuddio pinnau';
    } else if (this.innerHTML == 'Cuddio pinnau') {
        YAHOO.util.Dom.setStyle('pins', 'display', 'none');
        this.innerHTML = 'Dangos pinnau';
    } else if (this.innerHTML == 'Hide pins') {
        YAHOO.util.Dom.setStyle('pins', 'display', 'none');
        this.innerHTML = 'Show pins';
    }
});
YAHOO.util.Event.addListener('all_pins_link', 'click', function(e) {
    YAHOO.util.Event.preventDefault(e);
    YAHOO.util.Dom.setStyle('pins', 'display', 'block');
    var welsh = 0;
    if (this.innerHTML == 'Include stale reports') {
        this.innerHTML = 'Hide stale reports';
        fixmystreet.all_pins = 1;
        load_pins(fixmystreet.x, fixmystreet.y);
    } else if (this.innerHTML == 'Cynnwys hen adroddiadau') {
        this.innerHTML = 'Cuddio hen adroddiadau';
        fixmystreet.all_pins = 1;
        welsh = 1;
        load_pins(fixmystreet.x, fixmystreet.y);
    } else if (this.innerHTML == 'Cuddio hen adroddiadau') {
        this.innerHTML = 'Cynnwys hen adroddiadau';
        welsh = 1;
        fixmystreet.all_pins = '';
        load_pins(fixmystreet.x, fixmystreet.y);
    } else if (this.innerHTML == 'Hide stale reports') {
        this.innerHTML = 'Include stale reports';
        fixmystreet.all_pins = '';
        load_pins(fixmystreet.x, fixmystreet.y);
    }
    if (welsh) {
        document.getElementById('hide_pins_link').innerHTML = 'Cuddio pinnau';
    } else {
        document.getElementById('hide_pins_link').innerHTML = 'Hide pins';
    }
});

// I love the global
var tile_x = 0;
var tile_y = 0;

var myAnim;
function pan(x, y) {
    if (!myAnim || !myAnim.isAnimated()) {
        myAnim = new YAHOO.util.Motion('drag', { points:{by:[x,y]} }, 10, YAHOO.util.Easing.easeOut);
        myAnim.useSeconds = false;
        //myAnim.onTween.subscribe(function(){ update_tiles(x/10, y/10, false); });
        myAnim.onComplete.subscribe(function(){
            update_tiles(x, y, false);
            cleanCache();
        });
        myAnim.animate();
    }
}

var drag_x = 0;
var drag_y = 0;
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

    var horizontal = Math.floor(old_drag_x/fixmystreet.tilewidth) - Math.floor(drag_x/fixmystreet.tilewidth);
    var vertical = Math.floor(old_drag_y/fixmystreet.tileheight) - Math.floor(drag_y/fixmystreet.tileheight);
    if (!horizontal && !vertical && !force) return;
    fixmystreet.x += horizontal;
    
    tile_x += horizontal;
    fixmystreet.y -= vertical;
    tile_y += vertical;
    var url = [ root_path + '/tilma/tileserver/' + fixmystreet.tile_type + '/', fixmystreet.x, '-', (fixmystreet.x+5), ',', fixmystreet.y, '-', (fixmystreet.y+5), '/JSON' ].join('');
    YAHOO.util.Connect.asyncRequest('GET', url, {
        success: urls_loaded, failure: urls_not_loaded,
        argument: [tile_x, tile_y]
    });

    if (force) return;
    load_pins(fixmystreet.x, fixmystreet.y);
}

function load_pins(x, y) {
    if (document.getElementById('formX') && !document.getElementById('problem_submit')) {
        var ajax_params = [ 'sx=' + document.getElementById('formX').value, 
                            'sy=' + document.getElementById('formY').value, 
                            'x='  + (x+3),
                            'y='  + (y+3), 
                            'all_pins=' +  fixmystreet.all_pins ];

        var url = [ root_path , '/ajax?', ajax_params.join(';')].join('');
        YAHOO.util.Connect.asyncRequest('GET', url, {
           success: pins_loaded
        });
    }
}

function pins_loaded(o) {
    var data = eval(o.responseText);
    document.getElementById('pins').innerHTML = data.pins;
    if (typeof(data.current) != 'undefined')
        document.getElementById('current').innerHTML = data.current;
    if (typeof(data.current_near) != 'undefined')
        document.getElementById('current_near').innerHTML = data.current_near;
    if (typeof(data.fixed_near) != 'undefined')
        document.getElementById('fixed_near').innerHTML = data.fixed_near;
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
            var id = [ 't', ii, '.', jj ].join('');
            var xx = fixmystreet.x+j;
            var yy = fixmystreet.y+5-i;
            var img = document.getElementById(id);
            if (img) {
                if (!img.galleryimg) { img.galleryimg = false; }
                img.onclick = drag_check;
                tileCache[id] = { x: xx, y: yy, t: img };
                continue;
            }
            img = cloneNode();
            img.style.top = ((ii-2)*fixmystreet.tileheight) + 'px';
            img.style.left = ((jj-2)*fixmystreet.tilewidth) + 'px';
            img.name = [ 'tile_', xx, '.', yy ].join('')
            img.id = id;
            if (browser) {
                img.style.visibility = 'hidden';
                img.onload=function() { this.style.visibility = 'visible'; }
            }
            img.src = 'http://tilma.mysociety.org/tileserver/' + fixmystreet.tile_type + '/' + tiles[i][j];
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
        img.style.width = fixmystreet.tilewidth + 'px';
        img.style.height = fixmystreet.tileheight + 'px';
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
        if (tileCache[i].x < fixmystreet.x || tileCache[i].x > fixmystreet.x+5 || tileCache[i].y < fixmystreet.y || tileCache[i].y > fixmystreet.y+5) {
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

