window.onload = init;
function init() { map = new Map('map'); }

function Map(m) {
    // Public variables
    this.map = document.getElementById(m);
    this.pos = YAHOO.util.Dom.getXY(this.map);
    this.width = this.map.offsetWidth - 2;
    this.height = this.map.offsetHeight - 2;
    this.tilewidth = 254;
    this.tileheight = 254;
    if (this.width != 508 || this.height != 508) {
        return false;
    }
    this.point = new Point();
    this.zoomed = false;
    this.drag = this.map.getElementsByTagName('div')[0];

    // Private variables
    var drag_x = 0;
    var drag_y = 0;
    var self = this;

    // Event handlers
    this.map.onmousedown = associateObjWithEvent(this, 'drag_start');
//    this.map.ondblclick = associateObjWithEvent(this, 'centre');
    this.map.onclick = associateObjWithEvent(this, 'add_pin');
    document.onmouseout = associateObjWithEvent(this, 'drag_end_out');

    function image_rotate(img, x, y) {
        if (x) {
            img.style.left = (img.offsetLeft + x*254) + 'px';
            img.xx += x;
        }
        if (y) {
            img.style.top = (img.offsetTop + y*254) + 'px';
            img.yy += y;
        }
        var url = img.xx + '.' + img.yy + '.png';
        url = 't/' + url;
        img.src = url;
    }

    // Moving the map, loading more tiles as necessary
    this.update = function(dx, dy, noMove) {
        drag_x += dx;
        drag_y += dy;
        this.point.x = x + 1 - drag_x/this.tilewidth;
        this.point.y = y + 1 - drag_y/this.tileheight;
        if (!noMove) {
            this.drag.style.left = drag_x + 'px';
            this.drag.style.top = drag_y + 'px';
        }

        for (var i=0; i<6; i++) {
            for (var j=0; j<6; j++) {
                var id = i+'.'+j;
                var xx = x+i-2;
                var yy = y+j-2;
                var img = document.getElementById(id);
                if (img) {
                    if (!img.xx) { img.xx = xx; }
                    if (!img.yy) { img.yy = yy; }
                    if (!img.galleryimg) { img.galleryimg = false; }
                    if (drag_x + img.offsetLeft > 762) {
                        image_rotate(img, -6, 0);
                    } else if (drag_x + img.offsetLeft < -508) {
                        image_rotate(img, 6, 0);
                    } else if (drag_y + img.offsetTop > 762) {
                        image_rotate(img, 0, -6);
                    } else if (drag_y + img.offsetTop < -508) {
                        image_rotate(img, 0, 6);
                    }
                    continue;
                }
                img = document.createElement('img');
                img.id = id;
                img.style.position = 'absolute';
                img.style.width = this.tilewidth + 'px';
                img.style.height = this.tileheight + 'px';
                img.style.left = ((i-2)*self.tilewidth) + 'px';
                img.style.top = ((j-2)*self.tileheight) + 'px';
                img.galleryimg = false;
                img.xx = xx;
                img.yy = yy;
                image_rotate(img, 0, 0);
                img.alt = 'Loading...';
                this.drag.appendChild(img);
            }
        }
        return false;
    };
    this.update(0,0);

    this.add_pin = function(e, point) {
        if (this.in_drag) { this.in_drag = false; return false; }
        if (!point) point = new Point();
        m = new Pin(point.x-this.pos[0]-drag_x, point.y-this.pos[1]-drag_y);
        this.drag.appendChild(m.pin);
        return false;
    }
}

Map.prototype = {
    myAnim : null,
    in_drag : false,

    setCursor : function(s) {
        this.map.style.cursor = s;
    },

    centre : function(e, point){
        var x = -point.x + this.width/2 + this.pos[0];
        var y = -point.y + this.height/2 + this.pos[1];
        this.pan(x,y);
    },

    pan : function(x,y) {
        if (!this.myAnim || !this.myAnim.isAnimated()) {
            this.update(x,y, true);
            this.myAnim = new YAHOO.util.Motion('drag', {points: { by:[x,y] } }, 0.5, YAHOO.util.Easing.easeBoth);
            this.myAnim.animate();
        }
    },
    drag_move : function(e, point){
        this.in_drag = true;
        this.last_mouse_pos = this.mouse_pos;
        this.mouse_pos = point;
        this.update(this.mouse_pos.x-this.last_mouse_pos.x, this.mouse_pos.y-this.last_mouse_pos.y);
        return false;
    },
    drag_start : function(e, point){
        this.mouse_pos = point;
        this.setCursor('move');
        document.onmousemove = associateObjWithEvent(this, 'drag_move');
        document.onmouseup = associateObjWithEvent(this, 'drag_end');
        return false;
    },
    drag_end : function(e){
        document.onmousemove = null;
        document.onmouseup = null;
        this.setCursor('auto');
//        this.in_drag = false;
        return false;
    },
    drag_end_out : function(e){
        var relTarg;
        if (e.relatedTarget) { relTarg = e.relatedTarget; }
        else if (e.toElement) { relTarg = e.toElement; }
        if (!relTarg) {
            // mouse out to unknown = left the window?
            document.onmousemove = null;
            document.onmouseup = null;
            this.setCursor('auto');
        }
        return false;
    }

};

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
    return new Point(posx, posy);
}

function associateObjWithEvent(obj, methodName) {
    return (function(e) {
        e = e || window.event;
        var point = get_posn(e);
        return obj[methodName](e, point);
    });
}

function Point(x,y) {
    this.x = x || 0;
    this.y = y || 0;
}
Point.prototype.toString = function(){
    return "("+this.x+", "+this.y+")";
};

function Pin(x,y) {
    this.x = x || 0;
    this.y = y || 0;
    this.x -= 6;
    this.y -= 20;
    pin = document.createElement('div');
    pin.style.position = 'absolute';
    pin.style.top = this.y + 'px';
    pin.style.left = this.x + 'px';
    shadow = document.createElement('img');
    shadow.style.top = '0px';
    shadow.style.left = '0px';
    shadow.src = 'i/pin_shadow.png';
    pin.appendChild(shadow);
    img = document.createElement('img');
    img.style.top = '0px';
    img.style.left = '0px';
    img.src = 'i/pin_yellow.png';
    pin.appendChild(img);
    this.pin = pin;
}
Pin.prototype.toString = function() {
    return "("+this.x+", "+this.y+")";
}
