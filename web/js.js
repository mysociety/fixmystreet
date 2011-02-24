/*
 * js.js
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

        /*
        if (swfu && swfu.getStats().files_queued > 0) {
            swfu.startUpload();
            return false;
        }
        */
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

/* File upload */
/*
function doSubmit(e) {
    e = e || window.event;
    if (e.stopPropagation) e.stopPropagation();
    e.cancelBubble = true;
    try {
        if (swfu.getStats().files_queued > 0)
            swfu.startUpload();
        else
            return true;
    } catch (e) {}
    return false;
}

function uploadDone() {
    var m = document.getElementById('mapForm');
    if (m) {
        m.submit();
    } else {
        document.getElementById('fieldset').submit();
    }
}

var swfu;
var swfu_settings = {
    upload_url : "http://matthew.bci.mysociety.org/upload.cgi",
    flash_url : "http://matthew.bci.mysociety.org/jslib/swfupload/swfupload_f9.swf",
    file_size_limit : "10240",
    file_types : "*.jpg;*.jpeg;*.pjpeg",
    file_types_description : "JPEG files",
    file_upload_limit : "0",

    swfupload_loaded_handler : function() {
        var d = document.getElementById("fieldset");
        if (d) d.onsubmit = doSubmit;
    },
    file_queued_handler : function(obj) {
        document.getElementById('txtfilename').value = obj.name;
    },
    file_queue_error_handler : fileQueueError,
//upload_start_handler : uploadStartEventHandler,
    upload_progress_handler : function(obj, bytesLoaded, bytesTotal) {
        var percent = Math.ceil((bytesLoaded / bytesTotal) * 100);
        obj.id = "singlefile";
        var progress = new FileProgress(obj, this.customSettings.progress_target);
        progress.setProgress(percent);
        progress.setStatus("Uploading...");
    },
    upload_success_handler : function(obj, server_data) {
        obj.id = "singlefile";
        var progress = new FileProgress(obj, this.customSettings.progress_target);
        progress.setComplete();
        progress.setStatus("Complete!");
        if (server_data == ' ') {
            this.customSettings.upload_successful = false;
        } else {
            this.customSettings.upload_successful = true;
            document.getElementById('upload_fileid').value = server_data;
        }
    },
    upload_complete_handler : function(obj) {
        if (this.customSettings.upload_successful) {
            var d = document.getElementById('update_post');
            if (d) d.disabled = 'true';
            uploadDone();
        } else {
            obj.id = 'singlefile';
            var progress = new FileProgress(obj, this.customSettings.progress_target);
            progress.setError();
            progress.setStatus("File rejected");
            document.getElementById('txtfilename').value = '';
        }
        
    },
    upload_error_handler : uploadError,

    swfupload_element_id : "fileupload_flashUI",
    degraded_element_id : "fileupload_normalUI",
    custom_settings : {
        upload_successful : false,
        progress_target : 'fileupload_flashUI'
    }
};
*/
