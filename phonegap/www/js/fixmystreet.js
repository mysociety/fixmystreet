/*
 * fixmystreet.js
 * FixMyStreet JavaScript
 */

function form_category_onchange() {
    var cat = $('#form_category');
    var args = {
        category: cat.val()
    };

    if ( typeof fixmystreet !== 'undefined' ) {
        args.latitude = fixmystreet.latitude;
        args.longitude = fixmystreet.longitude;
    } else {
        args.latitude = $('input[name="latitude"]').val();
        args.longitude = $('input[name="longitude"]').val();
    }

    $.getJSON( CONFIG.FMS_URL + 'report/new/category_extras', args, function(data) {
        if ( data.category_extra ) {
            if ( $('#category_meta').size() ) {
                $('#category_meta').html( data.category_extra);
            } else {
                $('#form_category_row').after( data.category_extra );
            }
        } else {
            $('#category_meta').empty();
        }
    });
}

/*
 * general height fixing function
 *
 * elem1: element to check against
 * elem2: target element
 * offset: this will be added (if present) to the final value, useful for height errors
 */
function heightFix(elem1, elem2, offset){
    var h1 = $(elem1).height(),
        h2 = $(elem2).height();
    if(offset === undefined){
        offset = 0;
    }
    if(h1 > h2){
        $(elem2).css({'min-height':h1+offset});
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

    $html.removeClass('no-js').addClass('js');


    // Preload the new report pin
    document.createElement('img').src = '../i/pin-green.png';

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
                $('#site-header').hide();
                $('#map_box').prependTo('.wrapper').css({
                    position: 'absolute',
                    top: 0, left: 0, right: 0, bottom: 0,
                    height: 'auto',
                    margin: 0
                });
                $('#fms_pan_zoom').css({ top: '2.75em !important' });
                $('.big-green-banner')
                    .addClass('mobile-map-banner')
                    .appendTo('#map_box')
                    .text('Place pin on map')
	            .prepend('<a href="index.html">home</a>');
            }
            $('span.report-a-problem-btn').on('click.reportBtn', function(){
                $('html, body').animate({scrollTop:0}, 500);
            }).css({ cursor:'pointer' }).on('hover.reportBtn', function(){
                $(this).toggleClass('hover');
            });
        } else {
            // Make map full screen on non-mobile sizes.
            $html.removeClass('mobile');
            var map_pos = 'fixed', map_height = '100%';
            if ($html.hasClass('ie6')) {
                map_pos = 'absolute';
                map_height = $(window).height();
            }
            $('#map_box').prependTo('.wrapper').css({
                zIndex: 0, position: map_pos,
                top: 0, left: 0, right: 0, bottom: 0,
                width: '100%', height: map_height,
                margin: 0
            });
            if (typeof fixmystreet !== 'undefined') {
                fixmystreet.state_map = 'full';
            }
            if (typeof fixmystreet !== 'undefined' && fixmystreet.page == 'around') {
                // Remove full-screen-ness
                $('#site-header').show();
                $('#fms_pan_zoom').css({ top: '4.75em !important' });
                $('.big-green-banner')
                    .removeClass('mobile-map-banner')
                    .prependTo('#side')
                    .text('Click map to report a problem');
            }
            $('span.report-a-problem-btn').css({ cursor:'' }).off('.reportBtn');
        }
        last_type = type;
    });

    //add mobile class if small screen
    $(window).resize();

    $('#pc').focus();

    $('input[type=submit]').removeAttr('disabled');
    /*
    $('#mapForm').submit(function() {
        if (this.submit_problem) {
            $('input[type=submit]', this).prop("disabled", true);
        }
        return true;
    });
    */

    if (!$('#been_fixed_no').prop('checked') && !$('#been_fixed_unknown').prop('checked')) {
        $('#another_qn').hide();
    }
    $('#been_fixed_no').click(function() {
        $('#another_qn').show('fast');
    });
    $('#been_fixed_unknown').click(function() {
        $('#another_qn').show('fast');
    });
    $('#been_fixed_yes').click(function() {
        $('#another_qn').hide('fast');
    });

    // FIXME - needs to use translated string
    jQuery.validator.addMethod('validCategory', function(value, element) {
        return this.optional(element) || value != '-- Pick a category --'; }, validation_strings.category );

    jQuery.validator.addMethod('validName', function(value, element) {
        var validNamePat = /\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
        return this.optional(element) || value.length > 5 && value.match( /\S/ ) && !value.match( validNamePat ); }, validation_strings.category );

    var form_submitted = 0;
    var submitted = false;

    $("form.validate").validate({
        rules: {
            title: { required: true },
            detail: { required: true },
            email: { required: true },
            update: { required: true },
            rznvy: { required: true }
        },
        messages: validation_strings,
        onkeyup: false,
        onfocusout: false,
        errorElement: 'div',
        errorClass: 'form-error',
        // we do this to stop things jumping around on blur
        success: function (err) { if ( form_submitted ) { err.addClass('label-valid').removeClass('label-valid-hidden').html( '&nbsp;' ); } else { err.addClass('label-valid-hidden'); } },
        errorPlacement: function( error, element ) {
            element.before( error );
        },
        submitHandler: function(form) {
            if (form.submit_problem) {
                $('input[type=submit]', form).prop("disabled", true);
            }

            // this needs to be disabled otherwise it submits the form normally rather than
            // over AJAX. This comment is to make this more likely to happen when updating
            // this code.
            //form.submit();
        },
        // make sure we can see the error message when we focus on invalid elements
        showErrors: function( errorMap, errorList ) {
            if ( submitted && errorList.length ) {
               $(window).scrollTop( $(errorList[0].element).offset().top - 120 );
            }
            this.defaultShowErrors();
            submitted = false;
        },
        invalidHandler: function(form, validator) { submitted = true; }
    });

    $('input[type=submit]').click( function(e) { form_submitted = 1; } );

    /* set correct required status depending on what we submit 
    * NB: need to add things to form_category as the JS updating 
    * of this we do after a map click removes them */
    $('#submit_sign_in').click( function(e) {
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').removeClass();
    } );

    $('#submit_register').click( function(e) { 
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').addClass('required validName');
    } );

    $('#problem_submit > input[type="submit"]').click( function(e) { 
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('#form_name').addClass('required validName');
    } );

    $('#update_post').click( function(e) { 
        $('#form_name').addClass('required').removeClass('valid');
    } );

    $('#form_category').change( form_category_onchange );

    // Geolocation
    if (geo_position_js.init()) {
        $('#postcodeForm').after('<a href="#" id="geolocate_link">&hellip; or locate me automatically</a>');
        $('#geolocate_link').click(getPosition);
    }

    /* 
     * Report a problem page 
     */
    //desktop
    if ($('#report-a-problem-sidebar').is(':visible')) {
        heightFix('#report-a-problem-sidebar', '.content', 26);
    }

    //show/hide notes on mobile
    $('.mobile #report-a-problem-sidebar').after('<a href="#" class="rap-notes-trigger button-right">How to send successful reports</a>').hide();
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
            $('#report-a-problem-sidebar').appendTo('.rap-notes').show().after('<a href="#" class="rap-notes-close button-left">Back</a>');
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
    $('.form-focus-hidden').hide();
    $('.form-focus-trigger').on('focus', function(){
        $('.form-focus-hidden').fadeIn(500);
    });

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
$.fn.small_drawer = function(id) {
    this.toggle(function(){
        var $this = $(this), d = $('#' + id);
        if (!$this.addClass('hover').data('setup')) {
            d.hide().removeClass('hidden-js').css({
                padding: '1em',
                background: '#fff'
            });
            $this.data('setup', true);
        }
        d.slideDown();
    }, function(e){
        var $this = $(this), d = $('#' + id);
        $this.removeClass('hover');
        d.slideUp();
    });
};

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

    if ($('html.mobile').length) {
        $('#council_wards').hide().removeClass('hidden-js').find('h2').hide();
        $('#key-tool-wards').click(function(e){
            e.preventDefault();
            $('#council_wards').slideToggle('800', function(){
              $('#key-tool-wards').toggleClass('active');
            });
        });
    } else {
        $('#key-tool-wards').drawer('council_wards', false);
        $('#key-tool-around-updates').drawer('updates_ajax', true);
    }
    $('#key-tool-report-updates').small_drawer('report-updates-data');

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
        form.submit();
    });

    //add permalink on desktop, force hide on mobile
    $('#sub_map_links').append('<a href="#" id="map_permalink">Permalink</a>');
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
        if (!($('body').hasClass('frontpage'))){
            heightFix(window, '.content', -176);
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

