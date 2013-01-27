/*
 * creates a message_manage object that uses the Message Manager API:
 * include this file, then initialise the object when the page is loaded with
 * message_manager.config(settings)
 *
 * i.e., you *must* do something like:
 *
 *   $(document).ready(function() { 
 *     message_manager.config({url_root:'http://yourdomain.com/messages'})
 *   }
 *
 * You'll need to set the url_root, but you can leave everything else to default 
 * provided your HTML ids and classes are the same as ours (which they might be:
 * see the Message Manager's dummy client (at /client) to see the HTML we use).
 *
 * The (optional) single parameter for .config() is a hash of name-value pairs:
 *
 *     url_root           accepts the root URL to the message manager.
 *
 *     want_unique_locks  normally MM clients should relinquish all other locks 
 *                        when claiming a new one so want_unique_locks defaults 
 *                        to true; but you can set it explicitly here.
 *
 *     mm_name            name of Message Manager (used in error messages shown
 *                        to user, e.g., "please log in to Message Manager")
 *
 *     msg_prefix         all message <li> items have this as their ID prefix
 *
 *     want_nice_msgs     don't use language like "lock granted"
 *
 *     tooltips           hash of tooltips: override the items you want, keys are:
 *                        tt_hide, tt_info, tt_reply, tt_radio
 *
 *     want_radio_btns    normally MM clients show a radio button, but for archive
 *                        messages this might be unneccessary: default is true, but
 *                        pass in false to suppress this.
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
 *     message_manager.config([options])
 *     message_manager.setup_click_listener([options])
 *     message_manager.get_available_messages([options])
 *     message_manager.request_lock(msg_id, [options])  (default use: client code doesn't need to call this explicitly)
 *     message_manager.assign_fms_id(msg_id, fms_id, [options])
 *     message_manager.hide(msg_id, reason_text, [options])
 *     message_manager.reply(msg_id, reply_text, [options])
 *     message_manager.show_info(msg_id)
 *     message_manager.sign_out()
 *
 *  Note: options are {name:value, ...} hashes and often include "callback" which is a function that is executed on success
 *        but see the docs (request_lock executes callback if the call is successful even if the lock was denied, for example).
 *        Some methods take 'callback' as the only option, but you still need to pass it as a named option.
*/

