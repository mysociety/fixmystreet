/*
 *  message_manager.config(settings)
 *
 * Accepts settings for the Message Manager client. Even if you accept all the defaults,
 * you *must* call config when the page is loaded (i.e., call message_manager.config())
 *
 * The (optional) single parameter is a hash of name-value pairs:
 *
 *     url_root           accepts the root URL to the message manager.
 *
 *     want_unique_locks  normally MM clients should relinquish all other locks 
 *                        when claiming a new one so want_unique_locks defaults 
 *                        to true; but you can set it explicitly here.
 *
 *     msg_prefix         all message <li> items have this as their ID prefix
 *
 *     *_selector         these are the jQuery selects that will be used to find
 *                        the respective elements:
 *
 *                              message_list_selector: list of messages
 *                              status_selector:       status message display
 *                              login_selector:        login form 
 *
 *
 *   Summary of all methods:
 *   message_manager.config([options])
 *   message_manager.setup_click_listener([options])
 *   message_manager.get_available_messages([options])
 *   message_manager.request_lock(msg_id, [options])  (default use: client code doesn't need to call this explicitly)
 *   message_manager.assign_fms_id(msg_id, fms_id, [options])
 *
 *  Note: options are {name:value, ...} hashes and often include "callback" which is a function that is executed on success.
 *  Some methods take 'callback' as the only option, but you still need to pass it explicitly.
*/



