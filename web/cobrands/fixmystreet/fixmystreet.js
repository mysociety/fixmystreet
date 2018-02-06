/*
 * fixmystreet.js
 * FixMyStreet JavaScript
 */

var fixmystreet = fixmystreet || {};

/*
 * Find directionality of content
 */
function isR2L() {
    return !!$('html[dir=rtl]').length;
}

// Some small jQuery extensions
(function($) {
  var opened;

  $.fn.extend({
    // A sliding drawer from the bottom of the page, small version
    // that doesn't change the main content at all.
    small_drawer: function(id) {
        var $this = $(this), d = $('#' + id);
        this.toggle(function() {
            if (opened) {
                opened.click();
            }
            if (!$this.addClass('hover').data('setup')) {
                d.hide().removeClass('hidden-js').css({
                padding: '1em',
                background: '#fff'
                });
                $this.data('setup', true);
            }
            d.slideDown();
            opened = $this;
        }, function(e) {
            $this.removeClass('hover');
            d.slideUp();
            opened = null;
        });
    },

    // A sliding drawer from the bottom of the page, large version
    drawer: function(id, ajax) {

        // The link/button that triggered the drawer
        var $this = $(this);

        // A bunch of elements that will come in handy when opening/closing
        // the drawer. Because $sw changes its position in the DOM, we capture
        // all these elements just once, the first time .drawer() is called.
        var $sidebar = $('#map_sidebar');
        var $sw = $this.parents('.shadow-wrap');
        var $swparent = $sw.parent();
        var $drawer = $('#' + id);

        this.off('click');
        this.toggle(function() {
            // Find the specified drawer, or create it if it doesn't exist
            if ($drawer.length === 0) {
                $drawer = $('<div id="' + id + '">');
                $drawer.appendTo($swparent);
            }

            if (!$this.addClass('hover').data('setup')) {
                // Optionally fill $drawer with HTML from an AJAX data source
                if (ajax) {
                    var href = $this.attr('href') + ';ajax=1';
                    var margin = isR2L() ? 'margin-left' : 'margin-right';
                    var $ajax_result = $('<div>').appendTo($drawer);
                    $ajax_result.html('<p style="text-align:center">Loading</p>');
                    $ajax_result.load(href);
                }

                // Style up the $drawer
                var drawer_top = $(window).height() - $sw.height();
                var drawer_css = {
                    position: 'fixed',
                    zIndex: 10,
                    top: drawer_top,
                    bottom: 0,
                    width: $sidebar.css('width'),
                    paddingLeft: $sidebar.css('padding-left'),
                    paddingRight: $sidebar.css('padding-right'),
                    overflow: 'auto',
                    background: '#fff'
                };
                drawer_css[isR2L() ? 'right' : 'left'] = 0;
                $drawer.css(drawer_css).removeClass('hidden-js').find('h2').css({ marginTop: 0 });
                $this.data('setup', true);
            }

            // Insert the .shadow-wrap controls into the top of the drawer.
            $sw.addClass('static').prependTo($drawer);

            // Animate the drawer into place, enitrely covering the sidebar.
            var sidebar_top_px = $sidebar.position().top;
            $drawer.show().animate({ top: sidebar_top_px }, 1000);

        }, function(e) {
            // Slide the drawer down, move the .shadow-wrap back to its
            // original parent, and hide the drawer for potential re-use later.
            $this.removeClass('hover');
            var drawer_top = $(window).height() - $sw.height();

            $drawer.animate({ top: drawer_top }, 1000, function() {
                $sw.removeClass('static').appendTo($swparent);
                $drawer.hide();
            });
        });
    },

    make_multi: function() {
      // A convenience wrapper around $.multiSelect() that translates HTML
      // data-* attributes into settings for the multiSelect constructor.
      return this.each(function() {
        var $select = $(this);
        var settings = {};

        if ( $select.data('none') ) {
            settings.noneText = $select.data('none');
        }

        if ( $select.data('all') ) {
            settings.allText = $select.data('all');
            settings.noneText = settings.noneText || settings.allText;
            settings.presets = [];
            settings.presets.push({
                name: settings.allText,
                options: $select.data('all-options') || []
            });
        }

        if ( $select.data('extra') && $select.data('extra-options') ) {
            settings.presets = settings.presets || [];
            settings.presets.push({
                name: $select.data('extra'),
                options: $select.data('extra-options')
            });
        }

        if ( document.querySelector('#side') && document.querySelector('#side').contains($select[0]) ) {
            settings.positionMenuWithin = $('#side');
        }

        $select.multiSelect(settings);
      });
    }

  });
})(jQuery);

fixmystreet.hooks = fixmystreet.hooks || {};

fixmystreet.mobile_reporting = {
  apply_ui: function() {
    // Creates the "app-like" mobile reporting UI with full screen map
    // and special "OK/Cancel" buttons etc.
    $('html').addClass('map-fullscreen only-map map-reporting');
    $('.mobile-map-banner span').text(translation_strings.place_pin_on_map);
    $('html, body').scrollTop(0);
  },

  remove_ui: function() {
    // Removes the "app-like" mobile reporting UI, reverting all the
    // changes made by fixmystreet.mobile_reporting.apply_ui().
    $('html').removeClass('map-fullscreen only-map map-reporting');
    $('#map_box').css({ width: "", height: "", position: "" });
    $('#mob_sub_map_links').remove();
  }
};

