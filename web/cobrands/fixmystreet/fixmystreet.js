/*
 * fixmystreet.js
 * FixMyStreet JavaScript
 */

/*
 * Find directionality of content
 */
function isR2L() {
    return !!$('html[dir=rtl]').length;
}

/*
 * general height fixing function
 *
 * elem1: element to check against
 * elem2: target element
 * offset: this will be added (if present) to the final value, useful for height errors
 */
function heightFix(elem1, elem2, offset, force) {
    var h1 = $(elem1).height(),
        h2 = $(elem2).height();
    if (offset === undefined) {
        offset = 0;
    }
    if (h1 > h2 || force) {
        $(elem2).css( { 'min-height': h1+offset } );
    }
}


/*
 * very simple tab function
 *
 * elem: trigger element, must have an href attribute (so probably needs to be an <a>)
 */
function tabs(elem, indirect) {
    var href = elem.attr('href');
    //stupid IE sometimes adds the full uri into the href attr, so trim
    var start = href.indexOf('#'),
        target = href.slice(start, href.length);

    if (indirect) {
        elem = $(target + '_tab');
    }

    if(!$(target).hasClass('open'))
    {
        //toggle class on nav
        $('.tab-nav .active').removeClass('active');
        elem.addClass('active');

        //hide / show the correct tab
        $('.tab.open').hide().removeClass('open');
        $(target).show().addClass('open');
    }
}

/* Geographic functions for faking map centre, as it appears to be offset from
   where it actually is */

function midpoint_box_excluding_column(col_offset, col_width, box_offset, box_width) {
    var r2l = isR2L(),
        diff = r2l ? box_width : (box_offset.left - col_width),
        q = (col_offset.left - diff) / 2;
    if ((r2l && q > 0) || (!r2l && q < 0)) {
        return 0;
    }
    return q;
}

function fixmystreet_midpoint() {
    var $content = $('.content'), mb = $('#map_box');
    return midpoint_box_excluding_column($content.offset(), $content.width(), mb.offset(), mb.width());
}


