/*
 * fixmystreet.js
 * FixMyStreet JavaScript
 */

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
 
        //hide / show the right tab
        $('.tab.open').hide().removeClass('open');
        $(target).show().addClass('open');
    }
}


$(function(){
    var $html = $('html');

    var cobrand = $('meta[name="cobrand"]').attr('content');
    var is_small_map = false;
    if (cobrand === 'bromley') {
        is_small_map = true;
    }

    // Deal with switching between mobile and desktop versions on resize
    var last_type;
    $(window).resize(function(){
        var type = $('#site-header').css('borderTopWidth');
        if (type == '4px') { type = 'mobile'; }
        else if (type == '0px') { type = 'desktop'; }
        else { return; }
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
                if (cobrand != 'bromley') {
                    $('#site-header').hide();
                }
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
                if (is_small_map) {
                    //$('#bromley-footer').hide();
                } else {
                    fixmystreet.state_map = 'full';
                }
            }
            if (typeof fixmystreet !== 'undefined' && fixmystreet.page == 'around') {
                // Remove full-screen-ness
                var banner_text = translation_strings.report_problem_heading;
                if (cobrand == 'bromley') {
                    banner_text += '<span>Yellow pins show existing reports</span>';
                }
                if (! is_small_map && cobrand !== 'oxfordshire') {
                    $('#site-header').show();
                    banner_text = translation_strings.report_problem_heading;
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
    $('.mobile #report-a-problem-sidebar').after('<a href="#" class="rap-notes-trigger button-right">' + translation_strings.how_to_send + '</a>').hide();
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
            $('#report-a-problem-sidebar').appendTo('.rap-notes').show().after('<a href="#" class="rap-notes-close button-left">' + translation_strings.back + '</a>');
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
    $('.mobile #skip-this-step').hide();
    $('.mobile #skip-this-step a').addClass('chevron').wrap('<li>').appendTo('#key-tools');

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
                $this.prepend(' <img class="spinner" src="/cobrands/fixmystreet/images/spinner-black-333.gif" style="margin-right:2em;">');
                innerDiv.load(href, function(){
                    $('.spinner').remove();
                });
            }
            
            // Tall drawer - put after .content for scrolling to work okay.
            // position over the top of the main .content in precisely the right location
            d.insertAfter($content).addClass('content').css({
                position: 'absolute',
                zIndex: '1100',
                marginTop: $('html.ie6, html.ie7').length ? '-3em' : 0, // IE6/7 otherwise include the 3em padding and stay too low
                left: 0,
                top: $(window).height() - $content.offset().top
            }).removeClass('hidden-js').find('h2').css({ marginTop: 0 });
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
    $('.container').on('click', '#alert_rss_button', function(e){
        e.preventDefault();
        var feed = $('input[name=feed][type=radio]:checked').nextAll('a').attr('href');
        window.location.href = feed;
    });
    $('.container').on('click', '#alert_email_button', function(e){
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
        var maplinks_width = $('#sub_map_links').width();

        if($(this).hasClass('closed')){
            $(this).removeClass('closed');
            $('#sub_map_links').animate({'right':'0'}, 1200);
        }else{
            $(this).addClass('closed');
            $('#sub_map_links').animate({'right':-maplinks_width}, 1200);
        }
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

    $('#message_close').live('click', function() {
        $('#country_banner').hide();
        $.cookie('has_seen_country_message', 1, {expires: 365, path: '/'});
    });

    if ( cobrand == 'fixmystreet' && $('body.frontpage').length ) {
        if (!$.cookie('has_seen_country_message')) {
            $.ajax({
                url: '/country_message',
                success: function(data) {
                    if ( data ) {
                        $('#site-header').css('position', 'relative');
                        $('body').prepend(data);
                        $('#country_banner').slideDown('slow');
                    }
                }
            });
        }
    }

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
            if (cobrand == 'bromley') {
                offset = -110;
            }
            if (cobrand == 'oxfordshire') {
                offset = -13 * 16;
            }
            heightFix(window, '.content', offset, 1);
            // in case we have a map that isn't full screen
            map_fix();
        }
    }

});

/*
XXX Disabled because jerky on Android and makes map URL bar height too small on iPhone.
// Hide URL bar
$(window).load(function(){
    window.setTimeout(function(){
        var s = window.pageYOffset || document.compatMode === "CSS1Compat" && document.documentElement.scrollTop || document.body.scrollTop || 0;
        if (s < 20 && !location.hash) {
            window.scrollTo(0, 1);
        }
    }, 0);
});
*/