var message_manager = (function() {

    // default/config values: to be overridden using "config({name:value, ...})"

    var _url_root              = 'http://www.example.com/message_manager/';
    var _want_unique_locks     = true; 
    var _msg_prefix            = "msg-";
    var _username;
    var _mm_name               = "Message Manager";
    var _use_fancybox          = true; // note: currently *must* have fancybox!
    var _want_nice_msgs        = false;
    var _want_radio_btns       = true;

    var _tooltips = {
        tt_hide  : "Hide message",
        tt_info  : "Get info",
        tt_reply : "Send SMS reply",
        tt_radio : "Select message before clicking on map to create report",
        tt_detach: "Detach this message because it is not a reply"
    };

    // cached jQuery elements, populated by the (mandatory) call to config()
    var $message_list_element;
    var $status_element;
    var $login_element;
    var $htauth_username;
    var $htauth_password;
    var $hide_reasons;
    var $boilerplate_replies;

    var msg_no_config_err   = "Config error: no Message Manager URL has been specified";

    // set _want_nice_msgs to avoid using the term "lock"
    var msg_trying_for_lock = ["Trying for lock...", "Checking message..." ];
    var msg_checking_lock   = ["Checking lock...",   "Checking message..." ];
    var msg_claiming_lock   = ["Claiming lock...",   "Checking message..." ];
    var msg_lock_granted_ok = ["Lock granted OK",    "Checking message... OK"];
    var msg_lock_denied     = ["",                   "Someone is working with that message right now!"];

    function get_msg(msg) {
        return msg[_want_nice_msgs? 1 : 0];
    }

    var config = function(settings) {
        var selectors = {
            message_list_selector:    '#mm-message-list',
            status_selector:          '#mm-status-message-container',
            login_selector:           '#mm-login-container',
            username_selector:        '#mm-received-username',
            htauth_username_selector: '#mm-htauth-username',
            htauth_password_selector: '#mm-htauth-password',
            boilerplate_hide_reasons: '#mm-boilerplate-hide-reasons-box',
            boilerplate_replies:      '#mm-boilerplate-replies-box'
        };
        if (settings) {
            if (typeof settings.url_root === 'string') {
                _url_root = settings.url_root;
                if (_url_root.length > 0 && _url_root.charAt(_url_root.length-1) !== "/") {
                    _url_root+="/";
                }
            }
            if (typeof settings.want_unique_locks !== 'undefined') {
                _want_unique_locks = settings.want_unique_locks;
            }
            if (typeof settings.msg_prefix === 'string') {
                _msg_prefix = settings.msg_prefix;
            }
            for (var sel in selectors) {
                if (typeof settings[sel] === 'string') {
                    selectors[sel] = settings[sel];
                }
            }
            if (typeof settings.mm_name === 'string') {
                _mm_name = settings.mm_name;
            }
            if (typeof settings.want_nice_msgs !== 'undefined') {
                _want_nice_msgs = settings.want_nice_msgs;
            }
            if (typeof settings.want_radio_btns !== 'undefined') {
                _want_radio_btns = settings.want_radio_btns;
            }
            if (settings.tooltips) {
                for (var key in settings.tooltips) {
                    if (settings.tooltips.hasOwnProperty(key)) {
                        _tooltips[key]=settings.tooltips[key];
                    }
                }
            }
        }
        $message_list_element = $(selectors.message_list_selector);
        $status_element = $(selectors.status_selector);
        $login_element = $(selectors.login_selector);
        $htauth_username = $(selectors.htauth_username_selector);
        $htauth_password = $(selectors.htauth_password_selector);
        $hide_reasons = $(selectors.boilerplate_hide_reasons);
        $boilerplate_replies = $(selectors.boilerplate_replies);
        if (typeof settings.url_root === 'string' && _url_root.length===0) {
            say_status(msg_no_config_err);
        }
    };

    var make_base_auth = function(user, password) {
        var tok = user + ':' + password;
        var hash = encodeBase64(tok); // window.btoa(tok) doesn't work on all browers
        return "Basic " + hash;
    };
    
    function encodeBase64(input) {
        var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=',
            INVALID_CHARACTER_ERR = (function () {
                // fabricate a suitable error object
                try {
                    document.createElement('$');
                } catch (error) {
                    return error;
                }
            }()),
            block, charCode, idx, map, output;
        // encoder (with wee change by mhl Mark to satisfy jslint)
        // [https://gist.github.com/999166] by [https://github.com/nignag]
        for (idx = 0, map = chars, output = '';
             input.charAt(idx | 0) || ((map = '=') && (idx % 1));
             output += map.charAt(63 & block >> 8 - idx % 1 * 8)) {
            charCode = input.charCodeAt(idx += 3/4);
            if (charCode > 0xFF) {
                throw INVALID_CHARACTER_ERR;
            }
            block = block << 8 | charCode;
        }
        return output;
    }

    var get_current_auth_credentials = function() {
        var base_auth = "";
        var htauth_un = "";
        var htauth_pw = "";
        if ($htauth_username.size()) {
            htauth_un = $htauth_username.val();
            htauth_pw = $htauth_password.val();
        }
        if (htauth_un.length === 0 && Modernizr.sessionstorage && sessionStorage.getItem('mm_auth')) {
            base_auth = sessionStorage.getItem('mm_auth');
        } else {
            base_auth = make_base_auth(htauth_un, htauth_pw);
            if (Modernizr.sessionstorage) {
                sessionStorage.mm_auth = base_auth;
            }
        }
        return base_auth;
    };
    
    var sign_out = function() { // clear_current_auth_credentials
        if (Modernizr.sessionstorage) {
            sessionStorage.removeItem('mm_auth');
        }
        if ($htauth_password) {
            $htauth_password.val('');
        }
    };

    var show_login_form = function(suggest_username) {
        $('.mm-msg', $message_list_element).remove(); // remove (old) messages
        if ($htauth_username.size() && ! $htauth_username.val()) {
            $htauth_username.val(suggest_username);
        }
        $login_element.stop(true,true).slideDown();
    };

    var say_status = function (msg, show_spinner, allow_html) {
        if ($status_element) {
            if (show_spinner) {
                // slow fade in so that spinner only appears if there's a long delay
                $status_element.find('#mm-spinner').stop(true,true).fadeIn(1200);
            } else {
                $status_element.find('#mm-spinner').stop(true,true).hide();
            }
            $status_element.stop(true,true).show();
            if (allow_html) {
                $status_element.find('p').html(msg);
            } else {
                $status_element.find('p').text(msg);                
            }
        }
    };

    var extract_replies = function(replies, depth, is_archive) {
        var $ul = "";
        if (replies && replies.length > 0) {
            $ul = $('<ul class="mm-reply-thread"/>');
            for (var i=0; i<replies.length; i++) {
                $ul.append(get_message_li(replies[i], depth, is_archive));
            }
        }
        return $ul;
    };
    
    var get_message_li = function(message_root, depth, is_archive) {
        var msg = message_root.Message; // or use label value
        var lockkeeper = message_root.Lockkeeper.username;
        var escaped_text = $('<div/>').text(msg.message).html();
        var $p = $('<p/>');
        var $hide_button = $('<a class="mm-msg-action mm-hide" id="mm-hide-' + msg.id + '" href="#hide-form-container" title="' + _tooltips.tt_hide + '">X</a>');
        var $info_button = $('<span class="mm-msg-action mm-info" id="mm-info-' + msg.id + '" title="' + _tooltips.tt_info + '">i</span>');
        var $reply_button = $('<a class="mm-msg-action mm-rep" id="mm-rep-' + msg.id + '" href="#reply-form-container" title="' + _tooltips.tt_reply + '">reply</a>');
        var $detach_button = $('<a class="mm-msg-action mm-detach" id="mm-rep-' + msg.id + '" href="#detach-form-container" title="' + _tooltips.tt_detach + '">detach</a>');
        var is_radio_btn = _want_radio_btns && depth === 0 && ! is_archive;
        if (_use_fancybox) {
            $reply_button.fancybox();
            $hide_button.fancybox();
            $detach_button.fancybox();
        }
        if (depth === 0) {
            var tag = (!msg.tag || msg.tag === 'null')? '&nbsp;' : msg.tag;
            tag = $('<span class="msg-tag"/>').html(tag);
            var radio = null;
            if (is_radio_btn) {
                radio = $('<input type="radio"/>').attr({
                    'id': 'mm_text_' + msg.id,
                    'name': 'mm_text',
                    'value': escaped_text,
                    'title': is_radio_btn? _tooltips.tt_radio : ""
                }).wrap('<p/>').parent().html();
            } else {
                radio = $("<p>&ndash;</p>").addClass('mm-radio-filler');
            }
            var label = $('<label />').attr({
                'class': 'msg-text',
                'for': 'mm_text_' + msg.id,
                'title': is_radio_btn? _tooltips.tt_radio : ""
            }).text(escaped_text).wrap('<p/>').parent().html();
            $p.append(tag).append(radio).append(label);
        } else {
            $p.text(escaped_text).addClass('mm-reply mm-reply-' + depth);
        }
        var $litem = $('<li id="' + _msg_prefix + msg.id + '" class="mm-msg">').append($p).append($hide_button).append($info_button);
        if (depth > 0 && depth % 2 === 0) { // only even-numbered depths are incoming replies that can be detached
            $litem.append($detach_button);
        }
        if (msg.is_outbound != 1) {
          $litem.append($reply_button);
        }
        if (lockkeeper) {
            $litem.addClass(lockkeeper == _username? 'msg-is-owned' : 'msg-is-locked'); 
        }
        var info_text = "";
        if (msg.is_outbound == 1) {
            info_text = 'sent on ' + msg.created + ' by ' + msg.sender_token;
        } else {
            info_text = 'received on ' + msg.created + ' from ' + '<abbr title="'+ msg.sender_token + '">user</abbr>';
        }
        $p.append('<div class="msg-info-box" id="msg-info-box-' + msg.id + '">' + info_text + '</div>');
        if (message_root.children) {
            $litem.append(extract_replies(message_root.children, depth+1, is_archive));
        }
        return $litem;
    };
    
    var show_available_messages = function(data, anim_duration) {
        var messages = data.messages;
        _username = data.username;
        var $output = $message_list_element;
        if (anim_duration > 0) {
            $output.stop(true,true).fadeOut(anim_duration, function(){
                render_available_messages(data, anim_duration);
            });
        } else {
            render_available_messages(data, anim_duration);
        }
    };
    
    // render allows animation (if required) to hide messages before repainting and then revealing them
    var render_available_messages = function(data, anim_duration) {
        var $output = $message_list_element;
        $output.empty();
        var archive = data.messages_for_this_report;
        var $archive = "";
        var i, litem;
        if (archive instanceof Array) {
            var $arch_ul = $('<ul class="mm-root mm-archive"/>');
            for(i=0; i< archive.length; i++) {
                litem = get_message_li(archive[i], 0, true);
                $arch_ul.append(litem);
            }
            $output.append($arch_ul);
        }
        var messages = data.messages;
        _username = data.username;
        if (messages instanceof Array) {
            var $ul = $('<ul class="mm-root mm-current"/>');
            if (messages.length === 0) {
                $output.append('<p class="mm-empty">No messages available.</p>');
            } else {
                for(i=0; i< messages.length; i++) {
                    litem = get_message_li(messages[i], 0, false);
                    $ul.append(litem);
                }
            }
            $output.append($ul);
        } else {
            $output.html('<p>No messages (server did not send a list).</p>');
        }
        if (anim_duration > 0) {
            $output.slideDown(anim_duration);
        }
    };

    // accept an element (e.g., message_list) and add the click event to the *radio button* within it
    // A bit specific to expect li's perhaps.
    // options are passed through to the lock 
    var setup_click_listener = function(options) {
        $message_list_element.on('click', 'input[type=radio]', function(event) {
            var $li = $(this).closest('li');
            var id = $li.attr('id').replace(_msg_prefix, '');
            if ($li.hasClass('msg-is-locked')) {
                say_status(get_msg(msg_trying_for_lock), true);
            } else if ($li.hasClass('msg-is-owned')) {
                say_status(get_msg(msg_checking_lock), true);
            } else {
                say_status(get_msg(msg_claiming_lock), true);
            }
            request_lock(id, options);
        });
        // clicking the reply button loads the id into the (modal/fancybox) reply form
        $message_list_element.on('click', '.mm-rep', function(event) {
            $('#reply_to_msg_id').val($(this).closest('li').attr('id').replace(_msg_prefix, ''));
        });
        // clicking the hide button loads the id into the (modal/fancybox) hide form
        $message_list_element.on('click', '.mm-hide', function(event) {
            $('#hide_msg_id').val($(this).closest('li').attr('id').replace(_msg_prefix, ''));
            // $('#hide-form-message-text').val(TODO);
        });
        // clicking the detach button loads the id into the (modal/fancybox) detach form
        $message_list_element.on('click', '.mm-detach', function(event) {
            $('#detach_msg_id').val($(this).closest('li').attr('id').replace(_msg_prefix, ''));
        });
    };

    // gets messages or else requests login
    // options: suggest_username, if provided, is preloaded into the login form if provided
    //          anim_duration: duration of fade/reveal (0, by defaut, does no animation)
    //          fms_id: if provided, display an archive of messages for this username
    var get_available_messages = function(options) {
        var base_auth = get_current_auth_credentials();
        var suggest_username = "";
        var anim_duration = 0;
        var callback = null;
        var fms_id = null;
        if (options) {
            if (typeof(options.callback) === 'function') {
                callback = options.callback;
            }
            if (typeof options.suggest_username === 'string') {
                suggest_username = options.suggest_username;
            }
            if (typeof options.anim_duration === 'string' || typeof options.anim_duration === 'number') {
                anim_duration = parseInt(options.anim_duration, 10);
                if (isNaN(anim_duration)) {
                    anim_duration = 0;
                }
            }
            if (typeof options.fms_id === 'string' || typeof options.fms_id === 'number') {
                fms_id = parseInt(options.fms_id, 10);
                if (isNaN(fms_id)) {
                    fms_id = 0;
                }
            }
        }
        if (base_auth === "") {
            show_login_form(suggest_username);
            return;
        }
        $login_element.stop(true,true).hide();
        if (_url_root.length === 0) {
            say_status(msg_no_config_err);
        } else {
            var ajax_url = _url_root +"messages/available.json";
            if (fms_id) {
                ajax_url += "?fms_id=" + fms_id;
            }
            say_status("Fetching messages...", true);
            $.ajax({
                dataType: "json", 
                type:     "get", 
                url:      ajax_url,
                beforeSend: function (xhr){
                    xhr.setRequestHeader('Authorization', get_current_auth_credentials());
                    xhr.withCredentials = true;
                },
                success:  function(data, textStatus) {
                              show_available_messages(data, anim_duration);
                              say_status("Fetching messages... done, OK", false); // loaded OK
                              if (typeof(callback) === "function") {
                                  callback.call($(this), data); // execute callback
                              }
                          }, 
                error:    function(jqXHR, textStatus, errorThrown) {
                            var st = jqXHR.status;
                            var msg_is_html = false;
                            if (st == 401 || st == 403) {
                                var msg = (st == 401 ? "Invalid username or password for" : "Access denied: please log in to") + " " + _mm_name;
                                say_status(msg);
                                show_login_form(suggest_username);
                            } else {
                                var err_msg = "Unable to load messages: ";
                                if (st === 0 && textStatus === 'error') { // x-domain hard to detect, sometimes intermittent?
                                    if (_url_root.indexOf('https')===0 && ! location.protocol != 'https:') {
                                        var surl = location.href.replace(/^http:/, 'https:');
                                        err_msg += 'this is an insecure URL.<br/><a href="' + surl + '">Try from HTTPS instead?</a>';
                                        msg_is_html = true;
                                    } else {
                                        err_msg += "maybe try refreshing page?";
                                    }
                                } else {
                                    err_msg += textStatus + " (" + st + ")";
                                }
                                say_status(err_msg, false, msg_is_html);
                            }
                          }
            });
        }
    };

    var request_lock = function(msg_id, options) {
        var $li = $('#' + _msg_prefix + msg_id);
        var lock_unique = _want_unique_locks;
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
            url: _url_root +"messages/" +
                (lock_unique? "lock_unique" : "lock") + 
                "/" + msg_id + ".json",
            beforeSend: function (xhr){
                xhr.setRequestHeader('Authorization', get_current_auth_credentials());
                xhr.withCredentials = true;
            },
            success:function(data, textStatus) { 
                if (data.success) {
                    if (lock_unique) {
                        $('.msg-is-owned', $message_list_element).removeClass('msg-is-owned');
                    }
                    $li.removeClass('msg-is-busy msg-is-locked').addClass('msg-is-owned');
                    say_status(get_msg(msg_lock_granted_ok)); // to data['data']['Lockkeeper']['username']?
                } else {
                    $li.removeClass('msg-is-busy').addClass('msg-is-locked');
                    say_status(get_msg(msg_lock_denied) || ("lock failed: " + data.error));
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

    var assign_fms_id = function(msg_id, fms_id, options) {
        var check_li_exists = false;
        var is_async = true;
        var callback = null;
        if (options) {
            if (typeof(options.callback) === 'function') {
                callback = options.callback;
            }
            if (typeof(options.check_li_exists) !== undefined && options.check_li_exists !== undefined) {
                check_li_exists = true; // MM dummy
            }
            if (typeof(options.is_async) !== undefined && options.is_async !== undefined) {
                is_async = options.is_async;
            }
        }
        var $li = $('#' + _msg_prefix + msg_id);
        if (check_li_exists) {
            if ($li.size() === 0) {
                say_status("Couldn't find message with ID " + msg_id);
                return;
            }
        }
        if (isNaN(parseInt(fms_id,10))) {
            say_status("missing FMS id");
            return;            
        }
        $li.addClass('msg-is-busy');
        $.ajax({
            async:is_async,
            dataType:"json", 
            type:"post", 
            data: {fms_id: fms_id},
            url: _url_root +"messages/assign_fms_id/" + msg_id + ".json",
            beforeSend: function (xhr){
                xhr.setRequestHeader('Authorization', get_current_auth_credentials());
                xhr.withCredentials = true;
            },
            success:function(data, textStatus) {
                if (data.success) {
                    $li.removeClass('msg-is-busy msg-is-locked').addClass('msg-is-owned').fadeOut('slow'); // no longer available
                    say_status("OK: report ID was assigned to message.");
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

    var reply = function(msg_id, reply_text, options) {
        if (_use_fancybox){
            $.fancybox.close();
        }
        var callback = null;
        var check_li_exists = false;
        if (options) {
            if (typeof(options.callback) === 'function') {
                callback = options.callback;
            }
            if (typeof(options.check_li_exists) !== undefined && options.check_li_exists !== undefined) {
                check_li_exists = true; // MM dummy
            }
        }
        var $li = $('#' + _msg_prefix + msg_id);
        if (check_li_exists) {
            if ($li.size() === 0) {
                say_status("Couldn't find message with ID " + msg_id);
                return;
            }
        }
        reply_text = $.trim(reply_text);
        if (reply_text === '') {
            say_status("No reply sent: message was empty!");
            return;            
        } 
        $li.addClass('msg-is-busy');
        $.ajax({
            dataType:"json", 
            type:"post", 
            data: {reply_text: reply_text},
            url: _url_root +"messages/reply/" + msg_id + ".json",
            beforeSend: function (xhr){
                xhr.setRequestHeader('Authorization', get_current_auth_credentials());
                xhr.withCredentials = true;
            },
            success:function(data, textStatus) {
                if (data.success) {
                    $li.removeClass('msg-is-busy msg-is-locked').addClass('msg-is-owned'); // no longer available
                    say_status("Reply sent OK");
                    if (typeof(callback) === "function") {
                        callback.call($(this), data.data); // returned data['data'] is null but may change in future
                    }
                } else {
                    $li.removeClass('msg-is-busy').addClass('msg-is-locked');
                    say_status("Reply failed: " + data.error);
                }
            }, 
            error: function(jqXHR, textStatus, errorThrown) {
                say_status("Reply error: " + textStatus + ": " + errorThrown);
                $li.removeClass('msg-is-busy');
            }
        });
    };

    var hide = function(msg_id, reason_text, options) {
        if (_use_fancybox){
            $.fancybox.close();
        }
        var callback = null;
        var check_li_exists = false;
        if (options) {
            if (typeof(options.callback) === 'function') {
                callback = options.callback;
            }
            if (typeof(options.check_li_exists) !== undefined && options.check_li_exists !== undefined) {
                check_li_exists = true; // MM dummy
            }
        }
        var $li = $('#' + _msg_prefix + msg_id);
        if (check_li_exists) {
            if ($li.size() === 0) {
                say_status("Couldn't find message with ID " + msg_id);
                return;
            }
        }
        reason_text = $.trim(reason_text);
        $li.addClass('msg-is-busy');
        $.ajax({
            dataType:"json", 
            type:"post", 
            data: {reason_text: reason_text},
            url: _url_root +"messages/hide/" + msg_id + ".json",
            beforeSend: function (xhr){
                xhr.setRequestHeader('Authorization', get_current_auth_credentials());
                xhr.withCredentials = true;
            },
            success:function(data, textStatus) {
                if (data.success) {
                    $li.removeClass('msg-is-busy msg-is-locked').addClass('msg-is-owned').fadeOut('slow'); // no longer available
                    say_status("Message hidden");
                    if (typeof(callback) === "function") {
                        callback.call($(this), data.data); 
                    }
                } else {
                    $li.removeClass('msg-is-busy').addClass('msg-is-locked');
                    say_status("Hide failed: " + data.error);
                }
            }, 
            error: function(jqXHR, textStatus, errorThrown) {
                say_status("Hide error: " + textStatus + ": " + errorThrown);
                $li.removeClass('msg-is-busy');
            }
        });
    };
    
    var show_info = function(msg_id) {
        var $info = $("#msg-info-box-" + msg_id);
        if ($info.size()==1) {
            if ($info.is(':hidden')) {
                $info.slideDown();                
            } else {
                $info.slideUp();                
            }
        }
    };
    
    var mark_as_not_a_reply = function(msg_id, options) {
        if (_use_fancybox){
            $.fancybox.close();
        }
        var callback = null;
        var check_li_exists = false;
        if (options) {
            if (typeof(options.callback) === 'function') {
                callback = options.callback;
            }
            if (typeof(options.check_li_exists) !== undefined && options.check_li_exists !== undefined) {
                check_li_exists = true; // MM dummy
            }
        }
        var $li = $('#' + _msg_prefix + msg_id);
        if (check_li_exists) {
            if ($li.size() === 0) {
                say_status("Couldn't find message with ID " + msg_id);
                return;
            }
        }
        $li.addClass('msg-is-busy');
        $.ajax({
            dataType:"json", 
            type:"post", 
            data: {},
            url: _url_root +"messages/mark_as_not_a_reply/" + msg_id + ".json",
            beforeSend: function (xhr){
                xhr.setRequestHeader('Authorization', get_current_auth_credentials());
                xhr.withCredentials = true;
            },
            success:function(data, textStatus) {
                if (data.success) {
                    $li.removeClass('msg-is-busy msg-is-locked').addClass('msg-is-owned').fadeOut('slow'); // no longer available
                    say_status("Message no longer marked as a reply");
                    if (typeof(callback) === "function") {
                        callback.call($(this), data.data); 
                    }
                } else {
                    $li.removeClass('msg-is-busy').addClass('msg-is-locked');
                    say_status("Hide failed: " + data.error);
                }
            }, 
            error: function(jqXHR, textStatus, errorThrown) {
                say_status("Detach error: " + textStatus + ": " + errorThrown);
                $li.removeClass('msg-is-busy');
            }
        });
    };
    
    // if boilerplate is not already in local storage, make ajax call and load them
    // otherwise, populate the boilerplate select lists: these are currently the
    // reasons for hiding a message, and pre-loaded replies.message-manager.dev.mysociety.org
    // NB no auth required on this call
    var populate_boilerplate_strings = function(boilerplate_type, options) {
        if (Modernizr.sessionstorage && sessionStorage.getItem('boilerplate_' + boilerplate_type)) {
            populate_boilerplate(boilerplate_type, sessionStorage.getItem('boilerplate_' + boilerplate_type));
            return;
        }
        var callback = null;
        if (options) {
            if (typeof(options.callback) === 'function') {
                callback = options.callback;
            }
        }
        $.ajax({
            dataType:"json", 
            type:"get",
            url: _url_root +"boilerplate_strings/index/" + boilerplate_type + ".json",
            success:function(data, textStatus) {
                if (data.success) {
                    var raw_data = data.data;
                    var select_html = get_select_tag_html(data.data, boilerplate_type);
                    if (Modernizr.sessionstorage) {
                        sessionStorage.setItem('boilerplate_' + boilerplate_type, select_html);
                    }
                    populate_boilerplate(boilerplate_type, select_html);
                     if (typeof(callback) === "function") {
                         callback.call($(this), data.data); 
                     }
                } else {
                    // console.log("failed to load boilerplate");
                }
            }, 
            error: function(jqXHR, textStatus, errorThrown) {
                // console.log("boilerplate error: " + textStatus + ": " + errorThrown);
            }
        });
    };

    // TODO flatten all HTML in boilerplate text
    var get_select_tag_html = function(boilerplate_data, boilerplate_type) {
        var html = "<option value=''>--none--</option>\n";
        var qty_langs = 0;
        var qty_strings = 0;
        if (boilerplate_data.langs) {
            for (var i=0; i< boilerplate_data.langs.length; i++) {
                var lang = boilerplate_data.langs[i];
                var options = "";
                for (var j in boilerplate_data[lang]) {
                    if (boilerplate_data[lang].hasOwnProperty(j)) {
                        options += "<option>" + boilerplate_data[lang][j] + "</option>\n";
                        qty_strings++;
                    }
                }
                if (boilerplate_data.langs.length > 1) { // really need pretty name for language
                    options = '<optgroup label="' + lang + '">\n' + options + '</optgroup>\n';
                }
                html += options;
            }
        }
        if (qty_strings === 0) {
            html = '';
        }
        return html;
    };
    
    // actually load the select tag
    var populate_boilerplate = function(boilerplate_type, html) {
        var $target = null;
        switch(boilerplate_type) {
            case 'hide-reason': $target = $hide_reasons; break;
            case 'reply': $target = $boilerplate_replies; break;
        }
        if ($target) {
            if (html) {
                $target.show().find('select').html(html);
            } else {
                $target.hide();
            }
        }
    };
    
    // revealed public methods:
    return {
       config: config,
       setup_click_listener: setup_click_listener,
       get_available_messages: get_available_messages,
       request_lock: request_lock,
       assign_fms_id: assign_fms_id,
       reply: reply,
       hide: hide,
       show_info: show_info,
       sign_out: sign_out,
       populate_boilerplate_strings: populate_boilerplate_strings,
       say_status: say_status,
       mark_as_not_a_reply: mark_as_not_a_reply
     };
})();