$(function(){
    var $html = $('html');

    var cobrand = $('meta[name="cobrand"]').attr('content');

    if (typeof variation !== 'undefined' && variation === 1) {
        $('input[name=variant]').val(1);
    }

    // Deal with switching between mobile and desktop versions on resize
    var last_type;
    $(window).resize(function(){
        var type = Modernizr.mq('(min-width: 48em)') || $('html.iel8').length ? 'desktop' : 'mobile';
        if (last_type == type) { return; }
        if (type == 'mobile') {
            $html.addClass('mobile');
            $('#map_box').prependTo('.content').css({
                zIndex: '', position: '',
                top: '', left: '', right: '', bottom: '',
                width: '', height: '10em',
                margin: ''
            });
            if (typeof fixmystreet !== 'undefined') {
                fixmystreet.state_map = ''; // XXX
            }
            if (typeof fixmystreet !== 'undefined' && fixmystreet.page == 'around') {
                // Immediately go full screen map if on around page
                $('#site-header').hide();
                $('#map_box').prependTo('.wrapper').css({
                    position: 'absolute',
                    top: 0, left: 0, right: 0, bottom: 0,
                    height: 'auto',
                    margin: 0
                });
                $('#fms_pan_zoom').css({ top: '2.75em' });
                $('.big-green-banner')
                    .addClass('mobile-map-banner')
                    .appendTo('#map_box')
                    .html('<a href="/">' + translation_strings.home + '</a> ' + translation_strings.place_pin_on_map);
            } else {
                $('#fms_pan_zoom').css({ top: '0.5em' });
            }
            $('span.report-a-problem-btn').on('click.reportBtn', function(){
                $('html, body').animate({scrollTop:0}, 500);
            }).css({ cursor:'pointer' }).on('hover.reportBtn', function(){
                $(this).toggleClass('hover');
            });
        } else {
            // Make map full screen on non-mobile sizes.
            $html.removeClass('mobile');
            position_map_box();
            if (typeof fixmystreet !== 'undefined') {
                fixmystreet.state_map = 'full';
            }
            if (typeof fixmystreet !== 'undefined' && fixmystreet.page == 'around') {
                // Remove full-screen-ness
                var banner_text = translation_strings.report_problem_heading;
                if (cobrand !== 'oxfordshire') {
                    $('#site-header').show();
                }
                if (typeof variation !== 'undefined' && variation === 1) {
                    banner_text = 'Click map to request a fix';
                }
                $('.big-green-banner')
                    .removeClass('mobile-map-banner')
                    .prependTo('#side')
                    .html(banner_text);
            }
            $('#fms_pan_zoom').css({ top: '4.75em' });
            $('span.report-a-problem-btn').css({ cursor:'' }).off('.reportBtn');
        }
        last_type = type;
    }).resize();

    /*
     * Report a problem page
     */
    //desktop
    if ($('#report-a-problem-sidebar').is(':visible')) {
        heightFix('#report-a-problem-sidebar', '.content', 26);
    }

    //show/hide notes on mobile
    $('.mobile #report-a-problem-sidebar').after('<a href="#" class="rap-notes-trigger button-fwd">' + translation_strings.how_to_send + '</a>').hide();
    $('.rap-notes-trigger').click(function(e){
        e.preventDefault();
        //check if we've already moved the notes
        if($('.rap-notes').length > 0){
            //if we have, show and hide .content
            $('.content').hide();
            $('.rap-notes').show();
        }else{
            //if not, move them and show, hiding .content
            $('.content').after('<div class="content rap-notes"></div>').hide();
            $('#report-a-problem-sidebar').appendTo('.rap-notes').show().after('<a href="#" class="rap-notes-close button-back">' + translation_strings.back + '</a>');
        }
        $('html, body').scrollTop($('#report-a-problem-sidebar').offset().top);
        location.hash = 'rap-notes';
    });
    $('.mobile').on('click', '.rap-notes-close', function(e){
        e.preventDefault();
        //hide notes, show .content
        $('.content').show();
        $('.rap-notes').hide();
        $('html, body').scrollTop($('#mob_ok').offset().top);
        location.hash = 'report';
    });

    //move 'skip this step' link on mobile
    $('.mobile #skip-this-step').addClass('chevron').wrap('<li>').parent().appendTo('#key-tools');

    // Set up the Dropzone image uploader
    if('Dropzone' in window){
      Dropzone.autoDiscover = false;
    }
    if('Dropzone' in window && $('#form_photo').length){
      var $originalLabel = $('[for="form_photo"]');
      var $originalInput = $('#form_photos');
      var $dropzone = $('<div>').addClass('dropzone');

      $originalLabel.removeAttr('for');
      $originalInput.hide();

      $dropzone.insertAfter($originalInput);
      var photodrop = new Dropzone($dropzone[0], {
        url: '/photo/upload',
        paramName: 'photo',
        maxFiles: 3,
        addRemoveLinks: true,
        thumbnailHeight: 150,
        thumbnailWidth: 150,
        acceptedFiles: 'image/jpeg,image/pjpeg,image/gif,image/tiff,image/png',
        dictDefaultMessage: translation_strings.upload_default_message,
        dictCancelUploadConfirmation: translation_strings.upload_cancel_confirmation,
        dictInvalidFileType: translation_strings.upload_invalid_file_type,
        dictMaxFilesExceeded: translation_strings.upload_max_files_exceeded,

        fallback: function(){
          $dropzone.remove();
          $originalLabel.attr('for', 'form_photo');
          $originalInput.show();
        },
        init: function(){
          this.on("addedfile", function(file){
            $('input[type=submit]').prop("disabled", true).removeClass('green-btn');
          });
          this.on("queuecomplete", function(){
            $('input[type=submit]').removeAttr('disabled').addClass('green-btn');
          });
          this.on("success", function(file, xhrResponse) {
            var ids = $('input[name=upload_fileid]').val().split(','),
                id = (file.server_id = xhrResponse.id),
                l = ids.push(id),
                newstr = ids.join(',');
            $('input[name=upload_fileid]').val(newstr);
          });
          this.on("error", function(file, errorMessage, xhrResponse){
          });
          this.on("removedfile", function(file){
            var ids = $('input[name=upload_fileid]').val().split(','),
                newstr = $.grep(ids, function(n){ return (n!=file.server_id); }).join(',');
            $('input[name=upload_fileid]').val(newstr);
          });
          this.on("maxfilesexceeded", function(file){
            this.removeFile(file);
            var $message = $('<div class="dz-message dz-error-message">');
            $message.text(translation_strings.upload_max_files_exceeded);
            $message.prependTo(this.element);
            setTimeout(function(){
              $message.slideUp(250, function(){
                $message.remove();
              });
            }, 2000);
          });
        }
      });

      $.each($('input[name=upload_fileid]').val().split(','), function(i, f) {
        if (!f) {
            return;
        }
        var mockFile = { name: f, server_id: f };
        photodrop.emit("addedfile", mockFile);
        photodrop.createThumbnailFromUrl(mockFile, '/photo/temp.' + f);
        photodrop.emit("complete", mockFile);
        photodrop.options.maxFiles -= 1;
      });
    }

    /*
     * Tabs
     */
    //make initial tab active
    $('.tab-nav a').first().addClass('active');
    $('.tab').first().addClass('open');

    //hide other tabs
    $('.tab').not('.open').hide();

    //set up click event
    $(".tab-nav").on('click', 'a', function(e){
        e.preventDefault();
        tabs($(this));
    });
    $('.tab_link').click(function(e) {
        e.preventDefault();
        tabs($(this), 1);
    });

    /*
     * Skip to nav on mobile
     */
    $('.mobile').on('click', '#nav-link', function(e){
        e.preventDefault();
        var offset = $('#main-nav').offset().top;
        $('html, body').animate({scrollTop:offset}, 1000);
        window.location.hash = 'main-nav';
    });


    /*
     * Show stuff on input focus
     */
    var form_focus_data = $('.form-focus-trigger').map(function() {
        return $(this).val();
    }).get().join('');
    if (!form_focus_data) {
        $('.form-focus-hidden').hide();
        $('.form-focus-trigger').on('focus', function(){
            $('.form-focus-hidden').fadeIn(500);
        });
    }

    /* Log in with email button */
    var email_form = $('#js-social-email-hide'),
        button = $('<button class="btn btn--social btn--social-email">Log in with email</button>'),
        form_box = $('<div class="form-box"></div>');
    button.click(function(e){
        e.preventDefault();
        email_form.fadeIn(500);
        form_box.hide();
    });
    form_box.append(button).insertBefore(email_form);
    if ($('.form-error').length) {
        button.click();
    }

    /*
     * Show on click - pretty generic
     */
    $('.hideshow-trigger').on('click', function(e){
        e.preventDefault();
        var href = $(this).attr('href'),
            //stupid IE sometimes adds the full uri into the href attr, so trim
            start = href.indexOf('#'),
            target = href.slice(start, href.length);

        $(target).removeClass('hidden-js');

        $(this).hide();
    });

    /*
     * nicetable - on mobile shift 'name' col to be a row
     */
    $('.mobile .nicetable th.title').remove();
    $('.mobile .nicetable td.title').each(function(i){
        $(this).attr('colspan', 5).insertBefore($(this).parent('tr')).wrap('<tr class="heading" />');
    });
    // $('.mobile .nicetable tr.heading > td.title').css({'min-width':'300px'});
    // $('.mobile .nicetable tr > td.data').css({'max-width':'12%'});

    /*
     * Map controls prettiness
     */
    //add links container (if its not there)
    if($('#sub_map_links').length === 0){
        $('<p id="sub_map_links" />').insertAfter($('#map'));
    }

// A sliding drawer from the bottom of the page, small version
// that doesn't change the main content at all.
(function($){

    var opened;

    $.fn.small_drawer = function(id) {
        this.toggle(function(){
            if (opened) {
                opened.click();
            }
            var $this = $(this), d = $('#' + id);
            if (!$this.addClass('hover').data('setup')) {
                d.hide().removeClass('hidden-js').css({
                padding: '1em',
                background: '#fff'
                });
                $this.data('setup', true);
            }
            d.slideDown();
            opened = $this;
        }, function(e){
            var $this = $(this), d = $('#' + id);
            $this.removeClass('hover');
            d.slideUp();
            opened = null;
        });
    };

})(jQuery);

// A sliding drawer from the bottom of the page, large version
$.fn.drawer = function(id, ajax) {
    // IE7 positions the fixed tool bar 1em to the left unless it comes after
    // the full-width section, ho-hum. Move it to where it would be after an
    // open/close anyway
    if ($('html.ie7').length) {
        var $sw = $('.shadow-wrap'), $content = $('.content[role="main"]');
        $sw.appendTo($content);
    }
    this.toggle(function(){
        var $this = $(this), d = $('#' + id), $content = $('.content[role="main"]');
        if (!$this.addClass('hover').data('setup')) {
            // make a drawer div with an innerDiv
            if (!d.length) {
                d = $('<div id="' + id + '">');
            }
            var innerDiv = $('<div>');
            d.wrapInner(innerDiv);

            // if ajax, load it with a spinner
            if (ajax) {
                var href = $this.attr('href') + ';ajax=1';
                var margin = isR2L() ? 'margin-left' : 'margin-right';
                $this.prepend(' <img class="spinner" src="/cobrands/fixmystreet/images/spinner-black-333.gif" style="' + margin + ':2em;">');
                innerDiv.load(href, function(){
                    $('.spinner').remove();
                });
            }

            // Tall drawer - put after .content for scrolling to work okay.
            // position over the top of the main .content in precisely the correct location
            var drawer_css = {
                position: 'absolute',
                zIndex: '1100',
                marginTop: $('html.ie6, html.ie7').length ? '-3em' : 0, // IE6/7 otherwise include the 3em padding and stay too low
                top: $(window).height() - $content.offset().top
            };
            drawer_css[isR2L() ? 'right' : 'left'] = 0;
            d.insertAfter($content).addClass('content').css(drawer_css)
                .removeClass('hidden-js').find('h2').css({ marginTop: 0 });
            $this.data('setup', true);
        }

        //do the animation
        $('.shadow-wrap').prependTo(d).addClass('static');
        d.show().animate({top:'3em'}, 1000, function(){
            $content.fadeOut(function() {
                d.css({ position: 'relative' });
            });
        });
    }, function(e){
        var $this = $(this), d = $('#' + id), $sw = $('.shadow-wrap'),
            $content = $('.content[role="main"]'),
            tot_height = $(window).height() - d.offset().top;
        $this.removeClass('hover');
        d.css({ position: 'absolute' }).animate({ top: tot_height }, 1000, function(){
            d.hide();
            $sw.appendTo($content).removeClass('static');
        });
        $content.show();
    });
};

    if ($('html.mobile').length || slide_wards_down ) {
        $('#council_wards').hide().removeClass('hidden-js').find('h2').hide();
        $('#key-tool-wards').click(function(e){
            e.preventDefault();
            $('#council_wards').slideToggle('800', function(){
              $('#key-tool-wards').toggleClass('hover');
            });
        });
    } else {
        $('#key-tool-wards').drawer('council_wards', false);
        $('#key-tool-around-updates').drawer('updates_ajax', true);
    }
    $('#key-tool-report-updates').small_drawer('report-updates-data');
    $('#key-tool-report-share').small_drawer('report-share');

    // Go directly to RSS feed if RSS button clicked on alert page
    // (due to not wanting around form to submit, though good thing anyway)
    $('body').on('click', '#alert_rss_button', function(e){
        e.preventDefault();
        var feed = $('input[name=feed][type=radio]:checked').nextAll('a').attr('href');
        window.location.href = feed;
    });
    $('body').on('click', '#alert_email_button', function(e){
        e.preventDefault();
        var form = $('<form/>').attr({ method:'post', action:"/alert/subscribe" });
        form.append($('<input name="alert" value="Subscribe me to an email alert" type="hidden" />'));
        $('#alerts input[type=text], #alerts input[type=hidden], #alerts input[type=radio]:checked').each(function() {
            var $v = $(this);
            $('<input/>').attr({ name:$v.attr('name'), value:$v.val(), type:'hidden' }).appendTo(form);
        });
        $('body').append(form);
        form.submit();
    });

    //add permalink on desktop, force hide on mobile
    if (cobrand != 'zurich') {
        $('#sub_map_links').append('<a href="#" id="map_permalink">' + translation_strings.permalink + '</a>');
    }

    if($('.mobile').length){
        $('#map_permalink').hide();
        $('#key-tools a.feed').appendTo('#sub_map_links');
        $('#key-tools li:empty').remove();
        $('#report-updates-data').insertAfter($('#map_box'));
    }
    //add open/close toggle button on desk
    $('#sub_map_links').prepend('<span id="map_links_toggle">&nbsp;</span>');

    //set up map_links_toggle click event
    $('#map_links_toggle').on('click', function(){
        var sub_map_links_css = {},
            left_right = isR2L() ? 'left' : 'right';
        if ($(this).hasClass('closed')) {
            $(this).removeClass('closed');
            sub_map_links_css[left_right] = '0';
        } else {
            $(this).addClass('closed');
            sub_map_links_css[left_right] = -$('#sub_map_links').width();
        }
        $('#sub_map_links').animate(sub_map_links_css, 1200);
    });


    /*
     * Add close buttons for .promo's
     */
    if($('.promo').length){
        $('.promo').append('<a href="#" class="close-promo">x</a>');
    }
    //only close its own parent
    $('.promo').on('click', '.close-promo', function(e){
        e.preventDefault();
        $(this).parent('.promo').animate({
            'height':0,
            'margin-bottom':0,
            'padding-top':0,
            'padding-bottom':0
        },{
            duration:500,
            queue:false
        }).fadeOut(500);
    });

    /*
     * Fancybox fullscreen images
     */
    if (typeof $.fancybox == 'function') {
        $('a[rel=fancy]').fancybox({
            'overlayColor': '#000000'
        });
    }

    /*
     * heightfix the desktop .content div
     *
     * this must be kept near the end so that the
     * rendered height is used after any page manipulation (such as tabs)
     */
    if (!$('html.mobile').length) {
        if (!($('body').hasClass('fullwidthpage'))){
            var offset = -15 * 16;
            if (cobrand == 'oxfordshire') {
                // Oxfordshire uses box-sizing:border-box and padding to work out height
                offset = 0;
            }
            heightFix(window, '.content', offset, 1);
            // in case we have a map that isn't full screen
            map_fix();
        }
    }

});