var message_manager = new function() {

    // default/config values: can be overridden using "config({name:value, ...})"

    var url_root              = 'http://www.example.com/message_manager/';
    var want_unique_locks     = true; 
    var msg_prefix            = "msg-";
    var username;

    // cached jQuery elements, populated by the (mandatory) call to config()
    var $message_list_element;
    var $status_element;
    var $login_element;
    var $htauth_username;
    var $htauth_password;

    this.config = function(settings) {
        var selectors = {
            message_list_selector:    '#mm-message-list',
            status_selector:          '#mm-status-message-container',
            login_selector:           '#mm-login-container',
            username_selector:        '#mm-received-username',
            htauth_username_selector: '#mm-htauth-username',
            htauth_password_selector: '#mm-htauth-password'
        };
        if (settings) {
            if (typeof settings.url_root === 'string') {
                url_root = settings.url_root;
            }
            if (typeof settings.want_unique_locks !== 'undefined') {
                want_unique_locks = settings.want_unique_locks;
            }
            if (typeof settings.msg_prefix === 'string') {
                want_unique_locks = settings.msg_prefix;
            }
            for (var sel in selectors) {
                if (typeof settings[sel] === 'string') {
                    selectors[sel] = settings[sel];
                }
            }
        }
        $message_list_element = $(selectors.message_list_selector);
        $status_element = $(selectors.status_selector);
        $login_element = $(selectors.login_selector);
        $htauth_username = $(selectors.htauth_username_selector);
        $htauth_password = $(selectors.htauth_password_selector);
    };

    // btoa doesn't work on all browers?
    function make_base_auth(user, password) {
        var tok = user + ':' + password;
        var hash = btoa(tok);
        return "Basic " + hash;
    }

    function getCurrentAuthCredentials() {
        var base_auth = "";
        if ($htauth_username.val().length === 0 && Modernizr.localstorage) {
            base_auth = localStorage.mm_auth === undefined? "" : localStorage.mm_auth;
        } else {
            base_auth = make_base_auth(
                $htauth_username.val(),
                $htauth_password.val()
            );
            if (Modernizr.localstorage) {
                localStorage.mm_auth = base_auth;
            }
        }
        return base_auth;
    }

    function showLoginForm() {
        $('.mm-msg', $message_list_element).remove(); // remove (old) messages
        $login_element.stop().slideDown();
    }

    function say_status(msg) {
        if ($status_element) {
            $status_element.stop().show().text(msg);
        }
    }

    this.show_available_messages = function(data) {
        var messages = data.messages;
        username = data.username;        
        var $output = $message_list_element;
        if (messages instanceof Array) {
            if (messages.length === 0) {
                $output.html('<p>No messages available.</p>');
            } else {
                var $ul = $('<ul/>');
                for(var i=0; i< messages.length; i++) {
                    var msg = messages[i].Message; // or use label value
                    var lockkeeper = messages[i].Lockkeeper.username;
                    var escaped_text = $('<div/>').text(msg.message).html();
                    var tag = (!msg.tag || msg.tag === 'null')? '&nbsp;' : msg.tag;
                    tag = $('<span class="msg-tag"/>').html(tag);
                    var radio = $('<input type="radio"/>').attr({
                        'id': 'mm_text_' + msg.id,
                        'name': 'mm_text',
                        'value': escaped_text
                    }).wrap('<p/>').parent().html();
                    var label = $('<label/>', {
                        'class': 'msg-text',
                        'for': 'mm_text_' + msg.id
                    }).text(escaped_text).wrap('<p/>').parent().html();
                    var p = $('<p/>').append(tag).append(radio).append(label);
                    var litem = $('<li id="' + msg_prefix + msg.id + '" class="mm-msg">').append(p);
                    if (lockkeeper) {
                        litem.addClass(lockkeeper == username? 'msg-is-owned' : 'msg-is-locked'); 
                    }
                    $ul.append(litem);
                }
                $output.empty().append($ul);
            }
        } else {
            $output.html('<p>No messages (server did not send a list).</p>');
        }
    };

    // accept an element (e.g., message_list) and add the click event to the *radio button* within it
    // A bit specific to expect li's perhaps.
    // options are passed through to the lock 
    this.setup_click_listener = function(options) {
        $message_list_element.on('click', 'input[type=radio]', function(event) {
            var $li = $(this).closest('li');
            var id = $li.attr('id').replace(msg_prefix, '');
            if ($li.hasClass('msg-is-locked')) {
                say_status("Trying for lock...");
            } else if ($li.hasClass('msg-is-owned')) {
                say_status("Checking lock...");
            } else {
                say_status("Trying for lock...");
            }
            message_manager.request_lock(id, options);
        });
    };

    // gets messages or else requests login
    this.get_available_messages = function(options) {
        var base_auth = getCurrentAuthCredentials();
        if (base_auth === "") {
            showLoginForm();
            return;
        }
        if (options) {
            if (typeof(options.callback) === 'function') {
                callback = options.callback;
            }
        }
        $login_element.stop().hide();
        $.ajax({
            dataType: "json", 
            type:     "post", 
            url:      url_root +"messages/available.json",
            beforeSend: function (xhr){
                xhr.setRequestHeader('Authorization', getCurrentAuthCredentials());
                xhr.withCredentials = true;
            },
            success:  function(data, textStatus) {
                          message_manager.show_available_messages(data);
                          if (typeof(callback) === "function") {
                              callback.call($(this), data); // execute callback
                          }
                      }, 
            error:    function(jqXHR, textStatus, errorThrown) {
                        var st = jqXHR.status; 
                        if (st == 401 || st == 403) {
                            var msg = (st == 401)? "Invalid username or password" : "Access denied: please log in";
                            say_status(msg);
                            showLoginForm();
                        } else {
                            say_status("Error: " + st + " " + textStatus);
                        }
                      }
        });    
    };

    this.request_lock = function(msg_id, options) {
        var $li = $('#' + msg_prefix + msg_id);
        var lock_unique = want_unique_locks;
        var callback = null;
        if (options) {
            if (typeof(options.callback) === 'function') {
                callback = options.callback;
            }
            if (typeof(options.lock_unique) !== undefined && options.lock_unique !== undefined) {
                lock_unique = options.lock_unique;
            }
        }
        $li.addClass('msg-is-busy');
        $.ajax({
            dataType:"json", 
            type:"post", 
            url: url_root +"messages/" +
                (lock_unique? "lock_unique" : "lock") + 
                "/" + msg_id + ".json",
            beforeSend: function (xhr){
                xhr.setRequestHeader('Authorization', getCurrentAuthCredentials());
                xhr.withCredentials = true;
            },
            success:function(data, textStatus) { 
                if (data.success) {
                    if (lock_unique) {
                        $('.msg-is-owned', $message_list_element).removeClass('msg-is-owned');
                    }
                    $li.removeClass('msg-is-busy msg-is-locked').addClass('msg-is-owned');
                    say_status("Lock granted OK"); // to data['data']['Lockkeeper']['username']?
                } else {
                    $li.removeClass('msg-is-busy').addClass('msg-is-locked');
                    say_status("failed: " + data.error);
                }
                if (typeof(callback) === "function") { // note callbacks must check data['success']
                    callback.call($(this), data); // returned data['data'] is 'Message', 'Source', 'Lockkeeper' for success
                }
            }, 
            error: function(jqXHR, textStatus, errorThrown) {
                $li.removeClass('msg-is-busy');
                say_status("error: " + textStatus + ": " + errorThrown);
            }
        });
    };

    this.assign_fms_id = function(msg_id, fms_id, options) {
        if (options) {
            if (typeof(options.callback) === 'function') {
                callback = options['callback'];
            }
        }
        var $li = $('#' + msg_prefix + msg_id);
        if ($li.size() === 0) {
            say_status("Couldn't find message with ID " + msg_id);
            return;
        }
        if (isNaN(parseInt(fms_id,0))) {
            say_status("missing FMS id");
            return;            
        }
        $li.addClass('msg-is-busy');
        $.ajax({
            dataType:"json", 
            type:"post", 
            data:$("#assign-fms-submit").closest("form").serialize(),
            url: url_root +"messages/assign_fms_id/" + msg_id + ".json",
            beforeSend: function (xhr){
                xhr.setRequestHeader('Authorization', getCurrentAuthCredentials());
                xhr.withCredentials = true;
            },
            success:function(data, textStatus) {
                if (data.success) {
                    $li.removeClass('msg-is-busy msg-is-locked').addClass('msg-is-owned').fadeOut('slow'); // no longer available
                    say_status("FMS ID assigned"); // to data['data']['Lockkeeper']['username']?
                    if (typeof(callback) === "function") {
                        callback.call($(this), data.data); // returned data['data'] is 'Message', 'Source', 'Lockkeeper' for success
                    }
                } else {
                    $li.removeClass('msg-is-busy').addClass('msg-is-locked');
                    say_status("failed: " + data.error);
                }
            }, 
            error: function(jqXHR, textStatus, errorThrown) {
                say_status("error: " + textStatus + ": " + errorThrown);
                $li.removeClass('msg-is-busy');
            }
        });
    };
};