fixmystreet.resize_to = {
  mobile_page: function() {
    $('html').addClass('mobile');
    if (typeof fixmystreet !== 'undefined' && fixmystreet.page == 'around') {
        fixmystreet.mobile_reporting.apply_ui();
    }

    // Hide sidebar notes ("rap-notes") on the /report/new page on mobile,
    // and provide a button that reveals/hides them again.
    var $rapSidebar = $('#report-a-problem-sidebar');
    if ($rapSidebar.length) {
        $rapSidebar.hide();
        $('<a>')
            .addClass('rap-notes-trigger btn btn--block btn--forward')
            .html(translation_strings.how_to_send)
            .insertBefore($rapSidebar)
            .on('click', function(){
                $rapSidebar.slideToggle(100);
                $(this).toggleClass('btn--forward btn--cancel');
            });
    }

    // On the front page, make it so that the "report a problem" menu item
    // scrolls to the top of the page, and has a hover effect, rather than
    // just being an innert span.
    $('span.report-a-problem-btn').on('click.reportBtn', function() {
        $('html, body').animate({scrollTop:0}, 500);
    }).css({ cursor:'pointer' }).on('hover.reportBtn', function() {
        $(this).toggleClass('hover');
    });
  },

  desktop_page: function() {
    $('html').removeClass('mobile');
    fixmystreet.mobile_reporting.remove_ui();

    // Undo the special "rap-notes" tweaks that might have
    // been put into place by previous mobile UI.
    $('#report-a-problem-sidebar').show();
    $('.rap-notes-trigger').remove();

    // On a desktop, so reset the "Report a problem" nav item to act
    // like an innert span again.
    $('span.report-a-problem-btn').css({ cursor:'' }).off('.reportBtn');
  }
};

fixmystreet.update_list_item_buttons = function($list) {
    if (!$list) {
        return;
    }
  $list.find('[name="shortlist-up"], [name="shortlist-down"]').prop('disabled', false);
  $list.children(':first-child').find('[name="shortlist-up"]').prop('disabled', true);
  $list.children(':last-child').find('[name="shortlist-down"]').prop('disabled', true);
};

// A tiny helper to call a function only if it exists (so we can
// call this with staff-only functions and they won't error).
fixmystreet.run = function(fn) {
    if (fn) {
        fn.call(this);
    }
};

