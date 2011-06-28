/*
 * fixmystreet.js
 * FixMyStreet JavaScript
 */


YAHOO.util.Event.onContentReady('pc', function() {
    if (this.id && this.value == this.defaultValue) {
        this.focus();
    }
});

YAHOO.util.Event.onContentReady('mapForm', function() {
    this.onsubmit = function() {
        if (this.submit_problem) {
            this.onsubmit = function() { return false; };
        }

        /* XXX Should be in Tilma code only */
        if (this.x) {
            this.x.value = fixmystreet.x + 3;
            this.y.value = fixmystreet.y + 3;
        }

        return true;
    }
});

YAHOO.util.Event.onContentReady('another_qn', function() {
    if (!document.getElementById('been_fixed_no').checked && !document.getElementById('been_fixed_unknown').checked) {
        YAHOO.util.Dom.setStyle(this, 'display', 'none');
    }
    YAHOO.util.Event.addListener('been_fixed_no', 'click', function(e) {
        YAHOO.util.Dom.setStyle('another_qn', 'display', 'block');
    });
    YAHOO.util.Event.addListener('been_fixed_unknown', 'click', function(e) {
        YAHOO.util.Dom.setStyle('another_qn', 'display', 'block');
    });
    YAHOO.util.Event.addListener('been_fixed_yes', 'click', function(e) {
        YAHOO.util.Dom.setStyle('another_qn', 'display', 'none');
    });
});

var timer;
function email_alert_close() {
    YAHOO.util.Dom.setStyle('email_alert_box', 'display', 'none');
}
YAHOO.util.Event.onContentReady('email_alert', function() {
    YAHOO.util.Event.addListener(this, 'click', function(e) {
        if (!document.getElementById('email_alert_box'))
            return true;
        YAHOO.util.Event.preventDefault(e);
        if (YAHOO.util.Dom.getStyle('email_alert_box', 'display') == 'block') {
            email_alert_close();
        } else {
            var pos = YAHOO.util.Dom.getXY(this);
            pos[0] -= 20; pos[1] += 20;
            YAHOO.util.Dom.setStyle('email_alert_box', 'display', 'block');
            YAHOO.util.Dom.setXY('email_alert_box', pos);
            document.getElementById('alert_rznvy').focus();
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