fixmystreet.set_up = fixmystreet.set_up || {};
$.extend(fixmystreet.set_up, {
  basics: function() {
    // Preload the new report pin
    if ( typeof fixmystreet !== 'undefined' && typeof fixmystreet.pin_prefix !== 'undefined' ) {
        document.createElement('img').src = fixmystreet.pin_prefix + 'pin-' + fixmystreet.pin_new_report_colour + '.png';
    } else {
        document.createElement('img').src = '/i/pin-green.png';
    }

    $('a[href*="around"]').each(function() {
        this.href = this.href + (this.href.indexOf('?') > -1 ? '&js=1' : '?js=1');
    });
    $('input[name="js"]').val(1);
    $('form[action*="around"]').each(function() {
        $('<input type="hidden" name="js" value="1">').prependTo(this);
    });

    // Focus on postcode box on front page
    $('#pc').focus();

    // In case we've come here by clicking back to a form that disabled a submit button
    $('form.validate input[type=submit]').removeAttr('disabled');

    $('[data-confirm]').on('click', function() {
        return confirm(this.getAttribute('data-confirm'));
    });
  },

  questionnaire: function() {
    // Questionnaire hide/showings
    if (!$('#been_fixed_no').prop('checked') && !$('#been_fixed_unknown').prop('checked')) {
        $('.js-another-questionnaire').hide();
    }
    $('#been_fixed_no').on('click', function() {
        $('.js-another-questionnaire').show('fast');
    });
    $('#been_fixed_unknown').on('click', function() {
        $('.js-another-questionnaire').show('fast');
    });
    $('#been_fixed_yes').on('click', function() {
        $('.js-another-questionnaire').hide('fast');
    });
  },

  form_validation: function() {
    // FIXME - needs to use translated string
    if (jQuery.validator) {
        jQuery.validator.addMethod('validCategory', function(value, element) {
            return this.optional(element) || value != '-- Pick a category --'; }, translation_strings.category );
        jQuery.validator.addMethod('js-password-validate', function(value, element) {
            return !value || value.length >= fixmystreet.password_minimum_length;
        }, translation_strings.password_register.short);
    }

    var submitted = false;

    $("form.validate").each(function(){
      $(this).validate({
        rules: validation_rules,
        messages: translation_strings,
        onkeyup: false,
        onfocusout: false,
        errorElement: 'div',
        errorClass: 'form-error',
        errorPlacement: function( error, element ) {
            element.before( error );
        },
        submitHandler: function(form) {
            if (form.submit_problem) {
                $('input[type=submit]', form).prop("disabled", true);
            }
            form.submit();
        },
        // make sure we can see the error message when we focus on invalid elements
        showErrors: function( errorMap, errorList ) {
            if ( submitted && errorList.length ) {
                var currScroll = $('#map_sidebar').scrollTop(),
                    pos = $(errorList[0].element).position().top;
               $('#map_sidebar').scrollTop( currScroll + pos - 120 );
            }
            this.defaultShowErrors();
            submitted = false;
        },
        invalidHandler: function(form, validator) { submitted = true; }
      });
    });

    /* set correct required status depending on what we submit
    * NB: need to add things to form_category as the JS updating
    * of this we do after a map click removes them */
    $('.js-submit_sign_in').click( function(e) {
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('.js-form-name').removeClass('required');
    } );

    $('.js-submit_register').click( function(e) {
        $('#form_category').addClass('required validCategory').removeClass('valid');
        $('.js-form-name').addClass('required');
    } );

    $('#facebook_sign_in, #twitter_sign_in').click(function(e){
        $('#form_username').removeClass();
        $('#username').removeClass();
    });

    $('#planned_form').submit(function(e) {
        if (e.metaKey || e.ctrlKey) {
            return;
        }
        e.preventDefault();
        var $form = $(this),
            $submit = $form.find("input[type='submit']" ),
            $labels = $('label[for="' + $submit.attr('id') + '"]'),
            problemId = $form.find("input[name='id']").val(),
            data = $form.serialize() + '&ajax=1',
            changeValue,
            buttonLabel,
            buttonValue,
            classToAdd,
            classToRemove;

        $.post(this.action, data, function(data) {
            if (data.outcome == 'add') {
                $form.find("input[name='shortlist-add']" ).attr('name', 'shortlist-remove');
                buttonLabel = $submit.data('label-remove');
                buttonValue = $submit.data('value-remove');
                classToAdd = $submit.data('class-remove');
                classToRemove = $submit.data('class-add');
                $('.shortlisted-status').remove();
                $(document).trigger('shortlist-add', problemId);
            } else if (data.outcome == 'remove') {
                $form.find("input[name='shortlist-remove']" ).attr('name', 'shortlist-add');
                buttonLabel = $submit.data('label-add');
                buttonValue = $submit.data('value-add');
                $(document).trigger('shortlist-remove', problemId);
                classToAdd = $submit.data('class-add');
                classToRemove = $submit.data('class-remove');
            }
            $submit.val(buttonValue).attr('aria-label', buttonLabel).removeClass(classToRemove).addClass(classToAdd);
            $labels.text(buttonValue).attr('aria-label', buttonLabel).removeClass(classToRemove).addClass(classToAdd);
        });
    });
  },

  autocomplete: function() {
    $('.js-autocomplete').each(function() {
        accessibleAutocomplete.enhanceSelectElement({
            selectElement: this,
            displayMenu: 'overlay',
            required: true,
            // showAllValues: true, // Currently undismissable on iOS
            defaultValue: ''
        });
    });
  },

  category_change: function() {
    // Deal with changes to report category.

    // On the new report form, does this by asking for details from the server.
    // Delegation is necessary because #form_category may be replaced during the lifetime of the page
    $("#problem_form").on("change.category", "select#form_category", function(){
        var args = {
            category: $(this).val(),
            latitude: $('input[name="latitude"]').val(),
            longitude: $('input[name="longitude"]').val()
        };

        $.getJSON('/report/new/category_extras', args, function(data) {
            var $category_meta = $('#category_meta');
            $('#js-councils_text').html(data.councils_text);
            $('#js-councils_text_private').html(data.councils_text_private);
            if ( data.category_extra ) {
                if ( $category_meta.length ) {
                    $category_meta.replaceWith( data.category_extra );
                } else {
                    $('#form_category_row').after( data.category_extra );
                }
            } else {
                $category_meta.empty();
            }
        });

        if (fixmystreet.hooks.update_problem_fields) {
            args.prefill_reports = $(this).data('prefill');
            args.role = $(this).data('role');
            args.body = $(this).data('body');

            fixmystreet.hooks.update_problem_fields(args);
        }
    });
  },

  category_groups: function() {
    var $category_select = $("select#form_category.js-grouped-select");
    if ($category_select.length === 0) {
        return;
    }
    var $group_select = $("<select></select>").addClass("form-control");
    var $subcategory_label = $("#form_subcategory_label");
    var $empty_option = $category_select.find("option").first();

    $group_select.change(function() {
        var subcategory_id = $(this).find(":selected").data("subcategory_id");
        $(".js-subcategory").hide();
        if (subcategory_id === undefined) {
            $subcategory_label.addClass("hidden");
            $category_select.val($(this).val()).change();
        } else {
            $("#" + subcategory_id).show().change();
            $("#form_subcategory_label").removeClass("hidden");
        }
    });

    var subcategory_change = function() {
        $category_select.val($(this).val()).change();
    };

    var add_option = function(el) {
        $group_select.append($(el).clone());
    };

    var add_optgroup = function(el) {
        var $el = $(el);
        var $options = $el.find("option");

        if ($options.length == 1) {
            add_option($options.get(0));
        } else {
            var label = $el.attr("label");
            var subcategory_id = "subcategory_" + label.replace(/[^a-zA-Z]+/g, '');
            var $opt = $("<option></option>").text(label).val(label);
            $opt.data("subcategory_id", subcategory_id);
            $group_select.append($opt);

            var $sub_select = $("<select></select>").addClass("form-control js-subcategory");
            $sub_select.attr("id", subcategory_id);
            $sub_select.append($empty_option.clone());
            $options.each(function() {
                var $newopt = $(this).clone();
                $sub_select.append($newopt);
                // Make sure any preselected value is preserved in the new UI:
                if ($newopt.attr('selected')) {
                    $group_select.val(label);
                }
            });
            $sub_select.hide().insertAfter($subcategory_label).change(subcategory_change);
        }
    };

    $category_select.hide();
    $group_select.insertAfter($category_select);
    $category_select.find("optgroup, > option").each(function() {
        if (this.tagName.toLowerCase() === 'optgroup') {
            add_optgroup(this);
        } else if (this.tagName.toLowerCase() === 'option') {
            add_option(this);
        }
    });
    $group_select.change();
  },

  hide_name: function() {
      $('body').on('click', '.js-hide-name', function(e){
          e.preventDefault();

          var $p = $(this).parents('p');
          var $form = $p.next('.hide-name-form'); // might not exist yet
          var url = $(this).attr('href');

          if ($form.length) {
              $form.slideUp(function(){
                  $form.remove();
              });
          } else {
              $.get(url).done(function(html){
                  $(html).find('.hide-name-form').hide().insertAfter($p).slideDown();
              }).fail(function(){
                  window.location.href = url;
              });
          }
      });
  },

  on_resize: function() {
    var last_type;
    $(window).on('resize', function() {
        var type = Modernizr.mq('(min-width: 48em)') || $('html.iel8').length ? 'desktop' : 'mobile';
        if (last_type == type) { return; }
        if (type == 'mobile') {
            fixmystreet.resize_to.mobile_page();
        } else {
            fixmystreet.resize_to.desktop_page();
        }
        last_type = type;
    }).resize();
  },

  dropzone: function($context) {

    // Pass a jQuery element, eg $('.foobar'), into this function
    // to limit all the selectors to that element. Handy if you want
    // to only bind/detect Dropzones in a particular part of the page,
    // or if your selectors (eg: "#form_photo") aren't unique across
    // the whole page.
    if (typeof $context === undefined) {
        $context = $(document);
    }

    if ('Dropzone' in window) {
      Dropzone.autoDiscover = false;
    }
    if ('Dropzone' in window && $('#form_photo', $context).length) {
      var $originalLabel = $('[for="form_photo"]', $context);
      var $originalInput = $('#form_photos', $context);
      var $dropzone = $('<div>').addClass('dropzone');

      $originalLabel.removeAttr('for');
      $('[data-plural]', $originalLabel).text(
          $('[data-plural]', $originalLabel).attr('data-plural')
      );
      $originalInput.hide();

      $dropzone.insertAfter($originalInput);
      var photodrop = new Dropzone($dropzone[0], {
        url: '/photo/upload',
        paramName: 'photo',
        maxFiles: 3,
        addRemoveLinks: true,
        thumbnailHeight: 150,
        thumbnailWidth: 150,
        resizeWidth: 2048,
        resizeHeight: 2048,
        resizeQuality: 0.6,
        acceptedFiles: 'image/jpeg,image/pjpeg,image/gif,image/tiff,image/png',
        dictDefaultMessage: translation_strings.upload_default_message,
        dictCancelUploadConfirmation: translation_strings.upload_cancel_confirmation,
        dictInvalidFileType: translation_strings.upload_invalid_file_type,
        dictMaxFilesExceeded: translation_strings.upload_max_files_exceeded,

        fallback: function() {
          $dropzone.remove();
          $originalLabel.attr('for', 'form_photo');
          $('[data-singular]', $originalLabel).text(
              $('[data-singular]', $originalLabel).attr('data-singular')
          );
          $originalInput.show();
        },
        init: function() {
          this.on("addedfile", function(file) {
            $('input[type=submit]', $context).prop("disabled", true).removeClass('green-btn');
          });
          this.on("queuecomplete", function() {
            $('input[type=submit]', $context).removeAttr('disabled').addClass('green-btn');
          });
          this.on("success", function(file, xhrResponse) {
            var ids = $('input[name=upload_fileid]', $context).val().split(','),
                id = (file.server_id = xhrResponse.id),
                l = ids.push(id),
                newstr = ids.join(',');
            $('input[name=upload_fileid]', $context).val(newstr);
          });
          this.on("error", function(file, errorMessage, xhrResponse) {
          });
          this.on("removedfile", function(file) {
            var ids = $('input[name=upload_fileid]', $context).val().split(','),
                newstr = $.grep(ids, function(n) { return (n!=file.server_id); }).join(',');
            $('input[name=upload_fileid]', $context).val(newstr);
          });
          this.on("maxfilesexceeded", function(file) {
            this.removeFile(file);
            var $message = $('<div class="dz-message dz-error-message">');
            $message.text(translation_strings.upload_max_files_exceeded);
            $message.prependTo(this.element);
            setTimeout(function() {
              $message.slideUp(250, function() {
                $message.remove();
              });
            }, 2000);
          });
        }
      });

      $.each($('input[name=upload_fileid]', $context).val().split(','), function(i, f) {
        if (!f) {
            return;
        }
        var mockFile = { name: f, server_id: f, dataURL: '/photo/temp.' + f };
        photodrop.emit("addedfile", mockFile);
        photodrop.createThumbnailFromUrl(mockFile,
            photodrop.options.thumbnailWidth, photodrop.options.thumbnailHeight,
            photodrop.options.thumbnailMethod, true, function(thumbnail) {
                photodrop.emit('thumbnail', mockFile, thumbnail);
            });
        photodrop.emit("complete", mockFile);
        photodrop.options.maxFiles -= 1;
      });
    }
  },

  report_list_filters: function() {
    // Hide the pin filter submit button. Not needed because we'll use JS
    // to refresh the map when the filter inputs are changed.
    $(".report-list-filters [type=submit]").hide();

    $('.js-multiple').make_multi();
  },

  mobile_ui_tweaks: function() {
    //move 'skip this step' link on mobile
    $('.mobile #skip-this-step').addClass('chevron').wrap('<li>').parent().appendTo('#key-tools');
  },

  on_mobile_nav_click: function() {
    $('.mobile').on('click', '#nav-link', function(e) {
        e.preventDefault();
        var offset = $('#main-nav').offset().top;
        $('html, body').animate({scrollTop:offset}, 1000);

        // Registering a pushState here means that mobile users can
        // press their browser's Back button to return out of the
        // mobile menu (easier than scrolling all the way back up
        // the page). However, to show the map page popstate listener
        // that this was a special state, we set hashchange to true in
        // the event state, so we can detect it, and ignore it, later.
        if ('pushState' in history) {
            history.pushState({
                hashchange: true
            }, null);
        }
    });
  },

  map_controls: function() {
    //add permalink on desktop, force hide on mobile
    //add links container (if its not there)
    if (fixmystreet.cobrand != 'zurich') {
        if ($('#sub_map_links').length === 0) {
            $('<p id="sub_map_links" />').insertAfter($('#map'));
        }
        if ($('#map_permalink').length === 0) {
            $('#sub_map_links').append('<a href="#" id="map_permalink">' + translation_strings.permalink + '</a>');
        }
    }

    if ($('.mobile').length) {
        $('#map_permalink').hide();
        // Make sure we end up with one Get updates link
        if ($('#key-tools a.feed').length) {
            $('#sub_map_links a.feed').remove();
            $('#key-tools a.feed').appendTo('#sub_map_links');
        }
        $('#key-tools li:empty').remove();
        $('#report-updates-data').insertAfter($('#map_box'));
        if (fixmystreet.page !== 'around' && !$('#toggle-fullscreen').length) {
            $('#sub_map_links').append('<a href="#" id="toggle-fullscreen" class="expand" data-expand-text="'+ translation_strings.expand_map +'" data-compress-text="'+ translation_strings.collapse_map +'" >'+ translation_strings.expand_map +'</span>');
        }
    }

    // Show/hide depending on whether it has any children to show
    if ($('#sub_map_links a:visible').length) {
        $('#sub_map_links').show();
    } else {
        $('#sub_map_links').hide();
    }

    //add open/close toggle button (if its not there)
    if ($('#map_links_toggle').length === 0) {
        $('<span>')
            .attr('id', 'map_links_toggle')
            .on('click', function() {
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
            })
            .prependTo('#sub_map_links');
    }

    $('#toggle-fullscreen').off('click').on('click', function() {
      var btnClass = $('html').hasClass('map-fullscreen') ? 'expand' : 'compress';
      var text = $(this).data(btnClass + '-text');

      $('html').toggleClass('map-fullscreen only-map');
      $(this).html(text).attr('class', btnClass);

      fixmystreet.map.updateSize();
    });
  },

  map_sidebar_key_tools: function() {
    if ($('html.mobile').length) {
        $('#council_wards').hide().removeClass('hidden-js').find('h2').hide();
        $('#key-tool-wards').off('click.wards');
        $('#key-tool-wards').on('click.wards', function(e) {
            e.preventDefault();
            $('#council_wards').slideToggle('800', function() {
              $('#key-tool-wards').toggleClass('hover');
            });
        });
    } else {
        $('#key-tool-wards').drawer('council_wards', false);
        $('#key-tool-around-updates').drawer('updates_ajax', true);
    }
    $('#key-tool-report-updates').small_drawer('report-updates-data');
    $('#key-tool-report-share').small_drawer('report-share');
  },

  email_login_form: function() {
    // Log in with email button
    var email_form = $('#js-social-email-hide'),
        button = $('<button class="btn btn--social btn--social-email">'+translation_strings.login_with_email+'</button>'),
        form_box = $('<div class="form-box"></div>');
    button.click(function(e) {
        e.preventDefault();
        email_form.fadeIn(500);
        form_box.hide();
    });
    form_box.append(button).insertBefore(email_form);
    if ($('.form-error').length) {
        button.click();
    }
  },

  reporting_hide_phone_email: function() {
    $('#form_username').on('keyup change', function() {
        var username = $(this).val();
        if (/^[^a-z]+$/i.test(username)) {
            $('#js-hide-if-username-phone').hide();
            $('#js-hide-if-username-email').show();
        } else {
            $('#js-hide-if-username-phone').show();
            $('#js-hide-if-username-email').hide();
        }
    });
  },

  fancybox_images: function() {
    // Fancybox fullscreen images
    if (typeof $.fancybox == 'function') {
        $('a[rel=fancy]').fancybox({
            'overlayColor': '#000000'
        });
    }
  },

  form_focus_triggers: function() {
    // If all of the form-focus-triggers are empty, hide form-focus-hidden.
    // (If the triggers aren't empty, then chances are we're being re-shown
    // the form after a validation error, so don't hide form-focus-hidden.)
    // Unhide form-focus-hidden when any of the triggers are focussed.
    var form_focus_data = $('.form-focus-trigger').map(function() {
        return $(this).val();
    }).get().join('');
    if (!form_focus_data) {
        $('.form-focus-hidden').hide();
        $('.form-focus-trigger').on('focus', function() {
            $('.form-focus-hidden').fadeIn(500);
        });
    }
  },

  alert_page_buttons: function() {
    // Go directly to RSS feed if RSS button clicked on alert page
    // (due to not wanting around form to submit, though good thing anyway)
    $('body').on('click', '#alert_rss_button', function(e) {
        e.preventDefault();
        var feed = $('input[name=feed][type=radio]:checked').parent().prevAll('a').attr('href');
        window.location.href = feed;
    });
    $('body').on('click', '#alert_email_button', function(e) {
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
  },

  ajax_history: function() {
    $('#map_sidebar').on('click', '.item-list--reports a', function(e) {
        if (e.metaKey || e.ctrlKey) {
            return;
        }

        e.preventDefault();

        var reportPageUrl = $(this).attr('href');
        var reportId = parseInt(reportPageUrl.replace(/^.*\/([0-9]+)$/, '$1'), 10);

        // If we've already selected this report
        if (reportId == window.selected_problem_id) {
            if (fixmystreet.map.setCenter) {
                // Second click, zoom in to the report on the map
                var marker = fixmystreet.maps.get_marker_by_id(reportId);
                fixmystreet.map.setCenter(
                    marker.geometry.getBounds().getCenterLonLat(),
                    fixmystreet.map.getNumZoomLevels() - 1 );
            }
            return;
        }

        fixmystreet.display.report(reportPageUrl, reportId, function() {
            // Since this navigation was the result of a user action,
            // we want to record the navigation as a state, so the user
            // can return to it later using their Back button.
            if ('pushState' in history) {
                history.pushState({
                    reportId: reportId,
                    reportPageUrl: reportPageUrl
                }, null, reportPageUrl);
            }
        });
    });

    $('#map_sidebar').on('click', '.js-back-to-report-list', function(e) {
        if (e.metaKey || e.ctrlKey) {
            return;
        }

        e.preventDefault();
        var reportListUrl = $(this).attr('href');
        fixmystreet.display.reports_list(reportListUrl, function() {
            // Since this navigation was the result of a user action,
            // we want to record the navigation as a state, so the user
            // can return to it later using their Back button.
            if ('pushState' in history) {
                history.pushState({ initial: true }, null, reportListUrl);
            }
        });
    });
  }

});

// The new location will be saved to a history state unless
// savePushState is set to false.
fixmystreet.update_pin = function(lonlat, savePushState) {
    var lonlats = fixmystreet.maps.update_pin(lonlat);

    if (savePushState !== false) {
        if ('pushState' in history) {
            var newReportUrl = '/report/new?longitude=' + lonlats.url.lon + '&latitude=' + lonlats.url.lat;
            history.pushState({
                newReportAtLonlat: lonlats.state
            }, null, newReportUrl);
        }
    }

    $.getJSON('/report/new/ajax', {
        latitude: $('#fixmystreet\\.latitude').val(),
        longitude: $('#fixmystreet\\.longitude').val()
    }, function(data) {
        if (data.error) {
            if (!$('#side-form-error').length) {
                $('<div id="side-form-error"/>').insertAfter($('#side-form'));
            }
            $('#side-form-error').html('<h1>' + translation_strings.reporting_a_problem + '</h1><p>' + data.error + '</p>').show();
            $('#side-form').hide();
            $('body').removeClass('with-notes');
            return;
        }
        $('#side-form, #site-logo').show();
        var old_category = $("select#form_category").val();
        $('#js-councils_text').html(data.councils_text);
        $('#js-councils_text_private').html(data.councils_text_private);
        $('#js-top-message').html(data.top_message || '');
        $('#form_category_row').html(data.category);
        if ($("select#form_category option[value=\""+old_category+"\"]").length) {
            $("select#form_category").val(old_category);
        }
        if ( data.extra_name_info && !$('#form_fms_extra_title').length ) {
            // there might be a first name field on some cobrands
            var lb = $('#form_first_name').prev();
            if ( lb.length === 0 ) { lb = $('#form_name').prev(); }
            lb.before(data.extra_name_info);
        }

        // If the category filter appears on the map and the user has selected
        // something from it, then pre-fill the category field in the report,
        // if it's a value already present in the drop-down.
        var category = $("#filter_categories").val();
        if (category !== undefined && $("#form_category option[value='"+category+"']").length) {
            $("#form_category").val(category);
        }

        var category_select = $("select#form_category");
        if (category_select.val() != '-- Pick a category --') {
            category_select.change();
        }
        fixmystreet.run(fixmystreet.set_up.category_groups);

        if (data.contribute_as) {
            var $select = $('.js-contribute-as');
            if (!$select.data('original')) {
                $select.data('original', $select.html());
            }
            $select.html($select.data('original'));
            if (!data.contribute_as.another_user) {
                $select.find('option[value=another_user]').remove();
            }
            if (!data.contribute_as.anonymous_user) {
                $select.find('option[value=anonymous_user]').remove();
            }
            if (!data.contribute_as.body) {
                $select.find('option[value=body]').remove();
            }
            $select.change();
            $('#js-contribute-as-wrapper').show();
        } else {
            $('#js-contribute-as-wrapper').hide();
        }
    });

    if (!$('#side-form-error').is(':visible')) {
        $('#side-form, #site-logo').show();
        $('#map_sidebar').scrollTop(0);
    }

};

fixmystreet.display = {
  begin_report: function(lonlat, saveHistoryState) {
    lonlat = fixmystreet.maps.begin_report(lonlat);

    // Store pin location in form fields, and check coverage of point
    fixmystreet.update_pin(lonlat, saveHistoryState);

    // It's possible to invoke this multiple times in a row
    // (eg: by clicking on the map multiple times, to
    // reposition your report). But there is some stuff we
    // only want to happen the first time you switch from
    // the "around" view to the "new" report view. So, here
    // we check whether we've already transitioned into the
    // "new" report view, and if so, we return from the
    // callback early, skipping the remainder of the setup
    // stuff.
    if (fixmystreet.page == 'new') {
        if (fixmystreet.map.panTo) {
            fixmystreet.map.panDuration = 100;
            fixmystreet.map.panTo(lonlat);
            fixmystreet.map.panDuration = 50;
        }
        return;
    }

    // If there are notes to be displayed, add the .with-notes class
    // to make the sidebar wider.
    if ($('#report-a-problem-sidebar').length) {
        $('body').addClass('with-notes');
    }

    /* For some reason on IOS5 if you use the jQuery show method it
     * doesn't display the JS validation error messages unless you do this
     * or you cause a screen redraw by changing the phone orientation.
     * NB: This has to happen after the call to show() in fixmystreet.update_pin */
    if ( navigator.userAgent.match(/like Mac OS X/i)) {
        document.getElementById('side-form').style.display = 'block';
    }
    $('#side').hide();

    if (fixmystreet.map.updateSize) {
        fixmystreet.map.updateSize(); // required after changing the size of the map element
    }
    if (fixmystreet.map.panTo) {
        fixmystreet.map.panDuration = 100;
        fixmystreet.map.panTo(lonlat);
        fixmystreet.map.panDuration = 50;
    }

    $('#sub_map_links').hide();
    $('.big-hide-pins-link').hide();
    if ($('html').hasClass('mobile')) {
        var $map_box = $('#map_box'),
            width = $map_box.width(),
            height = $map_box.height();
        $map_box.append(
            '<p id="mob_sub_map_links">' +
            '<a href="#" id="try_again">' +
                translation_strings.try_again +
            '</a>' +
            '<a href="#ok" id="mob_ok">' +
                translation_strings.ok +
            '</a>' +
            '</p>')
        .addClass('above-form') // Stop map being absolute, so reporting form doesn't get hidden
        .css({
            width: width,
            height: height
        });
        $('#try_again').click(function(e){
            e.preventDefault();
            history.back();
        });

        $('.mobile-map-banner span').text(translation_strings.right_place);

        // mobile user clicks 'ok' on map
        $('#mob_ok').toggle(function(){
            //scroll the height of the map box instead of the offset
            //of the #side-form or whatever as we will probably want
            //to do this on other pages where #side-form might not be
            $('html, body').animate({ scrollTop: height-60 }, 1000, function(){
                $('html').removeClass('only-map');
                $('#mob_sub_map_links').addClass('map_complete');
                $('#mob_ok').text(translation_strings.map);
            });
        }, function(){
            $('html, body').animate({ scrollTop: 0 }, 1000, function(){
                $('html').addClass('only-map');
                $('#mob_sub_map_links').removeClass('map_complete');
                $('#mob_ok').text(translation_strings.ok);
            });
        });
    }

    fixmystreet.page = 'new';
  },

  report: function(reportPageUrl, reportId, callback) {
    $.ajax(reportPageUrl, { cache: false }).done(function(html, textStatus, jqXHR) {
        var $reportPage = $(html),
            $twoColReport = $reportPage.find('.two_column_sidebar'),
            $sideReport = $reportPage.find('#side-report');

        if ($sideReport.length) {
            $('#side').hide(); // Hide the list of reports
            // Remove any existing report page content from sidebar
            $('#side-report').remove();
            $('.two_column_sidebar').remove();
            // Insert this report's content
            if ($twoColReport.length) {
                $twoColReport.appendTo('#map_sidebar');
                $('body').addClass('with-actions');
                fixmystreet.run(fixmystreet.set_up.report_page_inspect);
                fixmystreet.run(fixmystreet.set_up.manage_duplicates);
                fixmystreet.run(fixmystreet.set_up.action_scheduled_raise_defect);
            } else {
                $sideReport.appendTo('#map_sidebar');
            }
            $('#map_sidebar').scrollTop(0);

            var found = html.match(/<title>([\s\S]*?)<\/title>/);
            var page_title = found[1];
            fixmystreet.page = 'report';

            fixmystreet.mobile_reporting.remove_ui();
            if (fixmystreet.map.updateSize && ($twoColReport.length || $('html').hasClass('mobile'))) {
                fixmystreet.map.updateSize();
            }

            $('.big-hide-pins-link').hide();

            // If this is the first individual report we've loaded, remove the
            // "all reports" sub_map_links but store them in a global variable
            // so we can reinsert them when the user returns to the all reports
            // view.
            if (!fixmystreet.original.sub_map_links) {
                fixmystreet.original.sub_map_links = $('#sub_map_links').detach();
            }
            // With #sub_map_links detached from the DOM, we set up the
            // individual report's sub_map_links using map_controls().
            fixmystreet.set_up.map_controls();

            // Set the Back link to know where to go back to.
            // TODO: If you e.g. filter before selecting a report, this URL is
            // wrong (but what is shown is correct).
            $('.js-back-to-report-list').attr('href', fixmystreet.original.href);

            // Problems nearby should act the same as 'Back to all reports' on around,
            // but on /my and /reports should go to that around page.
            if (fixmystreet.original.page == 'around') {
                $sideReport.find('#key-tool-problems-nearby').addClass('js-back-to-report-list');
            }
            fixmystreet.set_up.map_sidebar_key_tools();
            fixmystreet.set_up.form_validation();
            fixmystreet.set_up.email_login_form();
            fixmystreet.set_up.fancybox_images();
            fixmystreet.set_up.dropzone($sideReport);
            fixmystreet.set_up.form_focus_triggers();
            fixmystreet.run(fixmystreet.set_up.moderation);
            fixmystreet.run(fixmystreet.set_up.response_templates);

            window.selected_problem_id = reportId;
            var marker = fixmystreet.maps.get_marker_by_id(reportId);
            if (fixmystreet.map.panTo && ($('html').hasClass('mobile') || !marker.onScreen())) {
                fixmystreet.map.panTo(
                    marker.geometry.getBounds().getCenterLonLat()
                );
            }
            if (fixmystreet.maps.markers_resize) {
                fixmystreet.maps.markers_resize(); // force a redraw so the selected marker gets bigger
            }

            if (typeof callback === 'function') {
                callback();
            }
            document.title = page_title;

        } else {
            window.location.href = reportPageUrl;
        }

    }).fail(function(jqXHR, textStatus, errorThrown) {
        window.location.href = reportPageUrl;

    });
  },

  // This could be an /around page or a /reports page
  reports_list: function(reportListUrl, callback) {
    // If the report list is already in the DOM,
    // just reveal it, rather than loading new page.
    var side = document.getElementById('side');
    if (side) {
        if (side.style.display !== 'none') {
            return;
        }
        side.style.display = '';
        $('#side-form').hide();
        // Report page may have been one or two columns, remove either
        $('#side-report').remove();
        $('.two_column_sidebar').remove();
        $('body').removeClass('with-actions');
        $('body').removeClass('with-notes');

        fixmystreet.page = fixmystreet.original.page;
        if ($('html').hasClass('mobile') && fixmystreet.page == 'around') {
            $('#mob_sub_map_links').remove();
            fixmystreet.mobile_reporting.apply_ui();
        }

        if (fixmystreet.original.sub_map_links) {
            $('#sub_map_links').replaceWith(fixmystreet.original.sub_map_links);
            delete fixmystreet.original.sub_map_links;
        }
        $('.big-hide-pins-link').show();
        fixmystreet.set_up.map_controls();

        window.selected_problem_id = undefined;

        // Perform vendor-specific map setup steps,
        // to get map back into "around" mode.
        fixmystreet.maps.display_around();

        if (typeof callback === 'function') {
            callback();
        }
        document.title = fixmystreet.original.title;

    } else {
        window.location.href = reportListUrl;
    }
  }
};


$(function() {
    fixmystreet.original = {
        'href': location.href,
        'title': document.title,
        'page': fixmystreet.page
    };

    $.each(fixmystreet.set_up, function(setup_name, setup_func) {
        setup_func();
    });

    // Have a fake history entry so we can cover all eventualities.
    if ('replaceState' in history) {
        history.replaceState({ initial: true }, null);
    }

    $(window).on('load', function () {
        setTimeout(function () {
            window.addEventListener('popstate', function(e) {
                // The user has pressed the Back button, and there is a
                // stored History state for them to return to.

                // Note: no pushState callbacks in these display_* calls,
                // because we're already inside a popstate: We want to roll
                // back to a previous state, not create a new one!

                if (!fixmystreet.page) {
                    // Only care about map pages, which set this variable
                    return;
                }

                var location = window.history.location || window.location;

                if (e.state === null) {
                    // Hashchange or whatever, we don't care.
                    return;
                }

                if ('initial' in e.state) {
                    // User has navigated Back from a pushStated state, presumably to
                    // see the list of all reports (which was shown on pageload). By
                    // this point, the browser has *already* updated the URL bar so
                    // location.href is something like foo.com/around?pc=abc-123,
                    // which we pass into fixmystreet.display.reports_list() as a fallback
                    // in case the list isn't already in the DOM.
                    $('#filter_categories').add('#statuses').add('#sort').find('option')
                        .prop('selected', function() { return this.defaultSelected; })
                        .trigger('change.multiselect');
                    if (fixmystreet.utils && fixmystreet.utils.parse_query_string) {
                        var qs = fixmystreet.utils.parse_query_string();
                        var page = qs.p || 1;
                        $('.pagination').data('page', page)
                            .trigger('change.filters');
                    }
                    fixmystreet.display.reports_list(location.href);
                } else if ('reportId' in e.state) {
                    fixmystreet.display.report(e.state.reportPageUrl, e.state.reportId);
                } else if ('newReportAtLonlat' in e.state) {
                    fixmystreet.display.begin_report(e.state.newReportAtLonlat, false);
                } else if ('page_change' in e.state) {
                    $('.pagination').data('page', e.state.page_change.page)
                        .trigger('change.filters');
                } else if ('filter_change' in e.state) {
                    $('#filter_categories').val(e.state.filter_change.filter_categories);
                    $('#statuses').val(e.state.filter_change.statuses);
                    $('#sort').val(e.state.filter_change.sort);
                    $('#filter_categories').add('#statuses')
                        .trigger('change.filters').trigger('change.multiselect');
                    fixmystreet.display.reports_list(location.href);
                // } else if ('hashchange' in e.state) {
                    // This popstate was just here because the hash changed.
                    // (eg: mobile nav click.) We want to ignore it.
                }
            });
        }, 0);
    });

});
